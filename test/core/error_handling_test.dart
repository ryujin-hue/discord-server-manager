import 'package:dio/dio.dart';
import 'package:discord_server_manager/core/errors/app_failure.dart';
import 'package:discord_server_manager/core/network/failure_mapper.dart';
import 'package:discord_server_manager/core/utils/redaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redaction', () {
    test('removes a secret from a text', () {
      const secret =
          'https://discord.com/api/webhooks/123456789/abcdefghijklmnop';
      final text = 'The request to $secret failed.';
      expect(
        Redaction.redact(text, <String>[secret]),
        'The request to *** failed.',
      );
    });

    test('keeps short values untouched', () {
      expect(
        Redaction.redact('a short value', <String>['ab']),
        'a short value',
      );
    });

    test('masks a webhook url but keeps the host', () {
      final masked = Redaction.maskWebhookUrl(
        'https://discord.com/api/webhooks/123456789/abcdefghijklmnop',
      );
      expect(masked, startsWith('https://discord.com/api/'));
      expect(masked, isNot(contains('abcdefghijklmnop')));
      expect(masked, contains('***'));
    });

    test('masks a bot token', () {
      final masked = Redaction.maskBotToken(
        'MTIzNDU2Nzg5MDEyMzQ1Njc4.GaBcDe.thisIsAToken',
      );
      expect(masked, isNot(contains('thisIsAToken')));
      expect(masked, contains('***'));
    });

    test('returns an empty mask for an empty secret', () {
      expect(Redaction.maskSecret(null), '');
      expect(Redaction.maskSecret(''), '');
      expect(Redaction.maskSecret('1234'), '***');
    });
  });

  group('error classification', () {
    test('maps a connection error to the network failure', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/one'),
          type: DioExceptionType.connectionError,
          error: StateError('no route'),
        ),
      );
      expect(failure, isA<NetworkUnavailableFailure>());
      expect(failure.code, 'network_unavailable');
    });

    test('maps a timeout to the timeout failure', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/one'),
          type: DioExceptionType.sendTimeout,
        ),
      );
      expect(failure, isA<TimeoutFailure>());
    });

    test('maps a cancel to the cancel failure', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/one'),
          type: DioExceptionType.cancel,
        ),
      );
      expect(failure, isA<CancelledFailure>());
    });

    test('keeps the Discord error code and message', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/one'),
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: RequestOptions(path: '/one'),
            statusCode: 403,
            data: <Object?, Object?>{
              'code': 50013,
              'message': 'Missing Permissions',
            },
          ),
        ),
      );
      expect(failure, isA<DiscordApiFailure>());
      expect(failure.message, 'Missing Permissions');
      expect(failure.discordCode, 50013);
    });

    test('reads the error envelope of the backend', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/one'),
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: RequestOptions(path: '/one'),
            statusCode: 429,
            data: <Object?, Object?>{
              'error': <Object?, Object?>{
                'code': 'rate_limited',
                'message': 'Discord is rate limiting this request.',
                'retryAfter': 7,
              },
            },
          ),
        ),
      );
      expect(failure, isA<RateLimitedFailure>());
      expect(failure.retryAfter, 7);
    });

    test('maps a 403 of the backend to the forbidden failure', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/one'),
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: RequestOptions(path: '/one'),
            statusCode: 403,
            data: <Object?, Object?>{
              'error': <Object?, Object?>{
                'code': 'forbidden',
                'message': 'You do not administer this server.',
              },
            },
          ),
        ),
      );
      expect(failure, isA<ForbiddenFailure>());
      expect(failure.message, 'You do not administer this server.');
    });
  });
}
