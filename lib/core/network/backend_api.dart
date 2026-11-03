import 'package:dio/dio.dart';

/// Thin transport wrapper around the backend REST API. Every successful
/// answer is wrapped in `{ "data": ... }`, which is unwrapped here.
class BackendApi {
  BackendApi(this._dio);

  final Dio _dio;

  Future<Map<Object?, Object?>> getMap(
    String path, {
    Map<String, Object?>? query,
  }) async {
    final response = await _dio.get<Object?>(path, queryParameters: query);
    return _asMap(response.data);
  }

  Future<List<Object?>> getList(
    String path, {
    Map<String, Object?>? query,
  }) async {
    final response = await _dio.get<Object?>(path, queryParameters: query);
    final data = response.data;
    return data is List ? data : const <Object?>[];
  }

  Future<Map<Object?, Object?>> postMap(String path, {Object? body}) async {
    final response = await _dio.post<Object?>(path, data: body);
    return _asMap(response.data);
  }

  Future<Map<Object?, Object?>> putMap(String path, {Object? body}) async {
    final response = await _dio.put<Object?>(path, data: body);
    return _asMap(response.data);
  }

  Future<Map<Object?, Object?>> patchMap(String path, {Object? body}) async {
    final response = await _dio.patch<Object?>(path, data: body);
    return _asMap(response.data);
  }

  Future<void> delete(String path) async {
    await _dio.delete<Object?>(path);
  }

  static Map<Object?, Object?> _asMap(Object? data) {
    if (data is Map) {
      final payload = data['data'];
      if (payload is Map) {
        return payload;
      }
      return data;
    }
    return const <Object?, Object?>{};
  }
}
