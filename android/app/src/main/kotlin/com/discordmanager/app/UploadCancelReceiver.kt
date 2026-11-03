package com.discordmanager.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Handles the cancel action of the upload progress notification.
 */
class UploadCancelReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_CANCEL = "com.discordmanager.app.action.CANCEL_UPLOAD"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_CANCEL) {
            return
        }
        UploadServiceBridge.notifyCancelRequested()
        context.stopService(Intent(context, UploadForegroundService::class.java))
    }
}
