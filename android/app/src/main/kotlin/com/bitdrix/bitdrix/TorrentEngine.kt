package com.bitdrix.bitdrix

import android.content.Context
import android.os.Environment
import android.util.Log
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import org.libtorrent4j.*
import org.libtorrent4j.alerts.*
import java.io.File
import java.io.RandomAccessFile
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

private const val TAG = "BitdrixTorrent"

class TorrentEngine(context: Context) {

    private val session = SessionManager()

    // infoHash hex string → torrentId  (no TorrentHandle objects stored — they become
    // dangling after the alert that provided them is freed by the GC)
    private val hashToId = HashMap<String, String>()
    // torrentId → infoHash hex string
    private val idToHash = HashMap<String, String>()
    // torrents added whose hash couldn't be extracted ahead of time; resolved in ADD_TORRENT alert
    private val pendingIds = ArrayDeque<String>()
    // torrentId -> file index currently selected for streaming.
    private val streamingFileIndexes = HashMap<String, Int>()
    private val lock = Any()
    private var streamServer: ServerSocket? = null
    private var streamServerPort: Int = 0

    var onUpdate: ((String) -> Unit)? = null

    private val saveDir: File = run {
        val extDir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
        File(extDir ?: context.filesDir, "Bitdrix").also { it.mkdirs() }
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val alertListener = object : AlertListener {
        override fun types(): IntArray? = null

        override fun alert(alert: Alert<*>) {
            when (alert.type()) {
                AlertType.ADD_TORRENT -> {
                    val a = alert as AddTorrentAlert
                    Log.d(TAG, "ADD_TORRENT alert, error=${a.error().isError} msg=${a.error().message}")
                    if (a.error().isError) return
                    // Extract hash as a plain String immediately; do NOT store the handle —
                    // its C++ memory is owned by the alert and becomes invalid after this callback.
                    val hash = normalizeHash(a.handle().infoHash().toHex())
                    Log.d(TAG, "ADD_TORRENT hash=$hash")
                    synchronized(lock) {
                        var id = hashToId[hash]
                        if (id == null && pendingIds.isNotEmpty()) {
                            id = pendingIds.removeFirst()
                            hashToId[hash] = id
                            idToHash[id] = hash
                            Log.d(TAG, "Resolved pending torrent id=$id via ADD_TORRENT alert")
                        }
                        if (id == null) {
                            Log.w(TAG, "ADD_TORRENT: no id found for hash=$hash, ignoring")
                        }
                    }
                    requestTorrentUpdates()
                }
                AlertType.METADATA_RECEIVED -> {
                    val hash = normalizeHash((alert as MetadataReceivedAlert).handle().infoHash().toHex())
                    Log.d(TAG, "METADATA_RECEIVED hash=$hash")
                    requestTorrentUpdates()
                }
                AlertType.TORRENT_FINISHED -> {
                    Log.d(TAG, "TORRENT_FINISHED")
                    requestTorrentUpdates()
                }
                AlertType.STATE_UPDATE -> { /* handled by startPollLoop */ }
                AlertType.TORRENT_ERROR -> {
                    val a = alert as TorrentErrorAlert
                    val hash = normalizeHash(a.handle().infoHash().toHex())
                    val id = synchronized(lock) { hashToId[hash] } ?: return
                    onUpdate?.invoke(
                        JSONObject()
                            .put("id", id)
                            .put("status", "error")
                            .put("errorMessage", a.error().message)
                            .toString()
                    )
                }
                else -> {}
            }
        }
    }

    init {
        session.addListener(alertListener)
        session.start()
        session.startDht()
        Log.d(TAG, "Session started, saveDir=$saveDir")
        requestTorrentUpdates()
        startPollLoop()
    }

    // ── Public API ────────────────────────────────────────────────────────────

    fun addTorrentFile(filePath: String, torrentId: String) {
        scope.launch {
            try {
                val f = File(filePath)
                if (!f.exists()) {
                    emitError(torrentId, "Archivo torrent no encontrado: $filePath")
                    return@launch
                }
                val ti = TorrentInfo(f)
                val hash = normalizeHash(ti.infoHash().toHex())
                synchronized(lock) {
                    hashToId[hash] = torrentId
                    idToHash[torrentId] = hash
                    Log.d(TAG, "addTorrentFile id=$torrentId hash=$hash name=${ti.name()}")
                }
                val swigP = org.libtorrent4j.swig.add_torrent_params()
                swigP.set_ti(ti.swig())
                swigP.setSave_path(saveDir.absolutePath)
                session.swig().async_add_torrent(swigP)
                Log.d(TAG, "async_add_torrent (file) dispatched for id=$torrentId")
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.e(TAG, "addTorrentFile error: ${e.message}", e)
                emitError(torrentId, e.message ?: "Error al agregar archivo torrent")
            }
        }
    }

    fun addMagnet(magnetLink: String, torrentId: String) {
        scope.launch {
            try {
                val hash = extractInfoHash(magnetLink)
                synchronized(lock) {
                    if (hash != null) {
                        val normalized = normalizeHash(hash)
                        hashToId[normalized] = torrentId
                        idToHash[torrentId] = normalized
                        Log.d(TAG, "addMagnet torrentId=$torrentId hash=$normalized")
                    } else {
                        pendingIds.addLast(torrentId)
                        Log.d(TAG, "addMagnet torrentId=$torrentId, hash unknown — queued as pending")
                    }
                }
                val params = AddTorrentParams.parseMagnetUri(magnetLink)
                params.savePath = saveDir.absolutePath
                session.swig().async_add_torrent(params.swig())
                Log.d(TAG, "async_add_torrent dispatched for torrentId=$torrentId")
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.e(TAG, "addMagnet exception: ${e.message}", e)
                synchronized(lock) { pendingIds.removeLastOrNull() }
                emitError(torrentId, e.message ?: "Error desconocido")
            }
        }
    }

    fun pause(torrentId: String) {
        synchronized(lock) { findHandleLocked(torrentId)?.pause() }
        requestTorrentUpdates()
    }

    fun resume(torrentId: String) {
        synchronized(lock) { findHandleLocked(torrentId)?.resume() }
        requestTorrentUpdates()
    }

    fun remove(torrentId: String, deleteFiles: Boolean) {
        synchronized(lock) {
            val handle = findHandleLocked(torrentId)
            idToHash.remove(torrentId)?.let(hashToId::remove)
            hashToId.entries.removeIf { it.value == torrentId }
            streamingFileIndexes.remove(torrentId)
            if (handle == null) return
            val removeFlags = if (deleteFiles) {
                SessionHandle.DELETE_FILES
            } else {
                org.libtorrent4j.swig.remove_flags_t()
            }
            session.remove(handle, removeFlags)
        }
    }

    fun getFiles(torrentId: String): String {
        return synchronized(lock) {
            val handle = findHandleLocked(torrentId) ?: return@synchronized "[]"
            buildFilesJsonArrayLocked(torrentId, handle).toString()
        }
    }

    fun selectFile(torrentId: String, fileId: String): String? {
        synchronized(lock) {
            val handle = findHandleLocked(torrentId) ?: return null
            val ti = handle.torrentFile() ?: return null
            val fs = ti.files()
            val fileIndex = fileId.substringAfterLast('-').toIntOrNull() ?: return null
            if (fileIndex !in 0 until fs.numFiles()) return null

            val priorities = Array(fs.numFiles()) { Priority.LOW }
            priorities[fileIndex] = Priority.TOP_PRIORITY
            handle.prioritizeFiles(priorities)
            streamingFileIndexes[torrentId] = fileIndex
            prepareStreamingPieces(handle, fs, fileIndex)

            handle.resume()
            return streamUrl(torrentId, fileIndex)
        }
    }

    fun dispose() {
        scope.cancel()
        try { streamServer?.close() } catch (_: Exception) {}
        streamServer = null
        session.removeListener(alertListener)
        session.stop()
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * Returns a FRESH TorrentHandle obtained directly from the session.
     * Never uses a cached handle — avoids dangling-pointer crashes from handles
     * that were previously obtained from alert callbacks (swigCMemOwn = false).
     * Must be called with [lock] held.
     */
    private fun findHandleLocked(torrentId: String): TorrentHandle? {
        val hash = idToHash[torrentId] ?: return null
        if (hash.length != 40) return null
        return try {
            val h = session.find(Sha1Hash.parseHex(hash))
            if (h != null && h.isValid) h else null
        } catch (_: RuntimeException) {
            null
        }
    }

    private fun emitStatusJsonLocked(
        id: String,
        st: TorrentStatus,
        knownHandle: TorrentHandle? = null,
    ): String {
        val infoHashes = st.getInfoHashes()
        val resolvedHash = when {
            infoHashes.hasV1() -> normalizeHash(infoHashes.getV1().toHex())
            else -> normalizeHash(infoHashes.getBest().toHex())
        }
        idToHash[id] = resolvedHash
        hashToId[resolvedHash] = id
        val state = st.state()
        val isPaused = st.flags().and_(TorrentFlags.PAUSED).non_zero()
        val statusStr = when {
            state == TorrentStatus.State.FINISHED ||
            state == TorrentStatus.State.SEEDING -> "completed"
            isPaused -> "paused"
            state == TorrentStatus.State.DOWNLOADING ||
            state == TorrentStatus.State.DOWNLOADING_METADATA -> "downloading"
            else -> "queued"
        }
        // st.name() is blank until metadata arrives; fall back to TorrentInfo.name().
        val resolvedName = st.name().ifBlank {
            val h = knownHandle ?: try { session.find(Sha1Hash.parseHex(resolvedHash)) } catch (_: Exception) { null }
            h?.torrentFile()?.name()?.ifBlank { null }
        } ?: "Resolviendo metadatos..."
        if (knownHandle != null) {
            ensureStreamingCandidateLocked(id, knownHandle)
        }
        return JSONObject()
            .put("id", id)
            .put("name", resolvedName)
            .put("progress", st.progress().toDouble())
            .put("downloadSpeed", st.downloadRate().toLong())
            .put("uploadSpeed", st.uploadRate().toLong())
            .put("peers", st.numPeers())
            .put("seeds", st.numSeeds())
            .put("downloadedSize", st.totalWantedDone())
            .put("uploadedSize", st.totalUpload())
            .put("totalSize", st.totalWanted())
            .put("status", statusStr)
            .put("files", knownHandle?.let { buildFilesJsonArrayLocked(id, it) } ?: JSONArray())
            .toString()
    }

    private fun ensureStreamingCandidateLocked(torrentId: String, handle: TorrentHandle) {
        if (streamingFileIndexes.containsKey(torrentId)) return
        val ti = handle.torrentFile() ?: return
        val fs = ti.files()
        if (fs.numFiles() <= 0) return

        var selectedIndex = -1
        var selectedSize = -1L
        for (i in 0 until fs.numFiles()) {
            val path = fs.filePath(i).lowercase()
            val isVideo = path.endsWith(".mp4") ||
                path.endsWith(".mkv") ||
                path.endsWith(".avi") ||
                path.endsWith(".mov") ||
                path.endsWith(".webm") ||
                path.endsWith(".m4v")
            val size = fs.fileSize(i)
            if (isVideo && size > selectedSize) {
                selectedIndex = i
                selectedSize = size
            }
        }
        if (selectedIndex < 0) {
            for (i in 0 until fs.numFiles()) {
                val size = fs.fileSize(i)
                if (size > selectedSize) {
                    selectedIndex = i
                    selectedSize = size
                }
            }
        }
        if (selectedIndex < 0) return

        val priorities = Array(fs.numFiles()) { Priority.LOW }
        priorities[selectedIndex] = Priority.TOP_PRIORITY
        try { handle.prioritizeFiles(priorities) } catch (_: Exception) {}
        streamingFileIndexes[torrentId] = selectedIndex
        prepareStreamingPieces(handle, fs, selectedIndex)
    }

    private fun prepareStreamingPieces(handle: TorrentHandle, fs: FileStorage, fileIndex: Int) {
        try { handle.queuePositionTop() } catch (_: Exception) {}
        try { handle.forceReannounce(0, 0, TorrentHandle.IGNORE_MIN_INTERVAL) } catch (_: Exception) {}

        val startPiece = fs.pieceIndexAtFile(fileIndex)
        val endPiece = fs.lastPieceIndexAtFile(fileIndex)
        if (startPiece >= 0 && endPiece >= startPiece) {
            try { handle.setSequentialRange(startPiece, endPiece) } catch (_: Exception) {}
            prioritizeStreamingPieces(handle, startPiece, endPiece)
        }
    }

    private fun streamUrl(torrentId: String, fileIndex: Int): String {
        ensureStreamServer()
        return "http://127.0.0.1:$streamServerPort/stream/$torrentId/$fileIndex"
    }

    private fun ensureStreamServer() {
        if (streamServer != null) return
        val server = ServerSocket(0, 50, java.net.InetAddress.getByName("127.0.0.1"))
        streamServer = server
        streamServerPort = server.localPort
        scope.launch {
            while (isActive && !server.isClosed) {
                try {
                    val socket = server.accept()
                    launch { handleStreamClient(socket) }
                } catch (_: Exception) {
                    if (!server.isClosed) Log.w(TAG, "Stream server accept failed")
                }
            }
        }
        Log.d(TAG, "Local stream server listening on 127.0.0.1:$streamServerPort")
    }

    private fun handleStreamClient(socket: Socket) {
        socket.use { s ->
            try {
                s.soTimeout = 30_000
                val input = s.getInputStream()
                val output = s.getOutputStream()
                val request = readHttpRequest(input)
                val requestLine = request.firstOrNull() ?: return
                val parts = requestLine.split(' ')
                if (parts.size < 2 || parts[0] != "GET") {
                    writeHttpError(output, 405, "Method Not Allowed")
                    return
                }

                val path = URLDecoder.decode(parts[1].substringBefore('?'), StandardCharsets.UTF_8.name())
                val pathParts = path.trim('/').split('/')
                if (pathParts.size != 3 || pathParts[0] != "stream") {
                    writeHttpError(output, 404, "Not Found")
                    return
                }

                val torrentId = pathParts[1]
                val fileIndex = pathParts[2].toIntOrNull()
                if (fileIndex == null) {
                    writeHttpError(output, 400, "Bad Request")
                    return
                }

                val rangeHeader = request.firstOrNull { it.startsWith("Range:", ignoreCase = true) }
                serveStreamRange(output, torrentId, fileIndex, rangeHeader)
            } catch (e: Exception) {
                Log.w(TAG, "Stream request failed: ${e.message}")
            }
        }
    }

    private fun readHttpRequest(input: java.io.InputStream): List<String> {
        val lines = mutableListOf<String>()
        val current = StringBuilder()
        while (true) {
            val b = input.read()
            if (b < 0) break
            if (b == '\r'.code) continue
            if (b == '\n'.code) {
                val line = current.toString()
                if (line.isEmpty()) break
                lines.add(line)
                current.clear()
            } else {
                current.append(b.toChar())
            }
            if (lines.size > 64 || current.length > 8192) break
        }
        return lines
    }

    private data class StreamFileSnapshot(
        val handle: TorrentHandle,
        val fs: FileStorage,
        val path: File,
        val size: Long,
    )

    private fun serveStreamRange(
        output: java.io.OutputStream,
        torrentId: String,
        fileIndex: Int,
        rangeHeader: String?,
    ) {
        val snapshot = synchronized(lock) {
            val handle = findHandleLocked(torrentId) ?: return@synchronized null
            val ti = handle.torrentFile() ?: return@synchronized null
            val fs = ti.files()
            if (fileIndex !in 0 until fs.numFiles()) return@synchronized null
            streamingFileIndexes[torrentId] = fileIndex
            prepareStreamingPieces(handle, fs, fileIndex)
            StreamFileSnapshot(
                handle = handle,
                fs = fs,
                path = File(saveDir, fs.filePath(fileIndex)),
                size = fs.fileSize(fileIndex),
            )
        }
        if (snapshot == null || snapshot.size <= 0L) {
            writeHttpError(output, 404, "Not Found")
            return
        }

        val requested = parseRange(rangeHeader, snapshot.size)
        val start = requested.first
        val end = requested.second
        prioritizeRange(snapshot.handle, snapshot.fs, fileIndex, start, end)

        if (!waitForRange(snapshot.handle, snapshot.fs, fileIndex, start, end, 20_000L)) {
            output.write(
                ("HTTP/1.1 503 Service Unavailable\r\n" +
                    "Retry-After: 2\r\n" +
                    "Connection: close\r\n" +
                    "Content-Length: 0\r\n\r\n")
                    .toByteArray()
            )
            return
        }

        val length = end - start + 1
        val contentType = contentTypeFor(snapshot.path.name)
        output.write(
            ("HTTP/1.1 206 Partial Content\r\n" +
                "Content-Type: $contentType\r\n" +
                "Accept-Ranges: bytes\r\n" +
                "Content-Range: bytes $start-$end/${snapshot.size}\r\n" +
                "Content-Length: $length\r\n" +
                "Connection: close\r\n\r\n")
                .toByteArray()
        )

        RandomAccessFile(snapshot.path, "r").use { raf ->
            raf.seek(start)
            val buffer = ByteArray(64 * 1024)
            var remaining = length
            while (remaining > 0) {
                val read = raf.read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt())
                if (read <= 0) break
                output.write(buffer, 0, read)
                remaining -= read
            }
        }
    }

    private fun parseRange(rangeHeader: String?, size: Long): kotlin.Pair<Long, Long> {
        if (rangeHeader == null) {
            val end = minOf(size - 1, 1024L * 1024L - 1L)
            return 0L to end
        }
        val value = rangeHeader.substringAfter(':').trim()
        val range = value.removePrefix("bytes=").substringBefore(',')
        val startText = range.substringBefore('-')
        val endText = range.substringAfter('-', "")
        val start = startText.toLongOrNull() ?: 0L
        val end = endText.toLongOrNull() ?: minOf(size - 1, start + 1024L * 1024L - 1L)
        return start.coerceIn(0L, size - 1) to end.coerceIn(start, size - 1)
    }

    private fun prioritizeRange(handle: TorrentHandle, fs: FileStorage, fileIndex: Int, start: Long, end: Long) {
        val pieceLength = fs.pieceLength().toLong().coerceAtLeast(1L)
        val fileOffset = fs.fileOffset(fileIndex)
        val startPiece = ((fileOffset + start) / pieceLength).toInt()
        val endPiece = ((fileOffset + end) / pieceLength).toInt()
        for ((offset, piece) in (startPiece..endPiece).take(128).withIndex()) {
            try {
                handle.piecePriority(piece, Priority.TOP_PRIORITY)
                handle.setPieceDeadline(piece, offset * 100, TorrentHandle.ALERT_WHEN_AVAILABLE)
            } catch (_: Exception) {
            }
        }
    }

    private fun waitForRange(
        handle: TorrentHandle,
        fs: FileStorage,
        fileIndex: Int,
        start: Long,
        end: Long,
        timeoutMs: Long,
    ): Boolean {
        val pieceLength = fs.pieceLength().toLong().coerceAtLeast(1L)
        val fileOffset = fs.fileOffset(fileIndex)
        val startPiece = ((fileOffset + start) / pieceLength).toInt()
        val endPiece = ((fileOffset + end) / pieceLength).toInt()
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            var ready = true
            for (piece in startPiece..endPiece) {
                if (!try { handle.havePiece(piece) } catch (_: Exception) { false }) {
                    ready = false
                    break
                }
            }
            if (ready) return true
            Thread.sleep(250)
        }
        return false
    }

