import 'package:code_builder/code_builder.dart' show Reference;

class GraphqlFile {
  final String fileContents;
  final String fileName;

  List<GraphqlVariable>? _variables;
  String? _gqlString;
  String? _className;

  String? _operationName;

  String get gqlString => _gqlString!;
  String get className => _className!;
  String? get operationName => _operationName;
  List<GraphqlVariable>? get variables => _variables;

  GraphqlFile({
    required this.fileContents,
    required this.fileName,
  });

  void withVariables(List<GraphqlVariable> variables) {
    _variables = variables;
  }

  void withOperationName(String? operationName) {
    _operationName = operationName;
  }

  void withGqlQuery(String query) {
    _gqlString = query;
  }

  void build() {
    final _splitNames = fileName.split('.')[0];
    _className = _splitNames
        .split('_')
        .map((e) => e.replaceFirst(e[0], e[0].toUpperCase()))
        .join();
  }
}

class GraphqlVariable {
  final String name;
  final Reference type;
  final bool nullable;

  const GraphqlVariable(
    this.name,
    this.type, {
    this.nullable = false,
  });
}
