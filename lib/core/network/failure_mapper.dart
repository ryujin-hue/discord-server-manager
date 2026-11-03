import 'package:dio/dio.dart';

import '../errors/app_failure.dart';

/// Translates transport level exceptions into the typed failures the user
/// interface renders. The backend error envelope and the raw Discord error
/// body are both understood.
AppFailure mapDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkUnavailableFailure();
    case DioExceptionType.cancel:
      return const CancelledFailure();
    case DioExceptionType.badCertificate:
      return const NetworkUnavailableFailure(
        'The server certificate could not be verified.',
      );
    case DioExceptionType.badResponse:
      return _fromResponse(error.response);
    case DioExceptionType.unknown:
      return UnknownFailure(error.message ?? 'Something went wrong.');
  }
}

AppFailure _fromResponse(Response<dynamic>? response) {
  if (response == null) {
    return const UnknownFailure();
  }
  final status = response.statusCode ?? 0;
  final body = response.data;

  final backendError = _readBackendEnvelope(body);
  if (backendError != null) {
    return backendError;
  }

  final discordError = _readDiscordBody(body);
  if (discordError != null) {
    return discordError;
  }

  return switch (status) {
    400 => const ValidationFailure('The request was rejected as invalid.'),
    401 => const UnauthorizedFailure(),
    403 => const ForbiddenFailure(),
    404 => const NotFoundFailure(),
    429 => const RateLimitedFailure(
      'Discord is rate limiting this request. Try again shortly.',
    ),
    _ => UnknownFailure('The server answered with status $status.'),
  };
}

/// The backend answers with `{ "error": { "code": ..., "message": ... } }`.
AppFailure? _readBackendEnvelope(dynamic body) {
  if (body is! Map) {
    return null;
  }
  final envelope = body['error'];
  if (envelope is! Map) {
    return null;
  }
  final code = envelope['code'];
  final message = envelope['message'];
  if (code is! String && message is! String) {
    return null;
  }
  final text = message is String && message.isNotEmpty
      ? message
      : 'The request failed with code ${code ?? 'unknown'}.';
  final discordCode = envelope['discordCode'];
  final retryAfter = envelope['retryAfter'];

  return switch (code) {
    'unauthorized' => UnauthorizedFailure(text),
    'forbidden' => ForbiddenFailure(text),
    'not_found' => NotFoundFailure(text),
    'validation_failed' => ValidationFailure(text),
    'rate_limited' => RateLimitedFailure(
      text,
      seconds: retryAfter is num ? retryAfter.toDouble() : null,
    ),
    _ => DiscordApiFailure(
      detail: text,
      statusCode: 0,
      discordErrorCode: discordCode is int ? discordCode : null,
    ),
  };
}

/// Discord answers with `{ "code": 50013, "message": "Missing Permissions" }`.
AppFailure? _readDiscordBody(dynamic body) {
  if (body is! Map) {
    return null;
  }
  final code = body['code'];
  final message = body['message'];
  if (code is! int && message is! String) {
    return null;
  }
  final text = message is String && message.isNotEmpty
      ? message
      : 'Discord reported error ${code ?? 'unknown'}.';
  return DiscordApiFailure(
    detail: text,
    statusCode: 0,
    discordErrorCode: code is int ? code : null,
  );
}
