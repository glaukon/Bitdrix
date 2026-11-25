package com.bitdrix.bitdrix

import android.content.Context
import android.os.Environment
import android.util.Log
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import org.libtorrent4j.*
import org.libtorrent4j.alerts.*
import org.libtorrent4j.swig.error_code
import org.libtorrent4j.swig.libtorrent
import java.io.File

private const val TAG = "BitdrixTorrent"

/**
 * Process-wide BitTorrent engine backed by libtorrent4j.
 *
 * It outlives the Activity so downloads keep going while the app is in the
 * background (kept alive by [TorrentForegroundService]). Every torrent is
 * persisted under `filesDir/torrents` (a small JSON meta file plus libtorrent
 * resume data) and restored on the next start.
 */
class TorrentEngine private constructor(private val appContext: Context) {

    companion object {
        @Volatile
        private var instance: TorrentEngine? = null

        fun get(context: Context): TorrentEngine =
            instance ?: synchronized(this) {
                instance ?: TorrentEngine(context.applicationContext).also { instance = it }
            }

        /** Returns the engine only if it was already created (never creates one). */
        fun peek(): TorrentEngine? = instance
    }

    data class Summary(val active: Int, val downloadRate: Long, val streaming: Boolean)

    private val session = SessionManager()
    private val lock = Any()

    // infoHash (hex, lowercase) ↔ torrentId. Handles are never cached: handles
    // obtained from alerts dangle once the alert is freed.
    private val hashToId = HashMap<String, String>()
    private val idToHash = HashMap<String, String>()
    // Magnets whose hash could not be parsed up front; resolved on ADD_TORRENT.
    private val pendingIds = ArrayDeque<String>()
    private val metas = HashMap<String, JSONObject>()
    // torrentId → file index currently being streamed.
    private val streamingFileIndexes = HashMap<String, Int>()

    /** Receives status JSON payloads (set by the Activity while Flutter is attached). */
    @Volatile
    var onUpdate: ((String) -> Unit)? = null

    val saveDir: File = run {
        val extDir = appContext.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
        File(extDir ?: appContext.filesDir, "Bitdrix").also { it.mkdirs() }
    }
    private val stateDir: File = File(appContext.filesDir, "torrents").also { it.mkdirs() }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val streamServer = StreamServer(this)

    private val alertListener = object : AlertListener {
        override fun types(): IntArray? = null

        override fun alert(alert: Alert<*>) {
            try {
                handleAlert(alert)
            } catch (e: Exception) {
                Log.w(TAG, "alert ${alert.type()} failed: ${e.message}")
            }
        }
    }

    init {
        session.addListener(alertListener)
        session.start()
        session.startDht()
        Log.d(TAG, "Session started, saveDir=$saveDir")
        restoreTorrents()
        startPollLoop()
    }

    // ── Public API ────────────────────────────────────────────────────────────

    fun addTorrentFile(filePath: String, torrentId: String) {
        scope.launch {
            try {
                val src = File(filePath)
                if (!src.exists()) {
                    emitError(torrentId, "Archivo torrent no encontrado: $filePath")
                    return@launch
                }
                // Keep our own copy: picked files usually live in a cache dir.
                val copy = File(stateDir, "$torrentId.torrent")
                src.copyTo(copy, overwrite = true)

                val ti = TorrentInfo(copy)
                val hash = normalizeHash(ti.infoHash().toHex())
                val meta = newMeta(torrentId).put("hash", hash).put("torrentFile", copy.absolutePath)
                synchronized(lock) {
                    registerLocked(torrentId, hash)
                    metas[torrentId] = meta
                }
                writeMeta(torrentId, meta)

                val p = org.libtorrent4j.swig.add_torrent_params()
                p.set_ti(ti.swig())
                p.setSave_path(saveDir.absolutePath)
                session.swig().async_add_torrent(p)
                TorrentForegroundService.ensureRunning(appContext)
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
                val hash = extractInfoHash(magnetLink)?.let(::normalizeHash)
                val meta = newMeta(torrentId).put("magnet", magnetLink)
                if (hash != null) meta.put("hash", hash)
                synchronized(lock) {
                    if (hash != null) registerLocked(torrentId, hash) else pendingIds.addLast(torrentId)
                    metas[torrentId] = meta
                }
                writeMeta(torrentId, meta)

                val params = AddTorrentParams.parseMagnetUri(magnetLink)
                params.savePath = saveDir.absolutePath
                session.swig().async_add_torrent(params.swig())
                TorrentForegroundService.ensureRunning(appContext)
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.e(TAG, "addMagnet exception: ${e.message}", e)
                synchronized(lock) { pendingIds.remove(torrentId) }
                emitError(torrentId, e.message ?: "Error desconocido")
            }
        }
    }

