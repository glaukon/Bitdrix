package com.bitdrix.bitdrix

import android.util.Log
import java.io.InputStream
import java.io.OutputStream
import java.io.RandomAccessFile
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.net.URLDecoder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

private const val TAG = "BitdrixStream"

/**
 * Minimal HTTP/1.1 server on 127.0.0.1 that serves torrent files while they
 * download. Each request is served progressively: for every piece the player
 * needs, the server sets libtorrent piece deadlines for a read-ahead window and
 * blocks until the piece is on disk, instead of failing the request.
 *
 * URL format: `http://127.0.0.1:<port>/stream/<torrentId>/<fileIndex>`
 */
internal class StreamServer(private val engine: TorrentEngine) {

    private var server: ServerSocket? = null
    private val pool = Executors.newCachedThreadPool { r -> Thread(r, "bitdrix-stream").apply { isDaemon = true } }
    private val clients = AtomicInteger(0)

    /** Pieces are waited for at most this long while no data arrives at all. */
    private val stallTimeoutMs = 3 * 60_000L

    fun activeClients(): Int = clients.get()

    @Synchronized
    fun urlFor(torrentId: String, fileIndex: Int): String {
        val s = server ?: start()
        return "http://127.0.0.1:${s.localPort}/stream/$torrentId/$fileIndex"
    }

    private fun start(): ServerSocket {
        val s = ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"))
        server = s
        Thread({
            while (!s.isClosed) {
                try {
                    val socket = s.accept()
                    pool.execute { handle(socket) }
                } catch (e: Exception) {
                    if (!s.isClosed) Log.w(TAG, "accept failed: ${e.message}")
                }
            }
        }, "bitdrix-stream-accept").apply { isDaemon = true }.start()
        Log.d(TAG, "Listening on 127.0.0.1:${s.localPort}")
        return s
    }

    private fun handle(socket: Socket) {
        clients.incrementAndGet()
        try {
            socket.use { s ->
                s.soTimeout = 30_000
                s.tcpNoDelay = true
                val request = readRequest(s.getInputStream())
                val out = s.getOutputStream().buffered(64 * 1024)
                serve(request, out)
                out.flush()
            }
        } catch (_: SocketException) {
            // Player closed the connection (seek or stop) — normal.
        } catch (e: Exception) {
            Log.w(TAG, "request failed: ${e.message}")
        } finally {
            clients.decrementAndGet()
        }
    }

