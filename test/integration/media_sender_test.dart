import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:discord_server_manager/core/providers.dart';
import 'package:discord_server_manager/core/security/secret_store.dart';
import 'package:discord_server_manager/core/storage/app_database.dart';
import 'package:discord_server_manager/features/media_sender/data/background_service.dart';
import 'package:discord_server_manager/features/media_sender/data/history_repository.dart';
import 'package:discord_server_manager/features/media_sender/data/media_picker.dart';
import 'package:discord_server_manager/features/media_sender/domain/picked_media.dart';
import 'package:discord_server_manager/features/media_sender/domain/queue_item.dart';
import 'package:discord_server_manager/features/media_sender/domain/queue_state.dart';
import 'package:discord_server_manager/features/media_sender/presentation/upload_controller.dart';
import 'package:discord_server_manager/features/settings/domain/app_settings.dart';
import 'package:discord_server_manager/features/settings/presentation/settings_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_adapter.dart';

/// A secret storage that keeps the values in memory.
class FakeSecretStorage implements SecretStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// A picker that always returns the files it was given.
class FakeMediaPicker implements MediaPicker {
  FakeMediaPicker(this.files);

  final List<PickedMedia> files;

  @override
  Future<List<PickedMedia>> pickFiles() async => files;

  @override
  Future<List<PickedMedia>> pickMedia() async => files;
}

/// A background service that only records the calls.
class FakeBackgroundService implements UploadBackgroundService {
  final List<String> calls = <String>[];
  // The controller is closed by the teardown of the test.
  // ignore: close_sinks
  final StreamController<UploadServiceEvent> controller =
      StreamController<UploadServiceEvent>.broadcast();

  @override
  Stream<UploadServiceEvent> get events => controller.stream;

  @override
  Future<void> start({
    required String title,
    required String body,
    int progress = -1,
    bool indeterminate = false,
  }) async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> update({
    required String title,
    required String body,
    int progress = -1,
    bool indeterminate = false,
  }) async => calls.add('update');
}

void main() {
  test('a webhook is added, two files are picked and sent', () async {
    final directory = await Directory.systemTemp.createTemp('dsm-integration');
    final first = File('${directory.path}/first.png');
    final second = File('${directory.path}/second.png');
    await first.writeAsBytes(List<int>.filled(16, 1));
    await second.writeAsBytes(List<int>.filled(16, 2));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final secrets = FakeSecretStorage();
    final requests = <RequestOptions>[];

    final adapter = MockAdapter((RequestOptions options) async {
      requests.add(options);
      return jsonResponse(<Object?, Object?>{
        'id': 'message-${requests.length}',
      });
    });
    final uploadDio = Dio(BaseOptions(baseUrl: 'https://discord.com/api/v10'))
      ..httpClientAdapter = adapter;

    final background = FakeBackgroundService();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretStoreProvider.overrideWithValue(secrets),
        uploadDioProvider.overrideWithValue(uploadDio),
        backgroundServiceProvider.overrideWithValue(background),
        settingsControllerProvider.overrideWith(
          () => _FixedSettingsController(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(background.controller.close);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    // 1. A webhook destination is added.
    final destinationRepository = container.read(destinationRepositoryProvider);
    await destinationRepository.addWebhook(
      id: 'destination-1',
      name: 'Test hook',
      url: 'https://discord.com/api/webhooks/1/token',
    );
    expect(await destinationRepository.list(), hasLength(1));
    expect(
      await destinationRepository.secretOf(
        (await destinationRepository.list()).first,
      ),
      'https://discord.com/api/webhooks/1/token',
    );

    // 2. Two files are picked with the fake picker.
    final picker = FakeMediaPicker(<PickedMedia>[
      PickedMedia(
        path: first.path,
        name: 'first.png',
        sizeBytes: await first.length(),
        kind: MediaKind.image,
        mimeType: 'image/png',
      ),
      PickedMedia(
        path: second.path,
        name: 'second.png',
        sizeBytes: await second.length(),
        kind: MediaKind.image,
        mimeType: 'image/png',
      ),
    ]);
    final picked = await picker.pickMedia();
    expect(picked, hasLength(2));

    // 3. The files are queued and sent.
    final controller = container.read(uploadControllerProvider.notifier);
    final destination = (await destinationRepository.list()).first;
    await controller.enqueue(media: picked, destination: destination);

    var queued = container.read(uploadControllerProvider).value ?? const [];
    expect(queued, hasLength(2));
    expect(
      queued.every((QueueItem item) => item.state == QueueState.pending),
      isTrue,
    );

    await controller.send();

    queued = container.read(uploadControllerProvider).value ?? const [];
    expect(queued, hasLength(2));
    expect(
      queued.every((QueueItem item) => item.state == QueueState.completed),
      isTrue,
    );
    expect(requests, hasLength(2));

    // 4. The history shows the two successes.
    final history = await container.read(historyRepositoryProvider).list();
    expect(history, hasLength(2));
    expect(
      history.every((HistoryRecord record) => record.status == 'completed'),
      isTrue,
    );
    expect(
      history.map((HistoryRecord record) => record.fileName).toSet(),
      <String>{'first.png', 'second.png'},
    );

    // The source files were not touched.
    expect(first.existsSync(), isTrue);
    expect(second.existsSync(), isTrue);
  });
}

/// A settings controller that always answers with the same settings.
class _FixedSettingsController extends SettingsController {
  @override
  Future<AppSettings> build() async => AppSettings.defaults;
}
