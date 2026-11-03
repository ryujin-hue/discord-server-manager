import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/utils/redaction.dart';
import '../domain/destination.dart';
import '../domain/queue_item.dart';
import '../domain/upload_failure.dart';
import 'upload_error_classifier.dart';

/// The result of one upload.
class UploadOutcome {
  const UploadOutcome.success(this.messageId) : failure = null;

  const UploadOutcome.failed(this.failure) : messageId = null;

  final String? messageId;
  final UploadFailure? failure;

  bool get isSuccess => failure == null;
}

/// Sends files to a webhook or to a channel with the user's own bot token.
///
/// Webhooks and bot tokens never reach the backend, the request is made
/// directly from the device.
class UploadEngine {
  UploadEngine({
    required this._dio,
    Random? random,
    this.maxAttempts = 5,
    this.baseBackoff = const Duration(milliseconds: 800),
    this.requestTimeout = const Duration(seconds: 120),
  }) : _random = random ?? Random();

  final Dio _dio;
  final int maxAttempts;
  final Duration baseBackoff;
  final Duration requestTimeout;
  final Random _random;

  static const String discordApiBase = 'https://discord.com/api/v10';

  /// Discord accepts at most ten files in one message.
  static const int maxFilesPerMessage = 10;

  /// Sends one or more files as a single message.
  Future<UploadOutcome> send({
    required Destination destination,
    required String secret,
    required List<QueueItem> items,
    required int sizeLimitBytes,
    CancelToken? cancelToken,
    void Function(double progress)? onProgress,
  }) async {
    if (items.isEmpty) {
      return const UploadOutcome.failed(
        UploadFailure(UploadErrorCode.unknown, detail: 'No file to send.'),
      );
    }

    for (final item in items) {
      if (item.sizeBytes > sizeLimitBytes) {
        return UploadOutcome.failed(
          classifyUploadError(
            UploadErrorContext(
              destinationType: destination.type,
              fileSizeBytes: item.sizeBytes,
              sizeLimitBytes: sizeLimitBytes,
            ),
          ),
        );
      }
    }

    final url = _targetUrl(destination, secret);
    if (url == null) {
      return const UploadOutcome.failed(
        UploadFailure(
          UploadErrorCode.invalidBotToken,
          detail: 'The destination has no channel.',
        ),
      );
    }

    UploadFailure? lastFailure;

    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      if (cancelToken?.isCancelled ?? false) {
        return const UploadOutcome.failed(
          UploadFailure(UploadErrorCode.cancelled),
        );
      }

      try {
        final response = await _dio.post<Object?>(
          url,
          data: await _buildFormData(items),
          cancelToken: cancelToken,
          onSendProgress: (sent, total) {
            if (onProgress != null && total > 0) {
              onProgress(sent / total);
            }
          },
          options: Options(
            sendTimeout: requestTimeout,
            receiveTimeout: requestTimeout,
            responseType: ResponseType.json,
            headers: _headers(destination, secret),
          ),
        );
        final messageId = _messageId(response.data);
        if (messageId != null) {
          onProgress?.call(1);
          return UploadOutcome.success(messageId);
        }
        lastFailure = const UploadFailure(
          UploadErrorCode.unknown,
          detail: 'Discord did not return a message id.',
        );
      } on DioException catch (error) {
        final failure = classifyUploadError(
          UploadErrorContext(
            statusCode: error.response?.statusCode,
            body: _bodyOf(error),
            destinationType: destination.type,
            isNetworkError:
                error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.unknown,
            isTimeout:
                error.type == DioExceptionType.sendTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.connectionTimeout,
            isCancelled: error.type == DioExceptionType.cancel,
            retryAfter: _retryAfter(error),
          ),
        );

        if (failure.code == UploadErrorCode.rateLimited) {
          lastFailure = failure;
          final wait = failure.retryAfter ?? 1;
          await Future<void>.delayed(
            Duration(milliseconds: (wait * 1000).round()),
          );
          continue;
        }

        if (!failure.code.isRetryable || attempt == maxAttempts - 1) {
          return UploadOutcome.failed(failure);
        }
        lastFailure = failure;
      }

      await Future<void>.delayed(_backoffFor(attempt));
    }

