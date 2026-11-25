package com.bitdrix.bitdrix

import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CH = "com.bitdrix.bitdrix/torrent"
        private const val EVENT_CH  = "com.bitdrix.bitdrix/torrent_updates"
        private const val MEDIA_TRACKS_CH = "com.bitdrix.bitdrix/media_tracks"
    }

    private lateinit var torrentEngine: TorrentEngine
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The engine is process-wide: it keeps running (with the foreground
        // service) after this Activity is destroyed.
        torrentEngine = TorrentEngine.get(applicationContext)
        torrentEngine.onUpdate = { json -> runOnUiThread { eventSink?.success(json) } }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CH)
            .setMethodCallHandler { call, result ->
                val eng = torrentEngine
                try {
                    when (call.method) {
                        "addTorrentFile" -> {
                            eng.addTorrentFile(call.argument<String>("filePath")!!, call.argument<String>("id")!!)
                            result.success(null)
                        }
                        "addMagnet" -> {
                            eng.addMagnet(call.argument<String>("magnet")!!, call.argument<String>("id")!!)
                            result.success(null)
                        }
                        "pause" -> {
                            eng.pause(call.argument<String>("id")!!)
                            result.success(null)
                        }
                        "resume" -> {
                            eng.resume(call.argument<String>("id")!!)
                            result.success(null)
                        }
                        "remove" -> {
                            eng.remove(call.argument<String>("id")!!, call.argument<Boolean>("deleteFiles") ?: false)
                            result.success(null)
                        }
                        "refresh" -> {
                            eng.refresh()
                            result.success(null)
                        }
                        "getFiles" -> result.success(eng.getFiles(call.argument<String>("id")!!))
                        "selectFile" -> result.success(
                            eng.selectFile(call.argument<String>("id")!!, call.argument<String>("fileId")!!)
                        )
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    Log.e("BitdrixTorrent", "${call.method} failed", e)
                    result.error("TORRENT_ERROR", e.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_TRACKS_CH)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAudioTracks" -> {
                        try {
                            val source = call.argument<String>("source").orEmpty()
                            result.success(readAudioTracks(source))
                        } catch (e: Exception) {
                            Log.w("BitdrixMediaTracks", "Could not read audio tracks", e)
                            result.success(emptyList<Map<String, Any?>>())
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CH)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    // Push the restored torrents to Dart straight away.
                    torrentEngine.refresh()
                }
                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            })
    }

    private fun readAudioTracks(source: String): List<Map<String, Any?>> {
        if (source.isBlank()) return emptyList()

        val extractor = MediaExtractor()
        try {
            when {
                source.startsWith("content://") -> {
                    extractor.setDataSource(applicationContext, Uri.parse(source), null)
                }
                source.startsWith("file://") -> {
                    extractor.setDataSource(Uri.parse(source).path.orEmpty())
                }
                source.startsWith("http://") || source.startsWith("https://") -> {
                    extractor.setDataSource(source, emptyMap())
                }
                else -> extractor.setDataSource(source)
            }

            val tracks = mutableListOf<Map<String, Any?>>()
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getOptionalString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") != true) continue

                val language = format.getOptionalString(MediaFormat.KEY_LANGUAGE)
                val label = buildAudioTrackLabel(tracks.size, language, mime)
                tracks.add(
                    mapOf(
                        "index" to i,
                        "language" to language,
                        "mimeType" to mime,
                        "label" to label
                    )
                )
            }
            return tracks
        } finally {
            extractor.release()
        }
    }

    private fun MediaFormat.getOptionalString(key: String): String? =
        if (containsKey(key)) getString(key)?.takeIf { it.isNotBlank() } else null

    private fun buildAudioTrackLabel(position: Int, language: String?, mime: String?): String {
        val lang = language?.uppercase()?.takeIf { it.isNotBlank() }
        val codec = mime
            ?.substringAfter('/')
            ?.uppercase()
            ?.takeIf { it.isNotBlank() }

        return listOfNotNull("Audio ${position + 1}", lang, codec).joinToString(" · ")
    }

    override fun onStop() {
        super.onStop()
        if (::torrentEngine.isInitialized) torrentEngine.saveAll()
    }

    override fun onDestroy() {
        // Detach from the engine but keep it running for background downloads.
        if (::torrentEngine.isInitialized) torrentEngine.onUpdate = null
        eventSink = null
        super.onDestroy()
    }
}
