/// Helpers that keep secrets out of logs, error messages and the interface.
class Redaction {
  const Redaction._();

  static const String mask = '***';

  /// Replaces every occurrence of the given secrets with a fixed mask.
  static String redact(String text, Iterable<String> secrets) {
    var result = text;
    for (final secret in secrets) {
      if (secret.length < 4) {
        continue;
      }
      result = result.replaceAll(secret, mask);
    }
    return result;
  }

  /// Masks a secret so only a short hint remains, for example `abc***xyz`.
  static String maskSecret(String? secret) {
    if (secret == null || secret.isEmpty) {
      return '';
    }
    if (secret.length <= 8) {
      return mask;
    }
    final head = secret.substring(0, 4);
    final tail = secret.substring(secret.length - 4);
    return '$head$mask$tail';
  }

  /// Masks the identifying part of a webhook URL while keeping the host.
  static String maskWebhookUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return maskSecret(url);
    }
    final segments = uri.pathSegments;
    if (segments.length < 2) {
      return maskSecret(url);
    }
    final id = segments[segments.length - 2];
    final token = segments[segments.length - 1];
    return '${uri.origin}/${segments.first}/${maskSecret(id)}/${maskSecret(token)}';
  }

  /// Masks a bot token, keeping only its shape.
  static String maskBotToken(String? token) {
    if (token == null || token.isEmpty) {
      return '';
    }
    return maskSecret(token);
  }
}
