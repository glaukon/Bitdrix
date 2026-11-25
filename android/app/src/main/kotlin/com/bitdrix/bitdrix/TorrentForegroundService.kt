package com.bitdrix.bitdrix

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import java.util.Locale

/**
 * Keeps the process alive while torrents are downloading or a file is being
 * streamed, showing an ongoing notification with progress. Stops itself as
 * soon as there is nothing left to do.
 */
class TorrentForegroundService : Service() {

    companion object {
        private const val TAG = "BitdrixService"
        private const val CHANNEL_ID = "bitdrix_downloads"
        private const val NOTIFICATION_ID = 1001
        private const val TICK_MS = 2_000L

        @Volatile
        private var running = false

        fun ensureRunning(context: Context) {
            if (running) return
            try {
                ContextCompat.startForegroundService(
                    context,
                    Intent(context, TorrentForegroundService::class.java),
                )
            } catch (e: Exception) {
                // Starting a foreground service from the background is not allowed
                // on Android 12+; the next call from the foreground will succeed.
                Log.w(TAG, "Could not start foreground service: ${e.message}")
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var idleTicks = 0

    private val tick = object : Runnable {
        override fun run() {
            val summary = TorrentEngine.peek()?.summary()
            if (summary == null || (summary.active == 0 && !summary.streaming)) {
                // Give the engine a moment (e.g. a magnet resolving) before stopping.
                if (++idleTicks >= 3) {
                    stopSelf()
                    return
                }
            } else {
                idleTicks = 0
                notifyProgress(summary)
            }
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, buildNotification("Preparando descargas…"), type)
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_NOT_STICKY
    }

    // Android 15 caps dataSync services; stop cleanly when the system asks.
    override fun onTimeout(startId: Int, fgsType: Int) {
        TorrentEngine.peek()?.saveAll()
        stopSelf()
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacks(tick)
        TorrentEngine.peek()?.saveAll()
        super.onDestroy()
    }

    private fun notifyProgress(summary: TorrentEngine.Summary) {
        val text = buildString {
            if (summary.streaming) append("Reproduciendo · ")
            append(
                when (summary.active) {
                    0 -> "Sin descargas activas"
                    1 -> "1 descarga activa"
                    else -> "${summary.active} descargas activas"
                }
            )
            append(" · ").append(formatSpeed(summary.downloadRate))
        }
        getSystemService(NotificationManager::class.java)?.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun buildNotification(text: String) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Bitdrix")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(launchIntent())
            .build()

    private fun launchIntent(): PendingIntent? {
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        return PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(CHANNEL_ID, "Descargas", NotificationManager.IMPORTANCE_LOW).apply {
            description = "Progreso de las descargas de torrents"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    private fun formatSpeed(bytesPerSecond: Long): String {
        val kb = bytesPerSecond / 1024.0
        return if (kb >= 1024) String.format(Locale.US, "%.1f MB/s", kb / 1024) else String.format(Locale.US, "%.0f KB/s", kb)
    }
}
