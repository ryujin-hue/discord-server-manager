package com.discordmanager.app

import io.flutter.plugin.common.EventChannel

/**
 * Carries events from the native upload service back to the Flutter side.
 */
object UploadServiceBridge {
    private var sink: EventChannel.EventSink? = null

    fun attach(eventSink: EventChannel.EventSink) {
        sink = eventSink
    }

    fun detach() {
        sink = null
    }

    fun notifyCancelRequested() {
        sink?.success("cancel_requested")
    }

    fun notifyServiceDestroyed() {
        sink?.success("service_destroyed")
    }
}
