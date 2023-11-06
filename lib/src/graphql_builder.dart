import 'dart:async';

import 'package:build/build.dart';
import 'graphql_file.dart';
import 'graphql_processor.dart';

class GraphqlBuilder implements Builder {
  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final resultFile = inputId.changeExtension('.g.dart');

    final gqlFile = GraphqlFile(
      fileContents: await buildStep.readAsString(inputId),
      fileName: inputId.pathSegments.last,
    );

    final resultClass = await getClassDefinition(
      await processGraphqlFile(gqlFile),
    );
    await buildStep.writeAsString(resultFile, resultClass);
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.graphql': ['.g.dart'],
        '.gql': ['.g.dart'],
      };
}
