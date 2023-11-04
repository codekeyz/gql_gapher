import 'package:dio/dio.dart';

import '../../gql_client.dart';

/// This calls catches all gql related
/// errors and notifies us through the
/// [onGqlError] callback
class GraphqlErrorInterceptor extends InterceptorsWrapper {
  /// constructor
  GraphqlErrorInterceptor(
    this.onGqlError, {
    required Dio retryDio,
  }) : _retryDio = retryDio;

  /// callback for graphql errors
  final Future<bool> Function(List<GraphQLError> gqlErrors) onGqlError;
  final Dio _retryDio;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final result = Map<String, dynamic>.from(response.data);
    final _errorsList = result['errors'];

    if (_errorsList != null) {
      final _errList = (_errorsList as Iterable)
          .map((e) => GraphQLError.fromJson(e))
          .toList();

      final _shouldRetry = await onGqlError(_errList);

      if (_shouldRetry) {
        var options = response.requestOptions;
        try {
          final _result = await _retryDio.fetch(options);
          handler.next(_result);
          return;
        } catch (_) {}
      }
    }

    handler.next(response);
  }
}

/// This listens for general errors in the network
class NetworkErrorInterceptor extends InterceptorsWrapper {
  /// Initialize network listener by passing
  /// a function triggered when an error occurs
  /// during a network request
  NetworkErrorInterceptor(this.onNetworkError);

  final Function(NetworkError error) onNetworkError;

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    final _networkError = NetworkError.fromDio(err);
    onNetworkError(_networkError);
    handler.next(err);
  }
}