    fun pause(torrentId: String) {
        synchronized(lock) {
            findHandleLocked(torrentId)?.let { h ->
                // Auto-managed torrents get resumed by the session queue, so a
                // user pause must take the torrent out of auto management.
                h.unsetFlags(TorrentFlags.AUTO_MANAGED)
                h.pause()
                h.saveResumeData(TorrentHandle.SAVE_INFO_DICT)
            }
        }
        emitStatusForAllHandles()
    }

    fun resume(torrentId: String) {
        synchronized(lock) {
            findHandleLocked(torrentId)?.let { h ->
                h.setFlags(TorrentFlags.AUTO_MANAGED)
                h.resume()
            }
        }
        TorrentForegroundService.ensureRunning(appContext)
        emitStatusForAllHandles()
    }

    fun remove(torrentId: String, deleteFiles: Boolean) {
        synchronized(lock) {
            val handle = findHandleLocked(torrentId)
            idToHash.remove(torrentId)?.let(hashToId::remove)
            hashToId.entries.removeIf { it.value == torrentId }
            pendingIds.remove(torrentId)
            streamingFileIndexes.remove(torrentId)
            metas.remove(torrentId)
            if (handle != null) {
                val flags = if (deleteFiles) SessionHandle.DELETE_FILES else org.libtorrent4j.swig.remove_flags_t()
                session.remove(handle, flags)
            }
        }
        listOf("json", "resume", "torrent").forEach { File(stateDir, "$torrentId.$it").delete() }
    }

    /** Forces an immediate status emission for every torrent. */
    fun refresh() {
        scope.launch { emitStatusForAllHandles() }
    }

    fun getFiles(torrentId: String): String = synchronized(lock) {
        val handle = findHandleLocked(torrentId) ?: return@synchronized "[]"
        buildFilesJsonArrayLocked(torrentId, handle).toString()
    }

    /**
     * Marks [fileId] as the file being streamed and returns its local HTTP URL.
     * The torrent keeps downloading the other files, but the streamed file gets
     * top priority and time-critical piece deadlines.
     */
    fun selectFile(torrentId: String, fileId: String): String? {
        synchronized(lock) {
            val handle = findHandleLocked(torrentId) ?: return null
            val ti = handle.torrentFile() ?: return null
            val fs = ti.files()
            val fileIndex = fileId.substringAfterLast('-').toIntOrNull() ?: return null
            if (fileIndex !in 0 until fs.numFiles()) return null

            val current = handle.filePriorities()
            val priorities = Array(fs.numFiles()) { i ->
                when {
                    i == fileIndex -> Priority.TOP_PRIORITY
                    current.getOrNull(i) == Priority.IGNORE -> Priority.IGNORE
                    else -> Priority.DEFAULT
                }
            }
            handle.prioritizeFiles(priorities)
            streamingFileIndexes[torrentId] = fileIndex

            handle.setFlags(TorrentFlags.AUTO_MANAGED)
            handle.resume()
            try { handle.queuePositionTop() } catch (_: Exception) {}
            try { handle.forceReannounce(0, -1, TorrentHandle.IGNORE_MIN_INTERVAL) } catch (_: Exception) {}

            // Warm up the start and the tail (container indexes) before the player connects.
            val startPiece = fs.pieceIndexAtFile(fileIndex)
            val endPiece = fs.lastPieceIndexAtFile(fileIndex)
            if (startPiece in 0..endPiece) {
                try { handle.setSequentialRange(startPiece, endPiece) } catch (_: Exception) {}
                setDeadlines(handle, startPiece, endPiece, readAheadPieces(fs))
                for ((i, piece) in (maxOf(startPiece, endPiece - 1)..endPiece).withIndex()) {
                    try { handle.setPieceDeadline(piece, 1_500 + i * 250) } catch (_: Exception) {}
                }
            }
        }
        TorrentForegroundService.ensureRunning(appContext)
        return streamServer.urlFor(torrentId, fileIndexOf(fileId))
    }