    private fun writeHttpError(output: java.io.OutputStream, code: Int, message: String) {
        val body = message.toByteArray()
        output.write(
            ("HTTP/1.1 $code $message\r\n" +
                "Content-Type: text/plain\r\n" +
                "Content-Length: ${body.size}\r\n" +
                "Connection: close\r\n\r\n")
                .toByteArray()
        )
        output.write(body)
    }

    private fun contentTypeFor(name: String): String {
        val lower = name.lowercase()
        return when {
            lower.endsWith(".mp4") || lower.endsWith(".m4v") -> "video/mp4"
            lower.endsWith(".webm") -> "video/webm"
            lower.endsWith(".mkv") -> "video/x-matroska"
            lower.endsWith(".avi") -> "video/x-msvideo"
            else -> "application/octet-stream"
        }
    }

    private fun prioritizeStreamingPieces(handle: TorrentHandle, startPiece: Int, endPiece: Int) {
        try {
            handle.clearPieceDeadlines()
        } catch (_: Exception) {
        }

        val firstPieces = (startPiece..endPiece).take(96)
        firstPieces.forEachIndexed { offset, piece ->
            try {
                handle.piecePriority(piece, Priority.TOP_PRIORITY)
                handle.setPieceDeadline(piece, offset * 150, TorrentHandle.ALERT_WHEN_AVAILABLE)
            } catch (_: Exception) {
            }
        }

        // A few containers keep useful indexes near the end. Keep them requested,
        // but behind the opening pieces so playback can start first.
        val tailStart = maxOf(startPiece, endPiece - 3)
        for (piece in tailStart..endPiece) {
            try {
                handle.piecePriority(piece, Priority.SIX)
                handle.setPieceDeadline(piece, 20_000 + (piece - tailStart) * 250)
            } catch (_: Exception) {
            }
        }
    }