    private fun serve(request: List<String>, out: OutputStream) {
        val parts = request.firstOrNull()?.split(' ') ?: return
        if (parts.size < 2) return writeStatus(out, 400, "Bad Request")
        val method = parts[0]
        if (method != "GET" && method != "HEAD") return writeStatus(out, 405, "Method Not Allowed")

        val path = URLDecoder.decode(parts[1].substringBefore('?'), "UTF-8").trim('/').split('/')
        val fileIndex = path.getOrNull(2)?.toIntOrNull()
        if (path.size < 3 || path[0] != "stream" || fileIndex == null) return writeStatus(out, 404, "Not Found")

        val target = engine.streamTarget(path[1], fileIndex) ?: return writeStatus(out, 404, "Not Found")
        val size = target.size
        if (size <= 0L) return writeStatus(out, 404, "Not Found")

        val rangeHeader = request.firstOrNull { it.startsWith("Range:", ignoreCase = true) }
        val range = parseRange(rangeHeader, size)
            ?: return writeRaw(out, "HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */$size\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
        val (start, end) = range
        val length = end - start + 1

        val head = StringBuilder()
        if (rangeHeader != null) {
            head.append("HTTP/1.1 206 Partial Content\r\n")
            head.append("Content-Range: bytes $start-$end/$size\r\n")
        } else {
            head.append("HTTP/1.1 200 OK\r\n")
        }
        head.append("Content-Type: ${contentTypeFor(target.file.name)}\r\n")
        head.append("Accept-Ranges: bytes\r\n")
        head.append("Content-Length: $length\r\n")
        head.append("Connection: close\r\n\r\n")
        writeRaw(out, head.toString())
        if (method == "HEAD") return

        streamBytes(target, start, end, out)
    }

    private fun streamBytes(t: TorrentEngine.StreamTarget, start: Long, end: Long, out: OutputStream) {
        val fs = t.fs
        val pieceLength = fs.pieceLength().toLong().coerceAtLeast(1L)
        val fileOffset = fs.fileOffset(t.index)
        val lastPiece = ((fileOffset + t.size - 1) / pieceLength).toInt()
        val readAhead = engine.readAheadPieces(fs)
        val buffer = ByteArray(64 * 1024)
        var raf: RandomAccessFile? = null

        // A new request usually means a seek: drop deadlines set for the old position.
        try { t.handle.clearPieceDeadlines() } catch (_: Exception) {}

        try {
            var pos = start
            while (pos <= end) {
                val piece = ((fileOffset + pos) / pieceLength).toInt()
                engine.setDeadlines(t.handle, piece, lastPiece, readAhead)
                if (!waitForPiece(t, piece, lastPiece, readAhead)) {
                    Log.w(TAG, "Piece $piece never arrived; closing stream")
                    return
                }
                val pieceEndInFile = ((piece + 1L) * pieceLength - fileOffset - 1).coerceAtMost(end)
                val file = raf ?: RandomAccessFile(t.file, "r").also { raf = it }
                file.seek(pos)
                while (pos <= pieceEndInFile) {
                    val want = minOf(buffer.size.toLong(), pieceEndInFile - pos + 1).toInt()
                    val read = file.read(buffer, 0, want)
                    if (read <= 0) return
                    out.write(buffer, 0, read)
                    pos += read
                }
            }
        } finally {
            try { raf?.close() } catch (_: Exception) {}
        }
    }

    private fun waitForPiece(t: TorrentEngine.StreamTarget, piece: Int, lastPiece: Int, readAhead: Int): Boolean {
        var waitedMs = 0L
        var lastRefresh = 0L
        while (true) {
            val have = try {
                if (!t.handle.isValid) return false
                t.handle.havePiece(piece)
            } catch (_: Exception) {
                return false
            }
            if (have) return true
            if (waitedMs >= stallTimeoutMs) return false
            // Re-assert deadlines now and then (another connection may have cleared them).
            if (waitedMs - lastRefresh >= 3_000) {
                engine.setDeadlines(t.handle, piece, lastPiece, readAhead)
                lastRefresh = waitedMs
            }
            Thread.sleep(100)
            waitedMs += 100
        }
    }

    private fun readRequest(input: InputStream): List<String> {
        val lines = mutableListOf<String>()
        val current = StringBuilder()
        while (lines.size < 64 && current.length < 8192) {
            val b = input.read()
            if (b < 0) break
            if (b == '\r'.code) continue
            if (b == '\n'.code) {
                if (current.isEmpty()) break
                lines.add(current.toString())
                current.clear()
            } else {
                current.append(b.toChar())
            }
        }
        return lines
    }

    /** Returns the inclusive byte range, or null when it is not satisfiable. */
    private fun parseRange(header: String?, size: Long): Pair<Long, Long>? {
        if (header == null) return 0L to size - 1
        val spec = header.substringAfter(':').trim().removePrefix("bytes=").substringBefore(',').trim()
        val startText = spec.substringBefore('-').trim()
        val endText = spec.substringAfter('-', "").trim()
        if (startText.isEmpty()) {
            // Suffix range: last N bytes.
            val n = endText.toLongOrNull() ?: return null
            if (n <= 0) return null
            return maxOf(0L, size - n) to size - 1
        }
        val start = startText.toLongOrNull() ?: return null
        if (start >= size) return null
        val end = endText.toLongOrNull()?.coerceAtMost(size - 1) ?: (size - 1)
        if (end < start) return null
        return start to end
    }

    private fun writeStatus(out: OutputStream, code: Int, message: String) {
        val body = message.toByteArray()
        writeRaw(out, "HTTP/1.1 $code $message\r\nContent-Type: text/plain\r\nContent-Length: ${body.size}\r\nConnection: close\r\n\r\n")
        out.write(body)
    }

    private fun writeRaw(out: OutputStream, text: String) = out.write(text.toByteArray(Charsets.US_ASCII))

    private fun contentTypeFor(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "mp4", "m4v" -> "video/mp4"
        "webm" -> "video/webm"
        "mkv" -> "video/x-matroska"
        "avi" -> "video/x-msvideo"
        "mov" -> "video/quicktime"
        "ts", "m2ts" -> "video/mp2t"
        "mp3" -> "audio/mpeg"
        "srt" -> "application/x-subrip"
        else -> "application/octet-stream"
    }
}
