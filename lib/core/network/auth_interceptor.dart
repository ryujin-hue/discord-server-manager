import 'dart:async';

import 'package:dio/dio.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/oauth_token.dart';
import '../errors/app_failure.dart';
import '../security/token_store.dart';

/// Attaches the bearer token to every request, refreshes it exactly once for
/// concurrent requests and retries a request once after a refresh or a rate
/// limit.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenStore,
    required this.authRepository,
    required this.onSignedOut,
    required this.dio,
    this.refreshWindow = const Duration(seconds: 60),
  });

  final TokenStorage tokenStore;
  final TokenRefresher authRepository;
  final void Function() onSignedOut;
  final Dio dio;
  final Duration refreshWindow;

  Future<OAuthToken?>? _refreshInFlight;

  /// The number of refresh calls performed. Exposed for tests.
  int refreshCount = 0;

  static const String _retriedKey = 'dsm_retried_after_refresh';
  static const String _rateRetriedKey = 'dsm_retried_after_rate_limit';
  static const String _usedTokenKey = 'dsm_used_access_token';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStore.read();
    if (token == null) {
      handler.next(options);
      return;
    }

    if (token.isExpiringSoon(window: refreshWindow)) {
      final refreshed = await _refresh(token);
      if (refreshed != null) {
        _attach(options, refreshed.accessToken);
        handler.next(options);
        return;
      }
    }

    _attach(options, token.accessToken);
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;

    if (status == 401 && err.requestOptions.extra[_retriedKey] != true) {
      final refreshed = await _refreshAfterUnauthorized(err.requestOptions);
      if (refreshed != null) {
        final options = err.requestOptions..extra[_retriedKey] = true;
        _attach(options, refreshed.accessToken);
        try {
          handler.resolve(await dio.fetch<Object?>(options));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
        return;
      }
      handler.next(err);
      return;
    }

    if (status == 429 && err.requestOptions.extra[_rateRetriedKey] != true) {
      final wait = _retryAfterSeconds(err);
      if (wait != null) {
        final options = err.requestOptions..extra[_rateRetriedKey] = true;
        await Future<void>.delayed(
          Duration(milliseconds: (wait * 1000).round()),
        );
        try {
          handler.resolve(await dio.fetch<Object?>(options));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
        return;
      }
    }

    handler.next(err);
  }

  void _attach(RequestOptions options, String accessToken) {
    options.headers['Authorization'] = 'Bearer $accessToken';
    options.extra[_usedTokenKey] = accessToken;
  }

  /// Returns the token that may be used to repeat a request that was
  /// answered with 401.
  ///
  /// When the token of the request is not the token that is stored any more,
  /// another request already refreshed the session and the new token is used
  /// without refreshing a second time.
  Future<OAuthToken?> _refreshAfterUnauthorized(RequestOptions options) async {
    final stored = await tokenStore.read();
    if (stored == null) {
      return null;
    }

    final used = options.extra[_usedTokenKey];
    if (used is String && used != stored.accessToken) {
      return stored;
    }

    return _refresh(stored);
  }

  /// Runs at most one refresh at a time and shares its result with every
  /// request that waits for it.
  Future<OAuthToken?> _refresh(OAuthToken token) {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _performRefresh(token);
    _refreshInFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_refreshInFlight, future)) {
          _refreshInFlight = null;
        }
      }),
    );
    return future;
  }

  Future<OAuthToken?> _performRefresh(OAuthToken token) async {
    refreshCount += 1;
    try {
      final refreshed = await authRepository.refresh(token);
      // The store is the single source of truth. Writing the new token here
      // lets a request that failed in parallel use it instead of refreshing a
      // second time.
      await tokenStore.write(refreshed);
      return refreshed;
    } on InvalidGrantFailure {
      await tokenStore.clear();
      onSignedOut();
      return null;
    } on UnauthorizedFailure {
      await tokenStore.clear();
      onSignedOut();
      return null;
    }
  }

  static double? _retryAfterSeconds(DioException err) {
    final header = err.response?.headers.value('retry-after');
    if (header != null) {
      final parsed = double.tryParse(header);
      if (parsed != null) {
        return parsed;
      }
    }
    final body = err.response?.data;
    if (body is Map) {
      final value = body['retry_after'];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}