    private fun buildFilesJsonArrayLocked(torrentId: String, handle: TorrentHandle): JSONArray {
        val ti = handle.torrentFile() ?: return JSONArray()
        val fs = ti.files()
        // Try PIECE_GRANULARITY first (accurate per-piece tracking).
        // In seeding state libtorrent may return all-zeros, so if every entry is zero
        // we retry with the no-flag overload (raw byte tracking).
        val pgPiece: LongArray = try { handle.fileProgress(TorrentHandle.PIECE_GRANULARITY) } catch (_: Exception) { LongArray(0) }
        val fileProgress: LongArray = if (pgPiece.any { it > 0L }) pgPiece else {
            try { handle.fileProgress() } catch (_: Exception) { LongArray(0) }
        }

        val priorities = handle.filePriorities()
        val streamingFileIndex = streamingFileIndexes[torrentId]
        val arr = JSONArray()

        for (i in 0 until fs.numFiles()) {
            val size = fs.fileSize(i)
            // If libtorrent still reports 0 for a non-IGNORE file, fall back to disk size.
            var downloaded = fileProgress.getOrElse(i) { 0L }
            val relativePath = fs.filePath(i)
            val absolutePath = File(saveDir, relativePath).absolutePath
            if (downloaded == 0L && size > 0L) {
                val diskSize = try { File(absolutePath).length() } catch (_: Exception) { 0L }
                if (diskSize > 0L) downloaded = diskSize.coerceAtMost(size)
            }
            if (i == streamingFileIndex) {
                downloaded = streamingBufferedBytes(handle, fs, i).coerceAtMost(size)
            }
            val priority = priorities.getOrNull(i)?.let(::mapPriority) ?: "normal"
            val progress = if (size > 0L) downloaded.toDouble() / size.toDouble() else 0.0
            val contiguous = if (i == streamingFileIndex) {
                contiguousDownloadedBytes(handle, fs, i).coerceAtMost(size)
            } else {
                downloaded
            }

            arr.put(
                JSONObject()
                    .put("id", "$torrentId-$i")
                    .put("name", File(relativePath).name)
                    .put("path", absolutePath)
                    .put("size", size)
                    .put("downloadedSize", downloaded)
                    .put("contiguousDownloadedSize", contiguous)
                    .put("bufferedSize", downloaded)
                    .put("progress", progress.coerceIn(0.0, 1.0))
                    .put("priority", priority)
            )
        }

        return arr
    }