    fun summary(): Summary {
        var active = 0
        var rate = 0L
        synchronized(lock) {
            for (hash in idToHash.values) {
                val h = findByHash(hash) ?: continue
                val st = try { h.status() } catch (_: Exception) { continue }
                val paused = st.flags().and_(TorrentFlags.PAUSED).non_zero()
                if (!paused && !st.isFinished) active++
                rate += st.downloadRate().toLong()
            }
        }
        return Summary(active, rate, streamServer.activeClients() > 0)
    }

    /** Persists resume data for every torrent (call when the UI goes away). */
    fun saveAll() {
        synchronized(lock) {
            for (hash in idToHash.values) {
                try {
                    findByHash(hash)?.saveResumeData(TorrentHandle.SAVE_INFO_DICT)
                } catch (_: Exception) {
                }
            }
        }
    }

    // ── Streaming support (used by StreamServer) ──────────────────────────────

    internal data class StreamTarget(
        val handle: TorrentHandle,
        val fs: FileStorage,
        val index: Int,
        val file: File,
        val size: Long,
    )

    internal fun streamTarget(torrentId: String, fileIndex: Int): StreamTarget? = synchronized(lock) {
        val handle = findHandleLocked(torrentId) ?: return@synchronized null
        val ti = handle.torrentFile() ?: return@synchronized null
        val fs = ti.files()
        if (fileIndex !in 0 until fs.numFiles()) return@synchronized null
        streamingFileIndexes[torrentId] = fileIndex
        StreamTarget(handle, fs, fileIndex, File(saveDir, fs.filePath(fileIndex)), fs.fileSize(fileIndex))
    }

    internal fun readAheadPieces(fs: FileStorage): Int {
        val pieceLength = fs.pieceLength().toLong().coerceAtLeast(1L)
        return (24L * 1024 * 1024 / pieceLength).toInt().coerceIn(6, 64)
    }

    /** Gives the next [count] missing pieces from [fromPiece] increasing deadlines. */
    internal fun setDeadlines(handle: TorrentHandle, fromPiece: Int, lastPiece: Int, count: Int) {
        var slot = 0
        var piece = fromPiece
        while (piece <= lastPiece && slot < count) {
            try {
                if (!handle.havePiece(piece)) {
                    handle.piecePriority(piece, Priority.TOP_PRIORITY)
                    handle.setPieceDeadline(piece, slot * 200, TorrentHandle.ALERT_WHEN_AVAILABLE)
                    slot++
                }
            } catch (_: Exception) {
                return
            }
            piece++
        }
    }

    // ── Alerts ────────────────────────────────────────────────────────────────

    private fun handleAlert(alert: Alert<*>) {
        when (alert.type()) {
            AlertType.ADD_TORRENT -> {
                val a = alert as AddTorrentAlert
                if (a.error().isError) {
                    Log.w(TAG, "ADD_TORRENT error: ${a.error().message}")
                    return
                }
                val hash = normalizeHash(a.handle().infoHash().toHex())
                synchronized(lock) {
                    if (hashToId[hash] == null && pendingIds.isNotEmpty()) {
                        val id = pendingIds.removeFirst()
                        registerLocked(id, hash)
                        metas[id]?.let { writeMeta(id, it.put("hash", hash)) }
                    }
                }
                scope.launch { emitStatusForAllHandles() }
            }
            AlertType.METADATA_RECEIVED -> {
                // Persist the info dict so a restart does not need the swarm again.
                (alert as MetadataReceivedAlert).handle().saveResumeData(TorrentHandle.SAVE_INFO_DICT)
                scope.launch { emitStatusForAllHandles() }
            }
            AlertType.TORRENT_FINISHED -> {
                (alert as TorrentFinishedAlert).handle().saveResumeData(TorrentHandle.SAVE_INFO_DICT)
                scope.launch { emitStatusForAllHandles() }
            }
            AlertType.SAVE_RESUME_DATA -> {
                val a = alert as SaveResumeDataAlert
                val hash = normalizeHash(a.handle().infoHash().toHex())
                val id = synchronized(lock) { hashToId[hash] } ?: return
                val bytes = AddTorrentParams.writeResumeDataBuf(a.params())
                scope.launch {
                    try {
                        val tmp = File(stateDir, "$id.resume.tmp")
                        tmp.writeBytes(bytes)
                        tmp.renameTo(File(stateDir, "$id.resume").also { it.delete() })
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not write resume data for $id: ${e.message}")
                    }
                }
            }
            AlertType.TORRENT_ERROR -> {
                val a = alert as TorrentErrorAlert
                val hash = normalizeHash(a.handle().infoHash().toHex())
                val id = synchronized(lock) { hashToId[hash] } ?: return
                emitError(id, a.error().message)
            }
            else -> {}
        }
    }

