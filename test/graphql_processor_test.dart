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
    final result = await processGraphqlFile(GraphqlFile(
      fileContents: fileContent,
      fileName: fileName,
    ));

    expect(result.className, 'Authenticate');
    expect(result.operationName, 'AuthenticateUser');
    expect(result.variables, [
      GraphqlVariable('token', refer('String'), nullable: false),
      GraphqlVariable('attempt', refer('int'), nullable: false),
      GraphqlVariable('persist', refer('bool?'), nullable: true),
      GraphqlVariable('amount', refer('double?'), nullable: true),
    ]);
  });

  test("list types scalar types -> [Int], [String], etc", () async {
    final fileName = 'filter_products.graphql';
    final fileContent = await getFileContent(fileName);
    final result = await processGraphqlFile(GraphqlFile(
      fileContents: fileContent,
      fileName: fileName,
    ));

    expect(result.className, 'FilterProducts');
    expect(result.operationName, 'FilterProductsTags');
    expect(result.variables, [
      GraphqlVariable('filters', refer('List<String>?'), nullable: true),
      GraphqlVariable('sku', refer('List<int?>'), nullable: false),
      GraphqlVariable('product', refer('String'), nullable: false),
    ]);
  });

  test("complex types we know nothing about", () async {
    final fileName = 'update_user_data.graphql';
    final fileContent = await getFileContent(fileName);
    final result = await processGraphqlFile(GraphqlFile(
      fileContents: fileContent,
      fileName: fileName,
    ));

    expect(result.className, 'UpdateUserData');
    expect(result.operationName, 'UpdateUserData');
    expect(result.variables, [
      GraphqlVariable('profileItems', refer('List<dynamic>'), nullable: false),
      GraphqlVariable('userId', refer('String'), nullable: false),
      GraphqlVariable('location', refer('dynamic'), nullable: false),
    ]);
  });
}
