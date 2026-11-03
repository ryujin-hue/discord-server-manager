import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/redaction.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/background_service.dart';
import '../data/destination_repository.dart';
import '../data/history_repository.dart';
import '../data/queue_repository.dart';
import '../data/upload_engine.dart';
import '../domain/destination.dart';
import '../domain/picked_media.dart';
import '../domain/queue_item.dart';
import '../domain/queue_state.dart';
import '../domain/upload_failure.dart';

/// The destinations of the media sender.
final destinationRepositoryProvider = Provider<DestinationRepository>(
  (ref) => DestinationRepository(
    ref.watch(databaseProvider),
    ref.watch(secretStoreProvider),
  ),
);

/// The queue of the media sender.
final queueRepositoryProvider = Provider<QueueRepository>(
  (ref) => QueueRepository(ref.watch(databaseProvider)),
);

/// The history of the media sender.
final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(databaseProvider)),
);

/// The engine that sends the files.
final uploadEngineProvider = Provider<UploadEngine>(
  (ref) => UploadEngine(dio: ref.watch(uploadDioProvider)),
);

/// The bridge to the Android foreground service.
final backgroundServiceProvider = Provider<UploadBackgroundService>(
  (ref) => PlatformUploadBackgroundService(),
);

/// The destinations the user configured.
final destinationsProvider = FutureProvider<List<Destination>>(
  (ref) => ref.watch(destinationRepositoryProvider).list(),
);

/// The queue of the media sender.
class UploadController extends Notifier<AsyncValue<List<QueueItem>>> {
  @override
  AsyncValue<List<QueueItem>> build() {
    ref.onDispose(() {
      _cancelToken?.cancel('The controller was disposed.');
      _serviceSubscription?.cancel();
    });
    _listenForServiceEvents();
    unawaited(_restoreAfterRestart());
    return const AsyncValue<List<QueueItem>>.loading();
  }

  QueueRepository get _queue => ref.read(queueRepositoryProvider);
  DestinationRepository get _destinations =>
      ref.read(destinationRepositoryProvider);
  HistoryRepository get _history => ref.read(historyRepositoryProvider);
  UploadEngine get _engine => ref.read(uploadEngineProvider);

  CancelToken? _cancelToken;
  bool _running = false;
  bool _paused = false;
  StreamSubscription<UploadServiceEvent>? _serviceSubscription;

  /// The files that are ready to be sent.
  Future<void> enqueue({
    required List<PickedMedia> media,
    required Destination destination,
  }) async {
    for (final item in media) {
      await _queue.add(
        destinationId: destination.id,
        destinationName: destination.name,
        media: item,
      );
    }
    await _reload();
  }

  /// Sends everything that is pending.
  Future<void> send() async {
    if (_running) {
      return;
    }
    _paused = false;
    _running = true;
    try {
      while (true) {
        if (_paused) {
          break;
        }
        final items = await _queue.list();
        final pending = items
            .where((QueueItem item) => item.state == QueueState.pending)
            .toList(growable: false);
        if (pending.isEmpty) {
          break;
        }
        final group = _groupOf(pending);
        await _uploadGroup(group);
      }
    } finally {
      _running = false;
      await _stopService();
    }
  }

  /// Pauses the running upload. The current file is cancelled and stays in
  /// the queue.
  Future<void> pause() async {
    _paused = true;
    _cancelToken?.cancel('The upload was paused.');
    final items = await _queue.list();
    for (final item in items) {
      if (item.state == QueueState.uploading) {
        await _queue.updateState(
          item.id,
          QueueState.paused,
          errorCode: null,
          errorMessage: null,
        );
      }
    }
    await _reload();
  }

  /// Continues a paused queue.
  Future<void> resume() async {
    _paused = false;
    final items = await _queue.list();
    for (final item in items) {
      if (item.state == QueueState.paused) {
        await _queue.updateState(item.id, QueueState.pending);
      }
    }
    await _reload();
    await send();
  }

  /// Cancels the whole queue.
  Future<void> cancelAll() async {
    _paused = true;
    _cancelToken?.cancel('The upload was cancelled.');
    final items = await _queue.list();
    for (final item in items) {
      if (item.state == QueueState.pending ||
          item.state == QueueState.uploading ||
          item.state == QueueState.paused) {
        await _queue.updateState(item.id, QueueState.cancelled);
      }
    }
    await _reload();
    await _stopService();
  }

  /// Cancels one file.
  Future<void> cancelItem(int id) async {
    final items = await _queue.list();
    final item = items.where((QueueItem entry) => entry.id == id).firstOrNull;
    if (item == null) {
      return;
    }
    if (item.state == QueueState.uploading) {
      _cancelToken?.cancel('The upload was cancelled.');
    }
    await _queue.updateState(id, QueueState.cancelled);
    await _reload();
  }

  /// Puts a failed, cancelled or interrupted file back into the queue.
  Future<void> retryItem(int id) async {
    final items = await _queue.list();
    final item = items.where((QueueItem entry) => entry.id == id).firstOrNull;
    if (item == null) {
      return;
    }
    if (!File(item.sourcePath).existsSync()) {
      await _queue.updateState(
        id,
        QueueState.sourceMissing,
        errorCode: UploadErrorCode.unsupportedFile.code,
        errorMessage: 'The file is no longer available on this device.',
      );
      await _reload();
      return;
    }
    await _queue.updateState(id, QueueState.pending);
    await _reload();
  }

  /// Removes one file from the queue. The source file is never touched.
  Future<void> removeItem(int id) async {
    await _queue.remove(id);
    await _reload();
  }

  /// Removes every file that reached a final state.
  Future<void> clearCompleted() async {
    await _queue.clearCompleted();
    await _reload();
  }

