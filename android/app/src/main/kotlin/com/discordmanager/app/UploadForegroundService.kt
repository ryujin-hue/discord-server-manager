package com.discordmanager.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Keeps the upload running while the app is in the background and shows the
 * current progress with a cancel action.
 */
class UploadForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "dsm_upload_progress"
        const val NOTIFICATION_ID = 4201
        const val ACTION_START = "com.discordmanager.app.action.START_UPLOAD"
        const val ACTION_UPDATE = "com.discordmanager.app.action.UPDATE_UPLOAD"
        const val ACTION_STOP = "com.discordmanager.app.action.STOP_UPLOAD"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_INDETERMINATE = "indeterminate"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                createChannel()
                val notification = buildNotification(
                    title = intent?.getStringExtra(EXTRA_TITLE) ?: "Uploading",
                    body = intent?.getStringExtra(EXTRA_BODY) ?: "",
                    progress = intent?.getIntExtra(EXTRA_PROGRESS, -1) ?: -1,
                    indeterminate = intent?.getBooleanExtra(EXTRA_INDETERMINATE, false) ?: false,
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        UploadServiceBridge.notifyServiceDestroyed()
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Upload progress",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows the progress of files being sent to Discord."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(
        title: String,
        body: String,
        progress: Int,
        indeterminate: Boolean,
    ): Notification {
        val cancelIntent = Intent(this, UploadCancelReceiver::class.java).apply {
            action = UploadCancelReceiver.ACTION_CANCEL
        }
        val cancelPendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(
                NotificationCompat.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Cancel",
                    cancelPendingIntent,
                ).build(),
            )

        if (indeterminate) {
            builder.setProgress(0, 0, true)
        } else if (progress >= 0) {
            builder.setProgress(100, progress, false)
        }
        return builder.build()
    }
}
