import 'dart:async';

import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'parser.dart';

class GraphqlBuilder implements Builder {
  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final resultFile = inputId.changeExtension('.g.dart');
    final fileContent = await buildStep.readAsString(inputId);

    final operations = await parseGqlString(fileContent);
    final classes = await Future.wait(operations.map(getClassDefinition));
    final library = Library((builder) {
      builder.body.addAll([
        Directive.import(
          'package:gql_client/gql_client.dart',
          show: ['GraphqlRequest'],
        ),
        ...classes,
      ]);
    });

    await buildStep.writeAsString(
      resultFile,
      DartFormatter().format('${library.accept(DartEmitter())}'),
    );
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.graphql': ['.g.dart'],
        '.gql': ['.g.dart'],
      };
}