  /// Writes the new order of the queue.
  Future<void> reorder(List<int> orderedIds) async {
    await _queue.reorder(orderedIds);
    await _reload();
  }

  Future<void> _uploadGroup(List<QueueItem> group) async {
    final destination = await _destinationOf(group.first);
    if (destination == null) {
      for (final item in group) {
        await _queue.updateState(
          item.id,
          QueueState.failed,
          errorCode: UploadErrorCode.invalidWebhook.code,
          errorMessage: 'The destination of this file was removed.',
        );
      }
      await _reload();
      return;
    }

    final secret = await _destinations.secretOf(destination);
    if (secret == null || secret.isEmpty) {
      for (final item in group) {
        await _queue.updateState(
          item.id,
          QueueState.failed,
          errorCode: UploadErrorCode.invalidWebhook.code,
          errorMessage: 'The destination has no secret.',
        );
      }
      await _reload();
      return;
    }

    final settings =
        ref.read(settingsControllerProvider).value ?? AppSettings.defaults;
    _cancelToken = CancelToken();

    for (final item in group) {
      await _queue.updateState(item.id, QueueState.uploading);
    }
    await _reload();

    final startedAt = DateTime.now();
    await _startService(group.length);

    final outcome = await _engine.send(
      destination: destination,
      secret: secret,
      items: group,
      sizeLimitBytes: settings.sizeLimitBytes,
      cancelToken: _cancelToken,
      onProgress: (double progress) {
        unawaited(_reportProgress(group, progress));
      },
    );

    final endedAt = DateTime.now();
    for (final item in group) {
      if (outcome.isSuccess) {
        await _queue.updateState(item.id, QueueState.completed);
      } else {
        final failure =
            outcome.failure ?? const UploadFailure(UploadErrorCode.unknown);
        final state = failure.code == UploadErrorCode.cancelled
            ? QueueState.cancelled
            : QueueState.failed;
        await _queue.updateState(
          item.id,
          state,
          errorCode: failure.code.code,
          errorMessage: Redaction.redact(failure.message, <String>[secret]),
        );
      }
      await _history.add(
        HistoryRecord(
          id: 0,
          fileName: item.fileName,
          destinationName: destination.name,
          destinationType: destination.type.code,
          startedAt: startedAt,
          endedAt: endedAt,
          durationMs: endedAt.difference(startedAt).inMilliseconds,
          sizeBytes: item.sizeBytes,
          status: outcome.isSuccess ? 'completed' : 'failed',
          errorText: outcome.failure?.message,
        ),
      );
    }

    _cancelToken = null;
    await _reload();
  }

  List<QueueItem> _groupOf(List<QueueItem> pending) {
    final settings =
        ref.read(settingsControllerProvider).value ?? AppSettings.defaults;
    if (!settings.groupFiles) {
      return <QueueItem>[pending.first];
    }
    final first = pending.first;
    final group = <QueueItem>[];
    for (final item in pending) {
      if (item.destinationId != first.destinationId) {
        break;
      }
      if (group.length >= settings.maxFilesPerMessage) {
        break;
      }
      if (group.length >= UploadEngine.maxFilesPerMessage) {
        break;
      }
      group.add(item);
    }
    return group;
  }

  Future<Destination?> _destinationOf(QueueItem item) async {
    final all = await _destinations.list();
    for (final destination in all) {
      if (destination.id == item.destinationId) {
        return destination;
      }
    }
    return null;
  }

  Future<void> _reportProgress(List<QueueItem> group, double progress) async {
    for (final item in group) {
      await _queue.updateProgress(item.id, progress);
    }
    final service = ref.read(backgroundServiceProvider);
    await service.update(
      title: 'Sending to Discord',
      body: '${group.length} file(s) · ${(progress * 100).round()}%',
      progress: (progress * 100).round(),
    );
  }

  Future<void> _startService(int fileCount) async {
    final service = ref.read(backgroundServiceProvider);
    try {
      await service.start(
        title: 'Sending to Discord',
        body: '$fileCount file(s)',
        indeterminate: true,
      );
    } on Object {
      // The service is not available on every platform, the upload continues
      // in the foreground in that case.
    }
  }

  Future<void> _stopService() async {
    final service = ref.read(backgroundServiceProvider);
    try {
      await service.stop();
    } on Object {
      // Nothing to stop.
    }
  }

  void _listenForServiceEvents() {
    final service = ref.read(backgroundServiceProvider);
    _serviceSubscription = service.events.listen((UploadServiceEvent event) {
      switch (event) {
        case UploadServiceEvent.cancelRequested:
          unawaited(cancelAll());
        case UploadServiceEvent.serviceDestroyed:
          unawaited(_markInterrupted());
      }
    });
  }

  Future<void> _markInterrupted() async {
    final items = await _queue.list();
    for (final item in items) {
      if (item.state == QueueState.uploading) {
        await _queue.updateState(
          item.id,
          QueueState.interrupted,
          errorMessage:
              'The system stopped the upload. The file may still have been '
              'sent, check the channel before you retry it.',
        );
      }
    }
    await _reload();
  }

  /// After a restart an upload that was running becomes interrupted and a
  /// file whose copy is gone becomes source missing.
  Future<void> _restoreAfterRestart() async {
    await _queue.markInterrupted();
    await _queue.markMissingSources((String path) => File(path).existsSync());
    await _reload();
  }

  Future<void> _reload() async {
    state = AsyncValue<List<QueueItem>>.data(await _queue.list());
  }
}

final uploadControllerProvider =
    NotifierProvider<UploadController, AsyncValue<List<QueueItem>>>(
      UploadController.new,
    );