    return UploadOutcome.failed(
      lastFailure ??
          const UploadFailure(
            UploadErrorCode.unknown,
            detail: 'The upload did not succeed.',
          ),
    );
  }

  /// Checks a webhook without posting a message.
  Future<WebhookInfo> testWebhook(String url) async {
    try {
      final response = await _dio.get<Object?>(
        url,
        options: Options(
          sendTimeout: requestTimeout,
          receiveTimeout: requestTimeout,
          responseType: ResponseType.json,
        ),
      );
      final data = response.data;
      if (data is Map) {
        final id = data['id'];
        final name = data['name'];
        final channelId = data['channel_id'];
        return WebhookInfo(
          id: id is String ? id : '',
          name: name is String ? name : 'Webhook',
          channelId: channelId is String ? channelId : null,
        );
      }
      throw const UploadFailure(
        UploadErrorCode.invalidWebhook,
        detail: 'The webhook did not answer with a webhook object.',
      );
    } on DioException catch (error) {
      throw classifyUploadError(
        UploadErrorContext(
          statusCode: error.response?.statusCode,
          body: _bodyOf(error),
          destinationType: DestinationType.webhook,
          isNetworkError:
              error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.unknown,
          isTimeout:
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout,
          isCancelled: error.type == DioExceptionType.cancel,
        ),
      );
    }
  }

  /// Validates a bot token by reading the bot account.
  Future<BotIdentity> validateBotToken(String token) async {
    try {
      final response = await _dio.get<Object?>(
        '$discordApiBase/users/@me',
        options: Options(
          headers: <String, String>{'Authorization': 'Bot $token'},
          sendTimeout: requestTimeout,
          receiveTimeout: requestTimeout,
          responseType: ResponseType.json,
        ),
      );
      final data = response.data;
      if (data is Map) {
        final id = data['id'];
        final username = data['username'];
        return BotIdentity(
          id: id is String ? id : '',
          username: username is String ? username : 'Bot',
        );
      }
      throw const UploadFailure(
        UploadErrorCode.invalidBotToken,
        detail: 'Discord did not return a bot account.',
      );
    } on DioException catch (error) {
      throw classifyUploadError(
        UploadErrorContext(
          statusCode: error.response?.statusCode,
          body: _bodyOf(error),
          destinationType: DestinationType.bot,
          isNetworkError:
              error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.unknown,
          isTimeout:
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout,
        ),
      );
    }
  }

  /// The servers the bot is a member of.
  Future<List<BotGuild>> botGuilds(String token) async {
    final response = await _dio.get<Object?>(
      '$discordApiBase/users/@me/guilds',
      options: Options(
        headers: <String, String>{'Authorization': 'Bot $token'},
        responseType: ResponseType.json,
      ),
    );
    final data = response.data;
    if (data is! List) {
      return const <BotGuild>[];
    }
    return data
        .whereType<Map<Object?, Object?>>()
        .map(
          (entry) => BotGuild(
            id: entry['id'] is String ? entry['id']! as String : '',
            name: entry['name'] is String ? entry['name']! as String : 'Server',
          ),
        )
        .toList(growable: false);
  }

  /// The channels of a server the bot can see.
  Future<List<BotChannel>> botChannels(String token, String guildId) async {
    final response = await _dio.get<Object?>(
      '$discordApiBase/guilds/$guildId/channels',
      options: Options(
        headers: <String, String>{'Authorization': 'Bot $token'},
        responseType: ResponseType.json,
      ),
    );
    final data = response.data;
    if (data is! List) {
      return const <BotChannel>[];
    }
    return data
        .whereType<Map<Object?, Object?>>()
        .map(
          (entry) => BotChannel(
            id: entry['id'] is String ? entry['id']! as String : '',
            name: entry['name'] is String
                ? entry['name']! as String
                : 'Channel',
            type: entry['type'] is int ? entry['type']! as int : 0,
          ),
        )
        .toList(growable: false);
  }

  String? _targetUrl(Destination destination, String secret) {
    if (destination.type == DestinationType.webhook) {
      final separator = secret.contains('?') ? '&' : '?';
      return '$secret${separator}wait=true';
    }
    final channelId = destination.channelId;
    if (channelId == null || channelId.isEmpty) {
      return null;
    }
    return '$discordApiBase/channels/$channelId/messages';
  }

  Map<String, String> _headers(Destination destination, String secret) {
    if (destination.type == DestinationType.bot) {
      return <String, String>{'Authorization': 'Bot $secret'};
    }
    return const <String, String>{};
  }

  Future<FormData> _buildFormData(List<QueueItem> items) async {
    final files = <MultipartFile>[];
    for (final item in items) {
      files.add(
        await MultipartFile.fromFile(item.sourcePath, filename: item.fileName),
      );
    }
    return FormData.fromMap(<String, Object?>{
      for (var index = 0; index < files.length; index += 1)
        'files[$index]': files[index],
    });
  }

  static String? _messageId(Object? data) {
    if (data is Map) {
      final id = data['id'];
      if (id is String && id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  static String? _bodyOf(DioException error) {
    final data = error.response?.data;
    if (data == null) {
      return null;
    }
    if (data is String) {
      return data;
    }
    try {
      return jsonEncode(data);
    } on JsonUnsupportedObjectError {
      return null;
    }
  }

  static double? _retryAfter(DioException error) {
    final header = error.response?.headers.value('retry-after');
    if (header != null) {
      final parsed = double.tryParse(header);
      if (parsed != null) {
        return parsed;
      }
    }
    final data = error.response?.data;
    if (data is Map) {
      final value = data['retry_after'];
      if (value is num) {
        return value.toDouble();
      }
    }
    return null;
  }

  Duration _backoffFor(int attempt) {
    final base = baseBackoff.inMilliseconds * (1 << attempt);
    final jitter = _random.nextInt(400);
    return Duration(milliseconds: base + jitter);
  }
}

/// The information a webhook returns when it is queried.
class WebhookInfo {
  const WebhookInfo({required this.id, required this.name, this.channelId});

  final String id;
  final String name;
  final String? channelId;
}

/// The account behind a bot token.
class BotIdentity {
  const BotIdentity({required this.id, required this.username});

  final String id;
  final String username;
}

/// A server the bot is a member of.
class BotGuild {
  const BotGuild({required this.id, required this.name});

  final String id;
  final String name;
}

/// A channel of a server.
class BotChannel {
  const BotChannel({required this.id, required this.name, required this.type});

  final String id;
  final String name;
  final int type;

  bool get isText => type == 0;
}

/// Removes every secret from a text before it is logged.
String redactUploadSecrets(String text, Iterable<String> secrets) =>
    Redaction.redact(text, secrets);
