import 'dart:async';
import 'package:dio/dio.dart';

/// This adds user token to request
class AuthInterceptor extends InterceptorsWrapper {
  /// Initialize this with [getToken]
  AuthInterceptor(this.getToken);

  /// This function is called to retrieved the
  /// auth token to parse in request header
  final FutureOr<String?> Function()? getToken;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final authToken = await getToken?.call();
    if (authToken != null) {
      options.headers.addAll({'Authorization': 'Bearer $authToken'});
    }
    return handler.next(options);
  }
}