    private fun contiguousDownloadedBytes(
        handle: TorrentHandle,
        fs: FileStorage,
        fileIndex: Int,
    ): Long {
        val size = fs.fileSize(fileIndex)
        if (size <= 0L) return 0L

        val startPiece = fs.pieceIndexAtFile(fileIndex)
        val endPiece = fs.lastPieceIndexAtFile(fileIndex)
        if (startPiece < 0 || endPiece < startPiece) return 0L

        var pieces = 0L
        for (piece in startPiece..endPiece) {
            val havePiece = try { handle.havePiece(piece) } catch (_: Exception) { false }
            if (!havePiece) break
            pieces++
        }

        if (pieces == 0L) return 0L
        return (pieces * fs.pieceLength().toLong()).coerceAtMost(size)
    }

    private fun streamingBufferedBytes(
        handle: TorrentHandle,
        fs: FileStorage,
        fileIndex: Int,
    ): Long {
        val size = fs.fileSize(fileIndex)
        if (size <= 0L) return 0L

        val startPiece = fs.pieceIndexAtFile(fileIndex)
        val endPiece = fs.lastPieceIndexAtFile(fileIndex)
        if (startPiece < 0 || endPiece < startPiece) return 0L

        val pieceLength = fs.pieceLength().toLong()
        val contiguous = contiguousDownloadedBytes(handle, fs, fileIndex)
        val nextPiece = startPiece + (contiguous / pieceLength).toInt()
        if (nextPiece > endPiece) return contiguous.coerceAtMost(size)

        val partialPiece = try {
            handle.getDownloadQueue().firstOrNull { it.pieceIndex() == nextPiece }
        } catch (_: Exception) {
            null
        } ?: return contiguous.coerceAtMost(size)

        val blocks = partialPiece.blocksInPiece().coerceAtLeast(1)
        val bytesPerBlock = (pieceLength / blocks).coerceAtLeast(1L)
        val partialBytes = partialPiece.finished().toLong() * bytesPerBlock
        return (contiguous + partialBytes).coerceAtMost(size)
    }

