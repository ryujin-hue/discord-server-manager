/// The classification of every failure the upload engine can produce.
enum UploadErrorCode {
  networkUnavailable,
  invalidWebhook,
  invalidBotToken,
  permissionDenied,
  unsupportedFile,
  fileTooLarge,
  rateLimited,
  timeout,
  serverError,
  cancelled,
  unknown;

  String get code => switch (this) {
    UploadErrorCode.networkUnavailable => 'network_unavailable',
    UploadErrorCode.invalidWebhook => 'invalid_webhook',
    UploadErrorCode.invalidBotToken => 'invalid_bot_token',
    UploadErrorCode.permissionDenied => 'permission_denied',
    UploadErrorCode.unsupportedFile => 'unsupported_file',
    UploadErrorCode.fileTooLarge => 'file_too_large',
    UploadErrorCode.rateLimited => 'rate_limited',
    UploadErrorCode.timeout => 'timeout',
    UploadErrorCode.serverError => 'server_error',
    UploadErrorCode.cancelled => 'cancelled',
    UploadErrorCode.unknown => 'unknown',
  };

  /// A plain language message that can be shown without any translation.
  String get message => switch (this) {
    UploadErrorCode.networkUnavailable =>
      'No internet connection. The upload was not sent.',
    UploadErrorCode.invalidWebhook =>
      'The webhook URL is not valid anymore. Check the destination.',
    UploadErrorCode.invalidBotToken =>
      'The bot token was rejected by Discord. Check the destination.',
    UploadErrorCode.permissionDenied =>
      'The bot is missing a permission in that channel. It needs View '
          'Channel, Send Messages and Attach Files.',
    UploadErrorCode.unsupportedFile =>
      'Discord does not accept this file format.',
    UploadErrorCode.fileTooLarge =>
      'The file is larger than the configured limit.',
    UploadErrorCode.rateLimited =>
      'Discord is rate limiting this channel. The upload will be retried.',
    UploadErrorCode.timeout => 'The upload timed out before Discord answered.',
    UploadErrorCode.serverError =>
      'Discord reported a server error. The upload will be retried.',
    UploadErrorCode.cancelled => 'The upload was cancelled.',
    UploadErrorCode.unknown => 'The upload failed for an unknown reason.',
  };

  /// True when the upload engine retries this failure on its own.
  bool get isRetryable =>
      this == UploadErrorCode.networkUnavailable ||
      this == UploadErrorCode.timeout ||
      this == UploadErrorCode.serverError ||
      this == UploadErrorCode.rateLimited;
}

/// A failure of the upload engine with the plain language message.
class UploadFailure {
  const UploadFailure(this.code, {this.detail, this.retryAfter});

  final UploadErrorCode code;

  /// The technical detail from Discord, already free of secrets.
  final String? detail;

  /// Seconds to wait before the next attempt.
  final double? retryAfter;

  String get message {
    final extra = detail;
    if (extra == null || extra.isEmpty) {
      return code.message;
    }
    return '${code.message} ($extra)';
  }
}