    // ── Persistence ───────────────────────────────────────────────────────────

    private fun newMeta(id: String) = JSONObject().put("id", id).put("addedAt", System.currentTimeMillis())

    private fun writeMeta(id: String, meta: JSONObject) {
        try {
            File(stateDir, "$id.json").writeText(meta.toString())
        } catch (e: Exception) {
            Log.w(TAG, "Could not write meta for $id: ${e.message}")
        }
    }

    private fun restoreTorrents() {
        val files = stateDir.listFiles { f -> f.name.endsWith(".json") } ?: return
        for (metaFile in files) {
            try {
                val meta = JSONObject(metaFile.readText())
                val id = meta.getString("id")
                val hash = meta.optString("hash").takeIf { it.length == 40 }
                val params = loadParams(id, meta) ?: continue
                params.setSave_path(saveDir.absolutePath)
                synchronized(lock) {
                    metas[id] = meta
                    if (hash != null) registerLocked(id, hash) else pendingIds.addLast(id)
                }
                session.swig().async_add_torrent(params)
                Log.d(TAG, "Restored torrent id=$id hash=$hash")
            } catch (e: Exception) {
                Log.w(TAG, "Could not restore ${metaFile.name}: ${e.message}")
            }
        }
    }

    private fun loadParams(id: String, meta: JSONObject): org.libtorrent4j.swig.add_torrent_params? {
        val resume = File(stateDir, "$id.resume")
        if (resume.exists()) {
            val ec = error_code()
            val p = libtorrent.read_resume_data_ex(Vectors.bytes2byte_vector(resume.readBytes()), ec)
            if (ec.value() == 0) return p
            Log.w(TAG, "Bad resume data for $id: ${ec.message()}")
        }
        meta.optString("torrentFile").takeIf { it.isNotEmpty() && File(it).exists() }?.let {
            val p = org.libtorrent4j.swig.add_torrent_params()
            p.set_ti(TorrentInfo(File(it)).swig())
            return p
        }
        meta.optString("magnet").takeIf { it.isNotEmpty() }?.let {
            return AddTorrentParams.parseMagnetUri(it).swig()
        }
        return null
    }

    // ── Status ────────────────────────────────────────────────────────────────

    private fun registerLocked(id: String, hash: String) {
        hashToId[hash] = id
        idToHash[id] = hash
    }

    private fun findByHash(hash: String): TorrentHandle? {
        if (hash.length != 40) return null
        return try {
            session.find(Sha1Hash.parseHex(hash))?.takeIf { it.isValid }
        } catch (_: RuntimeException) {
            null
        }
    }

    private fun findHandleLocked(torrentId: String): TorrentHandle? =
        idToHash[torrentId]?.let(::findByHash)

    private fun fileIndexOf(fileId: String): Int = fileId.substringAfterLast('-').toIntOrNull() ?: 0

    private fun statusJsonLocked(id: String, handle: TorrentHandle): String {
        val st = handle.status()
        val state = st.state()
        val isPaused = st.flags().and_(TorrentFlags.PAUSED).non_zero()
        val statusStr = when {
            st.isFinished || state == TorrentStatus.State.FINISHED || state == TorrentStatus.State.SEEDING -> "completed"
            isPaused -> "paused"
            state == TorrentStatus.State.DOWNLOADING || state == TorrentStatus.State.DOWNLOADING_METADATA -> "downloading"
            else -> "queued"
        }
        val name = st.name().ifBlank { handle.torrentFile()?.name().orEmpty() }.ifBlank { "Resolviendo metadatos..." }
        val meta = metas[id]
        return JSONObject()
            .put("id", id)
            .put("infoHash", idToHash[id])
            .put("name", name)
            .put("progress", st.progress().toDouble())
            .put("downloadSpeed", st.downloadRate().toLong())
            .put("uploadSpeed", st.uploadRate().toLong())
            .put("peers", st.numPeers())
            .put("seeds", st.numSeeds())
            .put("downloadedSize", st.totalWantedDone())
            .put("uploadedSize", st.allTimeUpload())
            .put("totalSize", st.totalWanted())
            .put("status", statusStr)
            .put("hasMetadata", st.hasMetadata())
            .put("addedAt", meta?.optLong("addedAt") ?: 0L)
            .put("magnet", meta?.optString("magnet")?.ifEmpty { null })
            .put("files", buildFilesJsonArrayLocked(id, handle))
            .toString()
    }

