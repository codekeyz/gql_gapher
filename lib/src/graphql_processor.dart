import 'package:code_builder/code_builder.dart';
import 'package:gql/ast.dart';
import 'package:gql/language.dart' as lang;

import 'graphql_file.dart';

Future<List<GraphqlOperation>> parseGraphqlFile(
  String fileContents,
  String fileName,
) async {
  final gqlNode = lang.parseString(fileContents);

  final List<GraphqlOperation> operations = [];

  for (final node in gqlNode.definitions) {
    if (node is OperationDefinitionNode) {
      final variables = node.variableDefinitions
          .map((e) => OperationVariable(
                e.variable.name.value,
                getVariableType(e.type),
                nullable: !e.type.isNonNull,
              ))
          .toList();

      final operation = GraphqlOperation(
        lang.printNode(node),
        name: node.name?.value,
        variables: variables,
      );
      operations.add(operation);
    }
  }

  return operations;
}

Future<Class> getClassDefinition(
  GraphqlOperation operation, {
  String baseClassName = 'Request',
}) async {
  return Class((ClassBuilder builder) {
    final operationName = operation.name;

    builder.name = '$operationName$baseClassName';
    builder.extend = refer('GraphqlRequest');

    builder.fields.add(
      Field(
        (builder) => builder
          ..static = true
          ..name = '_query'
          ..type = refer('String')
          ..modifier = FieldModifier.constant
          ..assignment = Code("""
                    r\"\"\"
                    ${operation.query}
                    \"\"\"
                  """),
      ),
    );
    builder.constructors.add(Constructor((builder) {
      final variables = operation.variables ?? [];
      Map<String, dynamic> _variablsMap = {};

      if (variables.isNotEmpty) {
        for (final variable in variables) {
          if (variable.nullable) {
            builder.optionalParameters.add(
              Parameter((builder) => builder
                ..name = variable.name
                ..required = false
                ..named = true
                ..type = variable.type),
            );

            _variablsMap['if (${variable.name} != null) "${variable.name}"'] =
                "${variable.name}";
          } else {
            builder.requiredParameters.add(
              Parameter((builder) => builder
                ..name = variable.name
                ..type = variable.type),
            );
            _variablsMap['"${variable.name}"'] = "${variable.name}";
          }
        }
      }

      var _code = 'super(_query';

      if (operation.name != null) {
        _code += ', operationName: "$operationName"';
      }

      if (_variablsMap.isNotEmpty) _code += ', variables: $_variablsMap';

      _code += ',)';

      builder.initializers.add(Code(_code));
    }));
  });
}

const scalarTransformMap = <String, Type>{
  'ID': String,
  'String': String,
  'Int': int,
  'Float': double,
  'Boolean': bool,
};

Reference getVariableType(TypeNode type) {
  String typeOrNullable(String type, {bool nonNull = false}) {
    if (type == 'dynamic' || nonNull) return '$type';
    return '$type?';
  }

  Type getDartType(TypeNode node) => node is NamedTypeNode
      ? (scalarTransformMap[node.name.value] ?? dynamic)
      : dynamic;

  String getType(TypeNode node) {
    if (node is NamedTypeNode)
      return typeOrNullable(
        getDartType(node).toString(),
        nonNull: node.isNonNull,
      );
    else if (node is ListTypeNode) {
      final subType = node.type;
      return typeOrNullable(
        'List<${getType(subType)}>',
        nonNull: node.isNonNull,
      );
    } else
      return 'dynamic';
  }

  return refer(getType(type));
}
