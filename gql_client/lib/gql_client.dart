library gql_client;

import 'dart:async';
import 'package:dio/dio.dart' show Dio, DioError, DioErrorType;
import 'src/gql_client_impl.dart';

abstract class GraphQLClient {
  late GraphqlConfig config;

  GraphQLClient(this.config);

  factory GraphQLClient.create(GraphqlConfig config) {
    return GraphQLClientImpl(config);
  }

  void setHeader(Map<String, String> header);

  Future<Map<String, dynamic>?> runMutation(
    GraphqlRequest request, {
    String? resultKey,
  });

  Future<Map<String, dynamic>?> runQuery(
    GraphqlRequest request, {
    String? resultKey,
  });

  /// pause requests
  void pauseRequests();

  /// resume requests
  void resumeRequests();

  /// cancel requests
  void cancelRequests();
}

class NetworkError implements Exception {
  NetworkError(
    this.message, {
    Error? error,
    rawLog,
  }) {
    if (error?.fields != null) {
      fullError = error!.fields!
          .map((e) => '${e.field} ${e.message}')
          .join('\n\n-')
          .trim();
      rawResponse = error.toJson();
    }

    rawResponse = rawLog;
  }

  factory NetworkError.fromDio(DioError dioErr) {
    String? message;
    Error? _errr;

    switch (dioErr.type) {
      case DioErrorType.cancel:
        message = 'Request cancelled';
        break;
      case DioErrorType.sendTimeout:
      case DioErrorType.connectTimeout:
        message = 'Request timed out';
        break;
      case DioErrorType.receiveTimeout:
        message = 'Response timed out';
        break;
      case DioErrorType.response:
        final _statusCode = dioErr.response!.statusCode!;
        if (_statusCode >= 200 && _statusCode < 400) {
          final _response = dioErr.response?.data;
          if (_response != null) _errr = Error.fromJson(_response);
        }
        message = dioErr.message;
        break;
      case DioErrorType.other:
        message = dioErr.message;
        break;
      default:
    }

    message ??= 'An unknown error occurred';

    if (message.contains('SocketException') ||
        message.contains('failed host lookup')) {
      message = 'A network error occurred. Please check your connection.';
    }

    return NetworkError(
      message,
      error: _errr,
      rawLog: dioErr.response?.data,
    );
  }

  /// This holds the reason why the request failed
  /// you can display this to the user
  String message;

  /// This holds the full error, assuming there're
  /// other parts especially `Validation` errors
  String? fullError;

  /// This is the full dump of the error from the server
  /// Useful for logging purposes
  dynamic rawResponse;

  Map<String, dynamic> toJson() => {
        'message': message,
        'fullError': fullError,
        'rawResponse': rawResponse.toString(),
      };
}

class GraphqlConfig {
  final FutureOr<String?> Function()? getToken;
  final Future<bool> Function(List<GraphQLError> errors)? onGraphQLError;
  final Function(NetworkError error)? onNetworkError;
  final String apiEndpoint;
  final bool canLogRequests;
  final Dio? dioInstance;

  const GraphqlConfig({
    this.getToken,
    this.onGraphQLError,
    this.onNetworkError,
    required this.apiEndpoint,
    this.canLogRequests = false,
    this.dioInstance,
  });
}

abstract class GraphqlRequest {
  /// constructor
  const GraphqlRequest(
    this.query, {
    this.variables,
    this.operationName,
  });

  /// the query
  final String query;

  /// the variables
  final Map<String, dynamic>? variables;

  /// the operation name
  final String? operationName;

  @override
  String toString() {
    return '''
    Query:          $query,
    Variables:      $variables,
    OperationName:  $operationName,
    ''';
  }
}

class GraphQLError {
  const GraphQLError(this.extensions, this.message);

  factory GraphQLError.fromJson(Map<String, dynamic> data) {
    return GraphQLError(
      data['extensions'],
      data['message'],
    );
  }

  final String message;
  final Map<String, dynamic>? extensions;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'message': message,
        'extensions': extensions,
      };
}

class Error {
  const Error(
    this.message,
    this.code, {
    this.fields,
  });

  factory Error.fromJson(Map<String, dynamic> datamap) {
    final _fieldsData = datamap['fields'];
    return Error(
      datamap['message'],
      datamap['code'],
      fields: _fieldsData == null
          ? null
          : (_fieldsData as Iterable).map((e) => Field.fromJson(e)).toList(),
    );
  }

  final int? code;
  final String? message;
  final List<Field>? fields;

  String? get displayMessage {
    final fields = this.fields ?? [];
    if (fields.isEmpty) return message;

    var messages = [];
    for (final field in fields) {
      messages.add('${field.field} ${field.message}');
    }

    return messages.join('\n');
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'fields': fields,
      };
}

class Field {
  const Field({this.field, this.message});

  factory Field.fromJson(Map<String, dynamic> datamap) => Field(
        field: datamap['field'],
        message: datamap['message'],
      );

  final String? field;
  final String? message;

  Map<String, dynamic> toJson() => {
        'field': field,
        'message': message,
      };
}