    private fun mapPriority(priority: Priority): String = when (priority) {
        Priority.IGNORE -> "skip"
        Priority.TOP_PRIORITY, Priority.SIX, Priority.FIVE -> "high"
        else -> "normal"
    }

    private fun startPollLoop() {
        scope.launch {
            Log.d(TAG, "Poll loop started on ${Thread.currentThread().name}")
            while (isActive) {
                // Poll at 1 s while active downloads exist; back off to 5 s otherwise
                // to avoid draining battery when all torrents are completed/paused.
                val hasActive = synchronized(lock) { idToHash.isNotEmpty() } &&
                    session.stats().downloadRate() > 0
                delay(if (hasActive) 1000L else 5000L)
                emitStatusForAllHandles()
            }
        }
    }

    private fun emitStatusForAllHandles() {
        val payloads = synchronized(lock) {
            // Iterate by torrentId → hash; obtain each handle fresh from the session.
            // This avoids any dangling-pointer crash that would occur if we stored handles
            // obtained from alert callbacks (those have swigCMemOwn = false and are freed
            // together with the alert object by the GC).
            idToHash.mapNotNull { (id, hash) ->
                try {
                    if (hash.length != 40) return@mapNotNull null
                    val handle = session.find(Sha1Hash.parseHex(hash)) ?: return@mapNotNull null
                    if (!handle.isValid) return@mapNotNull null
                    emitStatusJsonLocked(id, handle.status(), handle)
                } catch (e: Exception) {
                    Log.e(TAG, "status error for $id: ${e.message}")
                    null
                }
            }
        }
        payloads.forEach { onUpdate?.invoke(it) }
    }

