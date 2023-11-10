import 'dart:io';
import 'package:code_builder/code_builder.dart';
import 'package:test/test.dart';

import 'package:gql_codegen/src/parser.dart';
import 'package:gql_codegen/src/data.dart';

void main() {
  const RESOURCE_PATH = 'test/graphql';

  Future<String> getFileContent(String filepath) async {
    return await File('$RESOURCE_PATH/$filepath').readAsString();
  }

  test("basic scalar types -> Int, String, Float, Boolean", () async {
    final fileContent = await getFileContent('authenticate.graphql');
    final operations = await parseGqlString(fileContent);

    expect(operations.length, 2);

    var operation = operations[0];
    expect(operation.name, 'AuthenticateUser');
    expect(operation.variables, [
      OperationVariable('token', refer('String'), nullable: false),
      OperationVariable('attempt', refer('int'), nullable: false),
      OperationVariable('persist', refer('bool?'), nullable: true),
      OperationVariable('amount', refer('double?'), nullable: true),
    ]);

    operation = operations[1];
    expect(operation.name, 'currentUser');
  });

  test("list types scalar types -> [Int], [String], etc", () async {
    final fileContent = await getFileContent('filter_products.graphql');
    final operations = await parseGqlString(fileContent);

    expect(operations.length, 1);

    final operation = operations[0];
    expect(operation.name, 'FilterProductsTags');
    expect(operation.variables, [
      OperationVariable('filters', refer('List<String>?'), nullable: true),
      OperationVariable('sku', refer('List<int?>'), nullable: false),
      OperationVariable('product', refer('String'), nullable: false),
    ]);
  });

  test("complex types we know nothing about", () async {
    final fileContent = await getFileContent('update_user_data.graphql');
    final operations = await parseGqlString(fileContent);

    expect(operations.length, 1);
    final operation = operations[0];
    expect(operation.name, 'UpdateUserData');
    expect(operation.variables, [
      OperationVariable('profileItems', refer('List<dynamic>'),
          nullable: false),
      OperationVariable('userId', refer('String'), nullable: false),
      OperationVariable('location', refer('dynamic'), nullable: false),
    ]);
  });

  test("fragment imports test", () async {
    var fileContent = await getFileContent('get_current_user.graphql');

    final operations = await parseGqlString(fileContent, sources: [
      await getFileContent('fragments/location.graphql'),
      await getFileContent('fragments/user.graphql')
    ]);

    expect(operations.length, 1);
    expect(operations[0].name, 'currentUser');
    expect(operations[0].variables, []);

    final fragments = operations[0].fragments ?? [];
    expect(fragments.length, 2);
    expect(fragments[0].name.value, 'UserFragment');
    expect(fragments[1].name.value, 'LocationFragment');

    fileContent = await getFileContent('get_house_data.graphql');
    await expectLater(
        parseGqlString(fileContent),
        throwsA(predicate((e) =>
            e is Exception &&
            (e as dynamic).message ==
                'No Type Definition found for Fragment LocationFragment')));

    fileContent = await getFileContent('multiple_definition.graphql');
    await expectLater(
        parseGqlString(fileContent, sources: [
          await getFileContent('fragments/location.graphql'),
        ]),
        throwsA(predicate((e) =>
            e is Exception &&
            (e as dynamic).message ==
                'Fragment: LocationFragment is defined in the query and also imported. Please remove one')));
  });
}
