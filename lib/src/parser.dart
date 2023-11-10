import 'package:code_builder/code_builder.dart';
import 'package:gql/ast.dart';
import 'package:gql/language.dart' as lang;

import 'data.dart';

Future<List<GraphqlOperation>> parseGqlString(
  String gqlString, {
  List<String> sources = const [],
}) async {
  final gqlNode = lang.parseString(gqlString);
  final imports = await resolveImports(sources);

  final List<GraphqlOperation> operations = [];
  final Map<String, FragmentDefinitionNode> fragmentsMap = {};
  if (imports.isNotEmpty) {
    fragmentsMap.addEntries(imports.map((e) => MapEntry(e.name.value, e)));
  }

  final internalFragmentDefinitions = gqlNode.definitions
      .where((e) => e is FragmentDefinitionNode)
      .map((e) => e as FragmentDefinitionNode)
      .toList();
  for (final frag in internalFragmentDefinitions) {
    final key = frag.name.value;
    if (fragmentsMap.containsKey(key)) {
      throw Exception(
          'Fragment: $key is defined in the query and also imported. Please remove one');
    }
    fragmentsMap[key] = frag;
  }

  for (final node in gqlNode.definitions) {
    if (node is OperationDefinitionNode) {
      final variables = node.variableDefinitions
          .map((e) => OperationVariable(
                e.variable.name.value,
                getVariableType(e.type),
                nullable: !e.type.isNonNull,
              ))
          .toList();

      var name = node.name?.value;
      name ??= (node.selectionSet.selections[0] as FieldNode).name.value;

      final query = lang.printNode(node);
      final fragments = <FragmentDefinitionNode>[];
      final dependents = getFragmentDeps(query);
      for (final dep in dependents) {
        final frag = fragmentsMap[dep];
        if (frag == null)
          throw Exception('No Type Definition found for Fragment $dep');
        fragments.add(frag);
      }

      operations.add(GraphqlOperation(
        name,
        query,
        variables: variables,
        fragments: fragments,
      ));
    }
  }

  return operations;
}

Future<Class> getClassDefinition(
  GraphqlOperation operation, {
  String baseClassName = 'Request',
}) async {
  String capitalizeFirst(String word) =>
      word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

  return Class((ClassBuilder builder) {
    final operationName = operation.name;
    String query = operation.query;

    final fragments = operation.fragments ?? [];
    if (fragments.length > 0) {
      query += fragments.fold<String>(
        '',
        (previousValue, e) => previousValue + "\n\n${lang.printNode(e)}",
      );
    }

    builder.name = '${capitalizeFirst(operationName)}$baseClassName';
    builder.fields.addAll(
      [
        Field((field) => field
          ..name = 'query'
          ..type = refer('String')
          ..modifier = FieldModifier.final$),
        Field((field) => field
          ..name = 'operation'
          ..type = refer('String')
          ..modifier = FieldModifier.final$),
        Field((field) => field
          ..modifier = FieldModifier.final$
          ..name = 'variables'
          ..type = refer('Map<String, dynamic>')),
        Field((field) => field
          ..static = true
          ..modifier = FieldModifier.constant
          ..type = refer('String')
          ..name = '_query'
          ..assignment = Code("r\"\"\"$query\"\"\"")),
      ],
    );

    builder.constructors.add(Constructor((struct) {
      final variables = operation.variables ?? [];
      Map<String, dynamic> _variablsMap = {};

      if (variables.isNotEmpty) {
        for (final variable in variables) {
          if (variable.nullable) {
            struct.optionalParameters.add(
              Parameter((builder) => builder
                ..name = variable.name
                ..required = false
                ..named = true
                ..type = variable.type),
            );

            _variablsMap['if (${variable.name} != null) "${variable.name}"'] =
                "${variable.name}";
          } else {
            struct.requiredParameters.add(
              Parameter((builder) => builder
                ..name = variable.name
                ..type = variable.type),
            );
            _variablsMap['"${variable.name}"'] = "${variable.name}";
          }
        }
      }

      struct
        ..lambda = true
        ..initializers.addAll([
          Code('query = _query'),
          Code('operation = "$operationName"'),
          Code('variables = $_variablsMap')
        ]);
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

final splitLines = RegExp(r'(\r\n|\r|\n)');

Set<String> getFragmentDeps(String query) {
  final lines = query.split(splitLines);
  final fragRegx = RegExp(r'^[^#]*\.\.\.(\w+)');
  final fragSpreads = lines.where((e) => fragRegx.hasMatch(e)).toList();
  return fragSpreads
      .map((e) => fragRegx.allMatches(e).map((e) => e.group(1)).first!)
      .toSet();
}

List<String> getImportLines(String source) => source
        .split(splitLines)
        .where((e) => e.startsWith('#import '))
        .toList()
        .map((e) {
      final match =
          RegExp("^['\"](.+)['\"]").firstMatch(e.split(" ")[1])?.group(1);
      if (match == null) throw Exception('Import path is not valid $e');
      return match;
    }).toList();

Future<List<FragmentDefinitionNode>> resolveImports(
  List<String> sources,
) async {
  if (sources.isEmpty) return [];

  final Map<String, FragmentDefinitionNode> importsMap = {};
  for (final source in sources) {
    final node = lang.parseString(source);
    for (final node in node.definitions) {
      if (node is! FragmentDefinitionNode) {
        throw Exception('Only Fragments are supported in imports');
      }
      final key = node.name.value;
      if (!importsMap.containsKey(key))
        importsMap[key] = node;
      else
        throw Exception('Many Fragments with the same name imported: $key');
    }
  }
  return importsMap.values.toList();
}
