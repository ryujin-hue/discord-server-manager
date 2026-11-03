import 'dart:async';

import 'package:flutter/services.dart';

/// The events the native upload service sends to the Flutter side.
enum UploadServiceEvent {
  cancelRequested,
  serviceDestroyed;

  static UploadServiceEvent? fromName(String? name) {
    switch (name) {
      case 'cancel_requested':
        return UploadServiceEvent.cancelRequested;
      case 'service_destroyed':
        return UploadServiceEvent.serviceDestroyed;
      default:
        return null;
    }
  }
}

/// Keeps an upload running while the app is in the background.
abstract class UploadBackgroundService {
  Future<void> start({
    required String title,
    required String body,
    int progress,
    bool indeterminate,
  });

  Future<void> update({
    required String title,
    required String body,
    int progress,
    bool indeterminate,
  });

  Future<void> stop();

  /// The events of the service, for example a tap on the cancel action.
  Stream<UploadServiceEvent> get events;
}

/// The implementation that talks to the Android foreground service.
class PlatformUploadBackgroundService implements UploadBackgroundService {
  PlatformUploadBackgroundService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel(methodChannelName),
       _eventChannel = eventChannel ?? const EventChannel(eventChannelName);

  static const String methodChannelName =
      'com.discordmanager.app/upload_service';
  static const String eventChannelName =
      'com.discordmanager.app/upload_service/events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<UploadServiceEvent>? _events;

  @override
  Stream<UploadServiceEvent> get events {
    final existing = _events;
    if (existing != null) {
      return existing;
    }
    final stream = _eventChannel
        .receiveBroadcastStream()
        .map((dynamic name) => UploadServiceEvent.fromName(name as String?))
        .where((UploadServiceEvent? event) => event != null)
        .cast<UploadServiceEvent>();
    _events = stream;
    return stream;
  }

  @override
  Future<void> start({
    required String title,
    required String body,
    int progress = -1,
    bool indeterminate = false,
  }) async {
    await _methodChannel.invokeMethod<void>('start', <String, Object?>{
      'title': title,
      'body': body,
      'progress': progress,
      'indeterminate': indeterminate,
    });
  }

  @override
  Future<void> update({
    required String title,
    required String body,
    int progress = -1,
    bool indeterminate = false,
  }) async {
    await _methodChannel.invokeMethod<void>('update', <String, Object?>{
      'title': title,
      'body': body,
      'progress': progress,
      'indeterminate': indeterminate,
    });
  }

  @override
  Future<void> stop() async {
    await _methodChannel.invokeMethod<void>('stop');
  }
}
