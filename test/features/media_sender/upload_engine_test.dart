import 'dart:io';

import 'package:dio/dio.dart';
import 'package:discord_server_manager/features/media_sender/data/upload_engine.dart';
import 'package:discord_server_manager/features/media_sender/data/upload_error_classifier.dart';
import 'package:discord_server_manager/features/media_sender/domain/destination.dart';
import 'package:discord_server_manager/features/media_sender/domain/queue_item.dart';
import 'package:discord_server_manager/features/media_sender/domain/queue_state.dart';
import 'package:discord_server_manager/features/media_sender/domain/upload_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_adapter.dart';

QueueItem buildItem({required String path, int sizeBytes = 10, int id = 1}) {
  return QueueItem(
    id: id,
    destinationId: 'destination-1',
    destinationName: 'Test webhook',
    sourcePath: path,
    fileName: 'file.png',
    sizeBytes: sizeBytes,
    kind: 'image',
    state: QueueState.pending,
    progress: 0,
    createdAt: DateTime.now(),
  );
}

final Destination webhookDestination = Destination(
  id: 'destination-1',
  name: 'Test webhook',
  type: DestinationType.webhook,
  active: true,
  createdAt: DateTime(2026),
);

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dsm-upload-test');
  });

  tearDown(() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  Future<String> writeFile(String name, {int size = 32}) async {
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(List<int>.filled(size, 1));
    return file.path;
  }

  Dio buildDio(MockAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://discord.com/api/v10'))
      ..httpClientAdapter = adapter;
    return dio;
  }

  test('a successful upload needs a message id in the answer', () async {
    final path = await writeFile('ok.png');
    final adapter = MockAdapter((RequestOptions options) async {
      return jsonResponse(<Object?, Object?>{'id': 'message-1'});
    });
    final engine = UploadEngine(dio: buildDio(adapter));

    final outcome = await engine.send(
      destination: webhookDestination,
      secret: 'https://discord.com/api/webhooks/1/token',
      items: <QueueItem>[buildItem(path: path)],
      sizeLimitBytes: 1024 * 1024,
    );

    expect(outcome.isSuccess, isTrue);
    expect(outcome.messageId, 'message-1');
    expect(adapter.requests.single.path, contains('wait=true'));
  });

  test('an answer without a message id is a failure', () async {
    final path = await writeFile('noid.png');
    final adapter = MockAdapter((RequestOptions options) async {
      return jsonResponse(<Object?, Object?>{'ok': true});
    });
    final engine = UploadEngine(dio: buildDio(adapter));

    final outcome = await engine.send(
      destination: webhookDestination,
      secret: 'https://discord.com/api/webhooks/1/token',
      items: <QueueItem>[buildItem(path: path)],
      sizeLimitBytes: 1024 * 1024,
    );

    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure?.code, UploadErrorCode.unknown);
  });

  test(
    'a 429 answer waits for the retry after header and tries again',
    () async {
      final path = await writeFile('limited.png');
      var calls = 0;
      final adapter = MockAdapter((RequestOptions options) async {
        calls += 1;
        if (calls == 1) {
          return jsonResponse(
            <Object?, Object?>{'message': 'You are being rate limited.'},
            statusCode: 429,
            headers: <String, List<String>>{
              'retry-after': <String>['0.05'],
            },
          );
        }
        return jsonResponse(<Object?, Object?>{'id': 'message-2'});
      });
      final engine = UploadEngine(dio: buildDio(adapter));

      final outcome = await engine.send(
        destination: webhookDestination,
        secret: 'https://discord.com/api/webhooks/1/token',
        items: <QueueItem>[buildItem(path: path)],
        sizeLimitBytes: 1024 * 1024,
      );

      expect(outcome.isSuccess, isTrue);
      expect(calls, 2);
    },
  );

  test('a 413 answer is reported as a file that is too large', () async {
    final path = await writeFile('big.png');
    final adapter = MockAdapter((RequestOptions options) async {
      return jsonResponse(<Object?, Object?>{
        'message': 'Request entity too large',
      }, statusCode: 413);
    });
    final engine = UploadEngine(dio: buildDio(adapter));

    final outcome = await engine.send(
      destination: webhookDestination,
      secret: 'https://discord.com/api/webhooks/1/token',
      items: <QueueItem>[buildItem(path: path)],
      sizeLimitBytes: 1024 * 1024,
    );

    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure?.code, UploadErrorCode.fileTooLarge);
  });

  test('a file above the limit is refused before it is sent', () async {
    final path = await writeFile('huge.png', size: 64);
    final adapter = MockAdapter((RequestOptions options) async {
      return jsonResponse(<Object?, Object?>{'id': 'message-3'});
    });
    final engine = UploadEngine(dio: buildDio(adapter));

    final outcome = await engine.send(
      destination: webhookDestination,
      secret: 'https://discord.com/api/webhooks/1/token',
      items: <QueueItem>[buildItem(path: path, sizeBytes: 4096)],
      sizeLimitBytes: 1024,
    );

    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure?.code, UploadErrorCode.fileTooLarge);
    expect(adapter.requests, isEmpty);
  });

  test('a cancelled upload stops and is not retried', () async {
    final path = await writeFile('cancel.png');
    final adapter = MockAdapter((RequestOptions options) async {
      await Future<void>.delayed(const Duration(seconds: 5));
      return jsonResponse(<Object?, Object?>{'id': 'message-4'});
    });
    final engine = UploadEngine(dio: buildDio(adapter));
    final cancelToken = CancelToken();

    final future = engine.send(
      destination: webhookDestination,
      secret: 'https://discord.com/api/webhooks/1/token',
      items: <QueueItem>[buildItem(path: path)],
      sizeLimitBytes: 1024 * 1024,
      cancelToken: cancelToken,
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    cancelToken.cancel('the user cancelled');

    final outcome = await future;
    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure?.code, UploadErrorCode.cancelled);
  });

  test('a lost connection is retried and then reported', () async {
    final path = await writeFile('network.png');
    var calls = 0;
    final adapter = MockAdapter((RequestOptions options) async {
      calls += 1;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: StateError('no route to host'),
      );
    });
    final engine = UploadEngine(
      dio: buildDio(adapter),
      maxAttempts: 3,
      baseBackoff: const Duration(milliseconds: 1),
    );

    final outcome = await engine.send(
      destination: webhookDestination,
      secret: 'https://discord.com/api/webhooks/1/token',
      items: <QueueItem>[buildItem(path: path)],
      sizeLimitBytes: 1024 * 1024,
    );

    expect(outcome.isSuccess, isFalse);
    expect(outcome.failure?.code, UploadErrorCode.networkUnavailable);
    expect(calls, 3);
  });

  test('a webhook that is gone is reported as an invalid webhook', () async {
    final path = await writeFile('gone.png');
    final adapter = MockAdapter((RequestOptions options) async {
      return jsonResponse(<Object?, Object?>{
        'message': 'Unknown Webhook',
      }, statusCode: 404);
    });
    final engine = UploadEngine(dio: buildDio(adapter));

    final outcome = await engine.send(
      destination: webhookDestination,
      secret: 'https://discord.com/api/webhooks/1/token',
      items: <QueueItem>[buildItem(path: path)],
      sizeLimitBytes: 1024 * 1024,
    );

    expect(outcome.failure?.code, UploadErrorCode.invalidWebhook);
  });

  test(
    'a bot token that is rejected is reported as an invalid token',
    () async {
      final path = await writeFile('bot.png');
      final adapter = MockAdapter((RequestOptions options) async {
        return jsonResponse(<Object?, Object?>{
          'message': '401: Unauthorized',
          'code': 0,
        }, statusCode: 401);
      });
      final engine = UploadEngine(dio: buildDio(adapter));

      final outcome = await engine.send(
        destination: Destination(
          id: 'destination-2',
          name: 'Bot',
          type: DestinationType.bot,
          active: true,
          createdAt: DateTime(2026),
          channelId: 'channel-1',
        ),
        secret: 'bot-token',
        items: <QueueItem>[buildItem(path: path)],
        sizeLimitBytes: 1024 * 1024,
      );

      expect(outcome.failure?.code, UploadErrorCode.invalidBotToken);
    },
  );

  test('a missing permission is reported with the Discord message', () async {
    final path = await writeFile('denied.png');
    final adapter = MockAdapter((RequestOptions options) async {
      return jsonResponse(<Object?, Object?>{
        'message': 'Missing Permissions',
        'code': 50013,
      }, statusCode: 403);
    });
    final engine = UploadEngine(dio: buildDio(adapter));

    final outcome = await engine.send(
      destination: webhookDestination,
      secret: 'https://discord.com/api/webhooks/1/token',
      items: <QueueItem>[buildItem(path: path)],
      sizeLimitBytes: 1024 * 1024,
    );

    expect(outcome.failure?.code, UploadErrorCode.permissionDenied);
    expect(outcome.failure?.detail, 'Missing Permissions');
  });

  test('several files are sent as one message', () async {
    final first = await writeFile('one.png');
    final second = await writeFile('two.png');
    final adapter = MockAdapter((RequestOptions options) async {
      return jsonResponse(<Object?, Object?>{'id': 'message-5'});
    });
    final engine = UploadEngine(dio: buildDio(adapter));

    final outcome = await engine.send(
      destination: webhookDestination,
      secret: 'https://discord.com/api/webhooks/1/token',
      items: <QueueItem>[
        buildItem(path: first, id: 1),
        buildItem(path: second, id: 2),
      ],
      sizeLimitBytes: 1024 * 1024,
    );

    expect(outcome.isSuccess, isTrue);
    expect(adapter.requests, hasLength(1));
  });

  test('a webhook is checked without posting a message', () async {
    final adapter = MockAdapter((RequestOptions options) async {
      return jsonResponse(<Object?, Object?>{
        'id': 'webhook-1',
        'name': 'My hook',
        'channel_id': 'channel-1',
      });
    });
    final engine = UploadEngine(dio: buildDio(adapter));

    final info = await engine.testWebhook(
      'https://discord.com/api/webhooks/1/token',
    );

    expect(info.name, 'My hook');
    expect(adapter.requests.single.method, 'GET');
  });

  group('upload error classifier', () {
    test('classifies a missing file', () {
      final failure = classifyUploadError(
        const UploadErrorContext(destinationType: DestinationType.webhook),
      );
      expect(failure.code, UploadErrorCode.unknown);
    });

    test('classifies a cancelled upload', () {
      final failure = classifyUploadError(
        const UploadErrorContext(
          destinationType: DestinationType.webhook,
          isCancelled: true,
        ),
      );
      expect(failure.code, UploadErrorCode.cancelled);
    });

    test('classifies a timeout', () {
      final failure = classifyUploadError(
        const UploadErrorContext(
          destinationType: DestinationType.webhook,
          isTimeout: true,
        ),
      );
      expect(failure.code, UploadErrorCode.timeout);
    });

    test('classifies a server error as retryable', () {
      final failure = classifyUploadError(
        const UploadErrorContext(
          destinationType: DestinationType.webhook,
          statusCode: 503,
        ),
      );
      expect(failure.code, UploadErrorCode.serverError);
      expect(failure.code.isRetryable, isTrue);
    });

    test('a permission error is not retried', () {
      final failure = classifyUploadError(
        const UploadErrorContext(
          destinationType: DestinationType.bot,
          statusCode: 403,
        ),
      );
      expect(failure.code, UploadErrorCode.permissionDenied);
      expect(failure.code.isRetryable, isFalse);
    });
  });
}
