import 'package:discord_server_manager/core/storage/app_database.dart';
import 'package:discord_server_manager/features/media_sender/data/history_repository.dart';
import 'package:discord_server_manager/features/media_sender/data/queue_repository.dart';
import 'package:discord_server_manager/features/media_sender/domain/picked_media.dart';
import 'package:discord_server_manager/features/media_sender/domain/queue_state.dart';
import 'package:discord_server_manager/features/settings/data/settings_repository.dart';
import 'package:discord_server_manager/features/settings/domain/app_settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('settings persistence', () {
    test('the defaults are returned when nothing was stored', () async {
      final settings = await SettingsRepository(database).load();
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.uploadConcurrency, 1);
      expect(settings.sizeLimitBytes, AppSettings.defaultSizeLimitBytes);
      expect(settings.maxFilesPerMessage, 1);
      expect(settings.groupFiles, isFalse);
      expect(settings.notificationsEnabled, isTrue);
    });

    test('the settings survive a reload', () async {
      final repository = SettingsRepository(database);
      const changed = AppSettings(
        themeMode: AppThemeMode.dark,
        notificationsEnabled: false,
        uploadConcurrency: 3,
        sizeLimitBytes: 25 * 1024 * 1024,
        maxFilesPerMessage: 7,
        groupFiles: true,
      );

      await repository.save(changed);
      final loaded = await repository.load();

      expect(loaded.themeMode, AppThemeMode.dark);
      expect(loaded.notificationsEnabled, isFalse);
      expect(loaded.uploadConcurrency, 3);
      expect(loaded.sizeLimitBytes, 25 * 1024 * 1024);
      expect(loaded.maxFilesPerMessage, 7);
      expect(loaded.groupFiles, isTrue);
    });

    test('the reset brings the defaults back', () async {
      final repository = SettingsRepository(database);
      await repository.save(
        const AppSettings(
          themeMode: AppThemeMode.light,
          notificationsEnabled: false,
          uploadConcurrency: 2,
          sizeLimitBytes: 1024 * 1024,
          maxFilesPerMessage: 4,
          groupFiles: true,
        ),
      );
      await repository.reset();

      final loaded = await repository.load();
      expect(loaded.themeMode, AppThemeMode.system);
      expect(loaded.uploadConcurrency, 1);
    });

    test('the concurrency is limited to the supported range', () {
      final settings = AppSettings.fromStorage(<String, String>{
        'uploadConcurrency': '9',
        'sizeLimitBytes': '1',
        'maxFilesPerMessage': '50',
      });
      expect(settings.uploadConcurrency, 3);
      expect(settings.sizeLimitBytes, 1024 * 1024);
      expect(settings.maxFilesPerMessage, AppSettings.hardMaxFilesPerMessage);
    });
  });

  group('history persistence', () {
    test('an entry is stored and read back', () async {
      final repository = HistoryRepository(database);
      final started = DateTime(2026, 5, 4, 12);

      await repository.add(
        HistoryRecord(
          id: 0,
          fileName: 'holiday.png',
          destinationName: 'Hook',
          destinationType: 'webhook',
          startedAt: started,
          endedAt: started.add(const Duration(seconds: 4)),
          durationMs: 4000,
          sizeBytes: 2048,
          status: 'completed',
        ),
      );

      final entries = await repository.list();
      expect(entries, hasLength(1));
      expect(entries.first.fileName, 'holiday.png');
      expect(entries.first.status, 'completed');
      expect(entries.first.isSuccessful, isTrue);
      expect(entries.first.durationMs, 4000);
    });

    test('the filter picks the right entries', () async {
      final repository = HistoryRepository(database);
      await repository.add(
        HistoryRecord(
          id: 0,
          fileName: 'ok.png',
          destinationName: 'Hook',
          destinationType: 'webhook',
          startedAt: DateTime(2026),
          sizeBytes: 1,
          status: 'completed',
        ),
      );
      await repository.add(
        HistoryRecord(
          id: 0,
          fileName: 'bad.png',
          destinationName: 'Hook',
          destinationType: 'webhook',
          startedAt: DateTime(2026),
          sizeBytes: 1,
          status: 'failed',
        ),
      );
      await repository.add(
        HistoryRecord(
          id: 0,
          fileName: 'stopped.png',
          destinationName: 'Hook',
          destinationType: 'webhook',
          startedAt: DateTime(2026),
          sizeBytes: 1,
          status: 'cancelled',
        ),
      );

      expect(await repository.list(filter: HistoryFilter.all), hasLength(3));
      expect(
        await repository.list(filter: HistoryFilter.successful),
        hasLength(1),
      );
      expect(await repository.list(filter: HistoryFilter.failed), hasLength(1));
      expect(
        await repository.list(filter: HistoryFilter.cancelled),
        hasLength(1),
      );
    });

    test('the search finds a file by name', () async {
      final repository = HistoryRepository(database);
      await repository.add(
        HistoryRecord(
          id: 0,
          fileName: 'holiday.png',
          destinationName: 'Hook',
          destinationType: 'webhook',
          startedAt: DateTime(2026),
          sizeBytes: 1,
          status: 'completed',
        ),
      );
      await repository.add(
        HistoryRecord(
          id: 0,
          fileName: 'invoice.pdf',
          destinationName: 'Hook',
          destinationType: 'webhook',
          startedAt: DateTime(2026),
          sizeBytes: 1,
          status: 'completed',
        ),
      );

      final found = await repository.list(query: 'holi');
      expect(found, hasLength(1));
      expect(found.first.fileName, 'holiday.png');
    });

    test('the history can be cleared', () async {
      final repository = HistoryRepository(database);
      await repository.add(
        HistoryRecord(
          id: 0,
          fileName: 'ok.png',
          destinationName: 'Hook',
          destinationType: 'webhook',
          startedAt: DateTime(2026),
          sizeBytes: 1,
          status: 'completed',
        ),
      );
      await repository.clear();
      expect(await repository.list(), isEmpty);
    });
  });

  group('queue persistence', () {
    test('a queued file keeps its state', () async {
      final repository = QueueRepository(database);
      final item = await repository.add(
        destinationId: 'destination-1',
        destinationName: 'Hook',
        media: const PickedMedia(
          path: '/tmp/one.png',
          name: 'one.png',
          sizeBytes: 128,
          kind: MediaKind.image,
          mimeType: 'image/png',
        ),
      );

      expect(item.state, QueueState.pending);
      expect(item.fileName, 'one.png');
      expect(item.sizeBytes, 128);

      await repository.updateState(item.id, QueueState.uploading);
      await repository.updateProgress(item.id, 0.5);
      final items = await repository.list();
      expect(items.first.state, QueueState.uploading);
      expect(items.first.progress, 0.5);
    });

    test('an upload that was running becomes interrupted', () async {
      final repository = QueueRepository(database);
      final item = await repository.add(
        destinationId: 'destination-1',
        destinationName: 'Hook',
        media: const PickedMedia(
          path: '/tmp/two.png',
          name: 'two.png',
          sizeBytes: 128,
          kind: MediaKind.image,
        ),
      );
      await repository.updateState(item.id, QueueState.uploading);

      await repository.markInterrupted();

      final items = await repository.list();
      expect(items.first.state, QueueState.interrupted);
    });

    test('a file whose copy is gone becomes source missing', () async {
      final repository = QueueRepository(database);
      await repository.add(
        destinationId: 'destination-1',
        destinationName: 'Hook',
        media: const PickedMedia(
          path: '/tmp/three.png',
          name: 'three.png',
          sizeBytes: 128,
          kind: MediaKind.image,
        ),
      );

      await repository.markMissingSources((String path) => false);

      final items = await repository.list();
      expect(items.first.state, QueueState.sourceMissing);
      expect(items.first.errorCode, 'source_missing');
    });

    test('the finished files are removed', () async {
      final repository = QueueRepository(database);
      final completed = await repository.add(
        destinationId: 'destination-1',
        destinationName: 'Hook',
        media: const PickedMedia(
          path: '/tmp/four.png',
          name: 'four.png',
          sizeBytes: 1,
          kind: MediaKind.image,
        ),
      );
      await repository.add(
        destinationId: 'destination-1',
        destinationName: 'Hook',
        media: const PickedMedia(
          path: '/tmp/five.png',
          name: 'five.png',
          sizeBytes: 1,
          kind: MediaKind.image,
        ),
      );
      await repository.updateState(completed.id, QueueState.completed);

      await repository.clearCompleted();

      final items = await repository.list();
      expect(items, hasLength(1));
      expect(items.first.fileName, 'five.png');
    });

    test('the order of the queue can be changed', () async {
      final repository = QueueRepository(database);
      final first = await repository.add(
        destinationId: 'd',
        destinationName: 'Hook',
        media: const PickedMedia(
          path: '/tmp/a.png',
          name: 'a.png',
          sizeBytes: 1,
          kind: MediaKind.image,
        ),
      );
      final second = await repository.add(
        destinationId: 'd',
        destinationName: 'Hook',
        media: const PickedMedia(
          path: '/tmp/b.png',
          name: 'b.png',
          sizeBytes: 1,
          kind: MediaKind.image,
        ),
      );

      await repository.reorder(<int>[second.id, first.id]);

      final items = await repository.list();
      expect(items.first.id, second.id);
      expect(items.last.id, first.id);
    });
  });
}
