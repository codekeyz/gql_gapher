import 'dart:io';
import 'package:code_builder/code_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gql_codegen/src/graphql_processor.dart';
import 'package:gql_codegen/src/graphql_file.dart';

void main() {
  const RESOURCE_PATH = 'test/graphql';

  Future<String> getFileContent(String filename) async {
    return await File('$RESOURCE_PATH/$filename').readAsString();
  }

  test("basic scalar types -> Int, String, Float, Boolean", () async {
    final fileName = 'authenticate.graphql';
    final fileContent = await getFileContent(fileName);
    final operations = await parseGraphqlFile(fileContent, fileName);

    expect(operations.length, 1);

    final operation = operations[0];
    expect(operation.variables, [
      OperationVariable('token', refer('String'), nullable: false),
      OperationVariable('attempt', refer('int'), nullable: false),
      OperationVariable('persist', refer('bool?'), nullable: true),
      OperationVariable('amount', refer('double?'), nullable: true),
    ]);
  });

  test("list types scalar types -> [Int], [String], etc", () async {
    final fileName = 'filter_products.graphql';
    final fileContent = await getFileContent(fileName);
    final operations = await parseGraphqlFile(fileContent, fileName);

    expect(operations.length, 1);

    final operation = operations[0];
    expect(operation.variables, [
      OperationVariable('filters', refer('List<String>?'), nullable: true),
      OperationVariable('sku', refer('List<int?>'), nullable: false),
      OperationVariable('product', refer('String'), nullable: false),
    ]);
  });

  test("complex types we know nothing about", () async {
    final fileName = 'update_user_data.graphql';
    final fileContent = await getFileContent(fileName);
    final operations = await parseGraphqlFile(fileContent, fileName);

    expect(operations.length, 1);
    final operation = operations[0];

    expect(operation.variables, [
      OperationVariable('profileItems', refer('List<dynamic>'),
          nullable: false),
      OperationVariable('userId', refer('String'), nullable: false),
      OperationVariable('location', refer('dynamic'), nullable: false),
    ]);
  });
}
