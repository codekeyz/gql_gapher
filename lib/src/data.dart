import 'package:code_builder/code_builder.dart' show Reference;
import 'package:gql/ast.dart';

class OperationVariable {
  final String name;
  final Reference type;
  final bool nullable;

  const OperationVariable(
    this.name,
    this.type, {
    this.nullable = false,
  });

  @override
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OperationVariable &&
        other.name == name &&
        other.type.symbol == type.symbol &&
        other.nullable == nullable;
  }

  @override
  int get hashCode {
    return name.hashCode ^ type.hashCode ^ nullable.hashCode;
  }

  @override
  String toString() => """ 
  name:       $name
  type:       ${type.symbol}
  nullable:   $nullable""";
}

class GraphqlOperation {
  final String query;
  final String name;
  final List<OperationVariable>? variables;
  final List<FragmentDefinitionNode>? fragments;

  const GraphqlOperation(
    this.name,
    this.query, {
    this.variables,
    this.fragments,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GraphqlOperation &&
        other.query == query &&
        other.name == name &&
        other.variables == variables &&
        other.fragments == fragments;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        query.hashCode ^
        variables.hashCode ^
        fragments.hashCode;
  }
}
