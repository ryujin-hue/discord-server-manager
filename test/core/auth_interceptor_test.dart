import 'package:dio/dio.dart';
import 'package:discord_server_manager/core/errors/app_failure.dart';
import 'package:discord_server_manager/core/network/auth_interceptor.dart';
import 'package:discord_server_manager/core/security/token_store.dart';
import 'package:discord_server_manager/features/auth/data/auth_repository.dart';
import 'package:discord_server_manager/features/auth/domain/oauth_token.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_adapter.dart';

class FakeTokenStorage implements TokenStorage {
  OAuthToken? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<OAuthToken?> read() async => token;

  @override
  Future<void> write(OAuthToken value) async => token = value;
}

class FakeRefresher implements TokenRefresher {
  FakeRefresher({this.failure});

  AppFailure? failure;
  int calls = 0;

  @override
  Future<OAuthToken> refresh(OAuthToken current) async {
    calls += 1;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return OAuthToken(
      accessToken: 'refreshed-access-token',
      refreshToken: 'refreshed-refresh-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }
}

void main() {
  late FakeTokenStorage storage;
  late FakeRefresher refresher;

  setUp(() {
    storage = FakeTokenStorage();
    refresher = FakeRefresher();
    storage.token = OAuthToken(
      accessToken: 'old-access-token',
      refreshToken: 'old-refresh-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  });

  Dio buildDio(MockAdapter adapter, {required void Function() onSignedOut}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        tokenStore: storage,
        authRepository: refresher,
        dio: dio,
        onSignedOut: onSignedOut,
      ),
    );
    return dio;
  }

  test('two concurrent 401 answers cause exactly one refresh', () async {
    final requests = <String>[];
    final adapter = MockAdapter((RequestOptions options) async {
      final authorization = options.headers['Authorization'];
      requests.add(authorization is String ? authorization : '');
      if (authorization == 'Bearer old-access-token') {
        return jsonResponse(<Object?, Object?>{
          'error': <Object?, Object?>{'code': 'unauthorized'},
        }, statusCode: 401);
      }
      return jsonResponse(<Object?, Object?>{
        'data': <Object?, Object?>{'ok': true},
      });
    });

    var signedOut = false;
    final dio = buildDio(adapter, onSignedOut: () => signedOut = true);

    final results = await Future.wait<Object?>(<Future<Object?>>[
      dio.get<Object?>('/one'),
      dio.get<Object?>('/two'),
    ]);

    expect(refresher.calls, 1);
    expect(signedOut, isFalse);
    expect(results.every((Object? result) => result != null), isTrue);
    expect(
      requests
          .where((String value) => value == 'Bearer refreshed-access-token')
          .length,
      2,
    );
  });

  test('an invalid grant clears the tokens and signs the user out', () async {
    refresher.failure = const InvalidGrantFailure();
    final adapter = MockAdapter((RequestOptions options) async {
      return jsonResponse(<Object?, Object?>{
        'error': <Object?, Object?>{'code': 'unauthorized'},
      }, statusCode: 401);
    });

    var signedOut = false;
    final dio = buildDio(adapter, onSignedOut: () => signedOut = true);

    await expectLater(dio.get<Object?>('/one'), throwsA(isA<DioException>()));

    expect(signedOut, isTrue);
    expect(storage.token, isNull);
  });

  test(
    'a 429 answer waits for the retry after header and retries once',
    () async {
      var calls = 0;
      final adapter = MockAdapter((RequestOptions options) async {
        calls += 1;
        if (calls == 1) {
          return jsonResponse(
            <Object?, Object?>{'message': 'slow down'},
            statusCode: 429,
            headers: <String, List<String>>{
              'retry-after': <String>['0.05'],
            },
          );
        }
        return jsonResponse(<Object?, Object?>{
          'data': <Object?, Object?>{'ok': true},
        });
      });

      final dio = buildDio(adapter, onSignedOut: () {});

      final response = await dio.get<Object?>('/one');

      expect(calls, 2);
      expect(response.statusCode, 200);
    },
  );

  test('the bearer token is attached to every request', () async {
    final adapter = MockAdapter((RequestOptions options) async {
      return jsonResponse(<Object?, Object?>{'data': <Object?, Object?>{}});
    });
    final dio = buildDio(adapter, onSignedOut: () {});

    await dio.get<Object?>('/one');

    expect(
      adapter.requests.first.headers['Authorization'],
      'Bearer old-access-token',
    );
  });

  test(
    'a token that is about to expire is refreshed before the request',
    () async {
      storage.token = OAuthToken(
        accessToken: 'old-access-token',
        refreshToken: 'old-refresh-token',
        expiresAt: DateTime.now().add(const Duration(seconds: 10)),
      );
      final adapter = MockAdapter((RequestOptions options) async {
        return jsonResponse(<Object?, Object?>{'data': <Object?, Object?>{}});
      });
      final dio = buildDio(adapter, onSignedOut: () {});

      await dio.get<Object?>('/one');

      expect(refresher.calls, 1);
      expect(
        adapter.requests.first.headers['Authorization'],
        'Bearer refreshed-access-token',
      );
    },
  );
}