    private fun requestTorrentUpdates() {
        try {
            session.postTorrentUpdates()
        } catch (_: Exception) {
        }
    }

    private fun normalizeHash(hash: String): String = hash.trim().lowercase()

    private fun emitError(torrentId: String, message: String) {
        onUpdate?.invoke(
            JSONObject()
                .put("id", torrentId)
                .put("status", "error")
                .put("errorMessage", message)
                .toString()
        )
    }

    private fun extractInfoHash(magnet: String): String? {
        Regex("[?&]xt=urn:btih:([0-9a-fA-F]{40})", RegexOption.IGNORE_CASE)
            .find(magnet)?.groupValues?.get(1)?.let { return it.lowercase() }
        Regex("[?&]xt=urn:btih:([A-Z2-7]{32})", RegexOption.IGNORE_CASE)
            .find(magnet)?.groupValues?.get(1)?.let { return base32ToHex(it.uppercase()) }
        return null
    }

    private fun base32ToHex(base32: String): String {
        val alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var bits = 0L
        var bitCount = 0
        val sb = StringBuilder()
        for (c in base32) {
            val idx = alphabet.indexOf(c).takeIf { it >= 0 } ?: continue
            bits = (bits shl 5) or idx.toLong()
            bitCount += 5
            if (bitCount >= 8) {
                bitCount -= 8
                sb.append("%02x".format((bits shr bitCount) and 0xFF))
            }
        }
        return sb.toString()
    }
}
