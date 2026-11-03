import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A scripted HTTP adapter. Every request is recorded and answered by the
/// handler the test provides.
class MockAdapter implements HttpClientAdapter {
  MockAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    final completer = Completer<ResponseBody>();
    unawaited(
      handler(options).then(
        (ResponseBody body) {
          if (!completer.isCompleted) {
            completer.complete(body);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      ),
    );
    if (cancelFuture != null) {
      unawaited(
        cancelFuture.then((void _) {
          if (!completer.isCompleted) {
            completer.completeError(
              DioException.requestCancelled(
                requestOptions: options,
                reason: 'the request was cancelled',
              ),
            );
          }
        }),
      );
    }
    return completer.future;
  }

  @override
  void close({bool force = false}) {}
}

/// Builds a JSON response body.
ResponseBody jsonResponse(
  Object? data, {
  int statusCode = 200,
  Map<String, List<String>> headers = const <String, List<String>>{},
}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
      ...headers,
    },
  );
}

/// Builds an empty response body.
ResponseBody emptyResponse({
  int statusCode = 204,
  Map<String, List<String>> headers = const <String, List<String>>{},
}) {
  return ResponseBody.fromString('', statusCode, headers: headers);
}
