package com.discordmanager.app

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "com.discordmanager.app/upload_service"
        private const val EVENT_CHANNEL = "com.discordmanager.app/upload_service/events"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        startUploadService(
                            title = call.argument<String>("title") ?: "Uploading",
                            body = call.argument<String>("body") ?: "",
                            progress = call.argument<Int>("progress") ?: -1,
                            indeterminate = call.argument<Boolean>("indeterminate") ?: false,
                        )
                        result.success(null)
                    }
                    "update" -> {
                        startUploadService(
                            title = call.argument<String>("title") ?: "Uploading",
                            body = call.argument<String>("body") ?: "",
                            progress = call.argument<Int>("progress") ?: -1,
                            indeterminate = call.argument<Boolean>("indeterminate") ?: false,
                        )
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, UploadForegroundService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        if (events != null) {
                            UploadServiceBridge.attach(events)
                        }
                    }

                    override fun onCancel(arguments: Any?) {
                        UploadServiceBridge.detach()
                    }
                },
            )
    }

    private fun startUploadService(
        title: String,
        body: String,
        progress: Int,
        indeterminate: Boolean,
    ) {
        val intent = Intent(this, UploadForegroundService::class.java).apply {
            action = UploadForegroundService.ACTION_UPDATE
            putExtra(UploadForegroundService.EXTRA_TITLE, title)
            putExtra(UploadForegroundService.EXTRA_BODY, body)
            putExtra(UploadForegroundService.EXTRA_PROGRESS, progress)
            putExtra(UploadForegroundService.EXTRA_INDETERMINATE, indeterminate)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
