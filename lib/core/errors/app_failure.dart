/// Typed failures. Repositories translate transport level exceptions into one
/// of these, so the user interface never renders a raw exception string.
sealed class AppFailure implements Exception {
  const AppFailure();

  /// Stable machine readable code, also used for analytics and tests.
  String get code;

  /// Plain language text that is safe to show to the user.
  String get message;

  /// Discord error code when the failure originates from Discord.
  int? get discordCode => null;

  /// Seconds to wait before retrying, when the failure is rate limiting.
  double? get retryAfter => null;

  @override
  String toString() => 'AppFailure($code): $message';
}

final class NetworkUnavailableFailure extends AppFailure {
  const NetworkUnavailableFailure([
    this.detail = 'The device could not reach the server.',
  ]);

  final String detail;

  @override
  String get code => 'network_unavailable';

  @override
  String get message => detail;
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure([this.detail = 'The request took too long.']);

  final String detail;

  @override
  String get code => 'timeout';

  @override
  String get message => detail;
}

final class CancelledFailure extends AppFailure {
  const CancelledFailure([this.detail = 'The request was cancelled.']);

  final String detail;

  @override
  String get code => 'cancelled';

  @override
  String get message => detail;
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([
    this.detail = 'The access token was rejected. Please sign in again.',
  ]);

  final String detail;

  @override
  String get code => 'unauthorized';

  @override
  String get message => detail;
}

/// The refresh token is no longer valid, the user has to sign in again.
final class InvalidGrantFailure extends AppFailure {
  const InvalidGrantFailure([
    this.detail = 'The session expired. Please sign in again.',
  ]);

  final String detail;

  @override
  String get code => 'invalid_grant';

  @override
  String get message => detail;
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([
    this.detail = 'You do not have permission to perform this action.',
  ]);

  final String detail;

  @override
  String get code => 'forbidden';

  @override
  String get message => detail;
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([
    this.detail = 'The requested resource was not found.',
  ]);

  final String detail;

  @override
  String get code => 'not_found';

  @override
  String get message => detail;
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(this.detail);

  final String detail;

  @override
  String get code => 'validation_failed';

  @override
  String get message => detail;
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure(this.detail, {this.seconds});

  final String detail;

  /// Seconds to wait before the request may be repeated.
  final double? seconds;

  @override
  String get code => 'rate_limited';

  @override
  String get message => detail;

  @override
  double? get retryAfter => seconds;
}

/// A failure reported by Discord itself. The original Discord error code and
/// message are preserved so the interface can show them verbatim.
final class DiscordApiFailure extends AppFailure {
  const DiscordApiFailure({
    required this.detail,
    required this.statusCode,
    this.discordErrorCode,
  });

  final String detail;
  final int statusCode;

  /// The numeric error code Discord reported.
  final int? discordErrorCode;

  @override
  int? get discordCode => discordErrorCode;

  @override
  String get code => 'discord_error';

  @override
  String get message => detail;
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure([this.detail = 'Something went wrong.']);

  final String detail;

  @override
  String get code => 'unknown';

  @override
  String get message => detail;
}
