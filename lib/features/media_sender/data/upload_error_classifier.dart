import '../domain/destination.dart';
import '../domain/upload_failure.dart';

/// The parts of a failed upload that decide how it is reported.
class UploadErrorContext {
  const UploadErrorContext({
    this.statusCode,
    this.body,
    required this.destinationType,
    this.isNetworkError = false,
    this.isTimeout = false,
    this.isCancelled = false,
    this.retryAfter,
    this.fileSizeBytes,
    this.sizeLimitBytes,
  });

  final int? statusCode;

  /// The raw response body, used to read the Discord error message.
  final String? body;
  final DestinationType destinationType;
  final bool isNetworkError;
  final bool isTimeout;
  final bool isCancelled;
  final double? retryAfter;
  final int? fileSizeBytes;
  final int? sizeLimitBytes;
}

/// Turns a failed upload into one of the classified failures.
///
/// The Discord error message is kept as the detail so the interface can show
/// the real reason, for example `50013 Missing Permissions`.
UploadFailure classifyUploadError(UploadErrorContext context) {
  if (context.isCancelled) {
    return const UploadFailure(UploadErrorCode.cancelled);
  }

  if (context.fileSizeBytes != null &&
      context.sizeLimitBytes != null &&
      context.fileSizeBytes! > context.sizeLimitBytes!) {
    return UploadFailure(
      UploadErrorCode.fileTooLarge,
      detail:
          '${context.fileSizeBytes} bytes exceed the limit of '
          '${context.sizeLimitBytes} bytes',
    );
  }

  if (context.isTimeout) {
    return const UploadFailure(UploadErrorCode.timeout);
  }

  if (context.isNetworkError) {
    return const UploadFailure(UploadErrorCode.networkUnavailable);
  }

  final status = context.statusCode;
  if (status == null) {
    return UploadFailure(
      UploadErrorCode.unknown,
      detail: _cleanDetail(context.body),
    );
  }

  switch (status) {
    case 400:
      return UploadFailure(
        UploadErrorCode.unsupportedFile,
        detail: _cleanDetail(context.body),
      );
    case 401:
      return UploadFailure(
        context.destinationType == DestinationType.bot
            ? UploadErrorCode.invalidBotToken
            : UploadErrorCode.invalidWebhook,
        detail: _cleanDetail(context.body),
      );
    case 403:
      return UploadFailure(
        UploadErrorCode.permissionDenied,
        detail: _cleanDetail(context.body),
      );
    case 404:
      return UploadFailure(
        context.destinationType == DestinationType.bot
            ? UploadErrorCode.permissionDenied
            : UploadErrorCode.invalidWebhook,
        detail: _cleanDetail(context.body),
      );
    case 413:
      return UploadFailure(
        UploadErrorCode.fileTooLarge,
        detail: _cleanDetail(context.body),
      );
    case 429:
      return UploadFailure(
        UploadErrorCode.rateLimited,
        detail: _cleanDetail(context.body),
        retryAfter: context.retryAfter,
      );
    default:
      if (status >= 500) {
        return UploadFailure(
          UploadErrorCode.serverError,
          detail: _cleanDetail(context.body),
        );
      }
      return UploadFailure(
        UploadErrorCode.unknown,
        detail: _cleanDetail(context.body),
      );
  }
}

/// Extracts the Discord error message and keeps it free of secrets.
String? _cleanDetail(String? body) {
  if (body == null || body.isEmpty) {
    return null;
  }
  final messageMatch = RegExp('"message"\\s*:\\s*"([^"]*)"').firstMatch(body);
  if (messageMatch != null) {
    return messageMatch.group(1);
  }
  if (body.length <= 120) {
    return body;
  }
  return '${body.substring(0, 120)}…';
}
