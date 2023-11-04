import 'package:dio/dio.dart';

import '../gql_client.dart';
import 'interceptors/auth.dart';
import 'interceptors/error.dart';

class GraphQLClientImpl extends GraphQLClient {
  /// constructor
  GraphQLClientImpl(GraphqlConfig config) : super(config) {
    final _dioOptions = BaseOptions(
      connectTimeout: _dioInstance.options.connectTimeout,
      receiveTimeout: _dioInstance.options.receiveTimeout,
      baseUrl: config.apiEndpoint,
    );

    _dioInstance = config.dioInstance ?? Dio(_dioOptions);

    _refreshDioInstance = Dio(_dioOptions);
    _dioInstance.interceptors.add(AuthInterceptor(config.getToken));

    if (config.onGraphQLError != null) {
      attachErrorInterceptor(
        config.onGraphQLError!,
        onNetworkError: config.onNetworkError,
      );
    }
  }

  final Map<String, String> customHeaders = {};

  void attachErrorInterceptor(
    Future<bool> Function(List<GraphQLError> errors) onGraphqlError, {
    Function(NetworkError error)? onNetworkError,
  }) {
    _dioInstance.interceptors.add(GraphqlErrorInterceptor(
      onGraphqlError,
      retryDio: _dioInstance,
    ));
  }

  /// Requests will timeout in [30] seconds when
  /// trying to reach the server
  static const int CONNECT_TIME_OUT = 30000;

  /// Requests will timeout in [30] seconds when
  /// waiting on server for response
  static const int RECEIVE_TIME_OUT = 30000;

  late Dio _refreshDioInstance, _dioInstance;

  Future<T?> _post<T>(Map<String, dynamic> body, {Dio? dio}) async {
    dio ??= _dioInstance;

    try {
      final _result = await dio.post('', data: body);
      return _result.data;
    } on DioError catch (e) {
      throw NetworkError.fromDio(e);
    }
  }

  @override
  Future<Map<String, dynamic>?> runMutation(
    GraphqlRequest request, {
    String? resultKey,
  }) async {
    _logRequest(request, resultKey: resultKey);

    final _response = await _post({
      'query': request.query,
      'variables': request.variables,
      if (request.variables != null) 'operationName': request.operationName,
    });

    return _handleResponse(_response, resultKey: resultKey);
  }

  @override
  Future<Map<String, dynamic>?> runQuery(GraphqlRequest request,
      {String? resultKey}) async {
    _logRequest(request, resultKey: resultKey);

    var _response = await _post({
      'query': request.query,
      'variables': request.variables,
      if (request.operationName != null) 'operationName': request.operationName,
    });

    return _handleResponse(_response, resultKey: resultKey);
  }

  Map<String, dynamic>? _handleResponse(Map<String, dynamic>? response,
      {String? resultKey}) {
    if (response == null) return null;

    _logResponse(response, resultKey: resultKey);

    final _errorsList = response['errors'];
    if (_errorsList != null) {
      final _errList = (_errorsList as Iterable)
          .map((e) => GraphQLError.fromJson(e))
          .toList();

      throw NetworkError(_errList.first.message, rawLog: _errorsList);
    }

    response = Map<String, dynamic>.from(response['data']);
    final _resultMap = (resultKey == null ? response : response[resultKey]);
    final _errorMap = Map<String, dynamic>.from(_resultMap)['error'];
    if (_errorMap != null) {
      final error = Error.fromJson(_errorMap);

      throw NetworkError(error.displayMessage ?? 'Unknown GraphQL Error',
          error: error);
    }

    if (_resultMap == null) return null;
    return _resultMap;
  }

  void _logRequest(
    GraphqlRequest request, {
    int maxQueryLines = 4,
    String? resultKey,
  }) {
    if (!config.canLogRequests) return;

    final _queryLines = request.query.split('\n');
    final _hasMoreLines = _queryLines.length > maxQueryLines;
    // _logger.debug({
    //   'query': [
    //     ..._queryLines.sublist(
    //         0, _hasMoreLines ? maxQueryLines : _queryLines.length),
    //     if (_hasMoreLines) '...and more...',
    //   ],
    //   'variables': request.variables,
    //   'operationName': request.operationName,
    //   'resultKey': resultKey,
    // });
  }

  void _logResponse(Map<String, dynamic> response, {String? resultKey}) {
    if (!config.canLogRequests) return;

    // _logger.debug({
    //   'response': response,
    //   'resultKey': resultKey,
    // });
  }

  @override
  void pauseRequests() {
    _dioInstance.interceptors.requestLock.lock();
    _dioInstance.interceptors.responseLock.lock();
  }

  @override
  void resumeRequests() {
    _dioInstance.interceptors.requestLock.unlock();
    _dioInstance.interceptors.responseLock.unlock();
  }

  @override
  Future<Map<String, dynamic>?> refreshToken(
    GraphqlRequest request, {
    String? resultKey,
  }) async {
    _logRequest(request, resultKey: resultKey);

    var _response = await _post({
      'query': request.query,
      'variables': request.variables,
      if (request.operationName != null) 'operationName': request.operationName,
    }, dio: _refreshDioInstance);

    return _handleResponse(_response, resultKey: resultKey);
  }

  @override
  void setHeader(Map<String, String> headers) {
    customHeaders.addAll(headers);

    setHeaders(_dioInstance, customHeaders);
    setHeaders(_refreshDioInstance, customHeaders);
  }

  /// set new headers
  void setHeaders(Dio instance, Map<String, dynamic> headers) {
    final options = instance.options.copyWith(headers: headers);
    instance.options = options;
  }

  @override
  void cancelRequests() {
    _dioInstance.clear();
    _refreshDioInstance.clear();
  }
}
