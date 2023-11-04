import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:gql/ast.dart';
import 'package:gql/language.dart' as lang;

import 'graphql_file.dart';

Future<GraphqlFile> processGraphqlFile(GraphqlFile file) async {
  final gqlNode = lang.parseString(file.fileContents);

  final _optNode =
      gqlNode.definitions.firstWhere((e) => e is OperationDefinitionNode)
          as OperationDefinitionNode;
  final _variables = _optNode.variableDefinitions
      .map((e) => GraphqlVariable(
            e.variable.name.value,
            extractVariableType(e.type),
            nullable: !e.type.isNonNull,
          ))
      .toList();

  return file
    ..withGqlQuery(lang.printNode(gqlNode))
    ..withVariables(_variables)
    ..withOperationName(_optNode.name?.value)
    ..build();
}

Future<String> getClassDefinition(
  GraphqlFile file, {
  String baseClassName = 'Request',
}) async {
  final _className = '${file.className}$baseClassName';

  final Library library = Library((builder) {
    builder.body.addAll([
      Directive.import(
        'package:gql_client/gql_client.dart',
        show: ['GraphqlRequest'],
      ),
      Class((ClassBuilder builder) {
        builder.name = _className;
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
                    ${file.gqlString}
                    \"\"\"
                  """),
          ),
        );
        builder.constructors.add(Constructor((builder) {
          final _variabls = file.variables;
          Map<String, dynamic> _variablsMap = {};

          if (_variabls != null) {
            for (final variable in _variabls) {
              if (variable.nullable) {
                builder.optionalParameters.add(
                  Parameter((builder) => builder
                    ..name = variable.name
                    ..required = false
                    ..named = true
                    ..type = variable.type),
                );

                _variablsMap[
                        'if (${variable.name} != null) "${variable.name}"'] =
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

            var _code = 'super(_query';

            if (file.operationName != null) {
              _code += ', operationName: "${file.operationName}"';
            }

            if (_variablsMap.isNotEmpty) _code += ', variables: $_variablsMap';

            _code += ',)';

            builder.initializers.add(Code(_code));
          }
        }));
      })
    ]);
  });

  final classDefinition =
      DartFormatter().format('${library.accept(DartEmitter())}');

  return classDefinition;
}

final typeTransformationMap = <String, Type>{
  'String': String,
  'Int': int,
  'Float': double,
  'Boolean': bool,
};

Reference extractVariableType(TypeNode type) {
  if (type is NamedTypeNode) {
    var dartType = typeTransformationMap[type.name.value];
    if (dartType != null) {
      if (!type.isNonNull) return refer('$dartType?');
      return refer('$dartType');
    }
  }
  return refer('dynamic');
}
