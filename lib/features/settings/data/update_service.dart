import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';

/// The latest release of the app on GitHub.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.url,
    required this.name,
  });

  final String version;
  final String url;
  final String name;
}

/// Checks whether a newer release is available.
class UpdateService {
  UpdateService({required this.config, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: <String, String>{
                'Accept': 'application/vnd.github+json',
              },
            ),
          );

  final AppConfig config;
  final Dio _dio;

  /// Reads the latest release from GitHub.
  Future<ReleaseInfo?> latestRelease() async {
    final response = await _dio.get<Object?>(
      '${config.githubApiBase}/releases/latest',
    );
    final data = response.data;
    if (data is! Map) {
      return null;
    }
    final tag = data['tag_name'];
    final url = data['html_url'];
    final name = data['name'];
    if (tag is! String) {
      return null;
    }
    return ReleaseInfo(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      url: url is String ? url : config.githubReleasesPage,
      name: name is String ? name : tag,
    );
  }
}

/// Compares two version strings such as `1.2.3` and `1.10.0`.
///
/// Returns a positive number when [left] is newer, a negative number when
/// [right] is newer and zero when both are the same.
int compareVersions(String left, String right) {
  final leftParts = _parts(left);
  final rightParts = _parts(right);
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var index = 0; index < length; index += 1) {
    final leftPart = index < leftParts.length ? leftParts[index] : 0;
    final rightPart = index < rightParts.length ? rightParts[index] : 0;
    if (leftPart != rightPart) {
      return leftPart - rightPart;
    }
  }
  return 0;
}

List<int> _parts(String version) {
  final cleaned = version.replaceAll(RegExp('[^0-9.]'), '');
  return cleaned
      .split('.')
      .map((String part) => int.tryParse(part) ?? 0)
      .toList(growable: false);
}