    private fun buildFilesJsonArrayLocked(torrentId: String, handle: TorrentHandle): JSONArray {
        val ti = handle.torrentFile() ?: return JSONArray()
        val fs = ti.files()
        val fileProgress: LongArray = try {
            handle.fileProgress(TorrentHandle.PIECE_GRANULARITY)
        } catch (_: Exception) {
            LongArray(0)
        }
        val priorities = handle.filePriorities()
        val streamingIndex = streamingFileIndexes[torrentId]
        val arr = JSONArray()

        for (i in 0 until fs.numFiles()) {
            val size = fs.fileSize(i)
            val relativePath = fs.filePath(i)
            val downloaded = fileProgress.getOrElse(i) { 0L }.coerceIn(0L, size)
            val contiguous = if (i == streamingIndex) contiguousBytes(handle, fs, i) else downloaded
            arr.put(
                JSONObject()
                    .put("id", "$torrentId-$i")
                    .put("index", i)
                    .put("name", File(relativePath).name)
                    .put("path", File(saveDir, relativePath).absolutePath)
                    .put("size", size)
                    .put("downloadedSize", downloaded)
                    .put("contiguousDownloadedSize", contiguous)
                    .put("bufferedSize", contiguous)
                    .put("progress", if (size > 0L) downloaded.toDouble() / size else 0.0)
                    .put("priority", priorities.getOrNull(i)?.let(::mapPriority) ?: "normal")
            )
        }
        return arr
    }

    private fun contiguousBytes(handle: TorrentHandle, fs: FileStorage, fileIndex: Int): Long {
        val size = fs.fileSize(fileIndex)
        val startPiece = fs.pieceIndexAtFile(fileIndex)
        val endPiece = fs.lastPieceIndexAtFile(fileIndex)
        if (size <= 0L || startPiece < 0 || endPiece < startPiece) return 0L
        val pieceLength = fs.pieceLength().toLong()
        val fileOffset = fs.fileOffset(fileIndex)
        var piece = startPiece
        while (piece <= endPiece && (try { handle.havePiece(piece) } catch (_: Exception) { false })) piece++
        if (piece == startPiece) return 0L
        // Bytes of the file covered by the contiguous run of pieces.
        return ((piece.toLong() * pieceLength) - fileOffset).coerceIn(0L, size)
    }

    private fun mapPriority(priority: Priority): String = when (priority) {
        Priority.IGNORE -> "skip"
        Priority.TOP_PRIORITY, Priority.SIX, Priority.FIVE -> "high"
        else -> "normal"
    }

    private fun startPollLoop() {
        scope.launch {
            var tick = 0
            while (isActive) {
                val hasTorrents = synchronized(lock) { idToHash.isNotEmpty() }
                delay(if (hasTorrents) 1000L else 3000L)
                emitStatusForAllHandles()
                // Periodically flush resume data for torrents that changed.
                if (++tick % 30 == 0) saveModified()
            }
        }
    }

    private fun saveModified() {
        synchronized(lock) {
            for (hash in idToHash.values) {
                try {
                    val h = findByHash(hash) ?: continue
                    if (h.needSaveResumeData()) h.saveResumeData(TorrentHandle.SAVE_INFO_DICT)
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun emitStatusForAllHandles() {
        val payloads = synchronized(lock) {
            idToHash.mapNotNull { (id, hash) ->
                try {
                    val handle = findByHash(hash) ?: return@mapNotNull null
                    statusJsonLocked(id, handle)
                } catch (e: Exception) {
                    Log.e(TAG, "status error for $id: ${e.message}")
                    null
                }
            }
        }
        val sink = onUpdate ?: return
        payloads.forEach(sink)
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
