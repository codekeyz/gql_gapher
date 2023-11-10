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

    final sources = await Future.wait(getImportLines(fileContent)
        .map((line) => resolvePath(line, inputId.path))
        .map((e) => buildStep.readAsString(AssetId(inputId.package, e!))));

    final operations = await parseGqlString(fileContent, sources: sources);
    if (operations.isEmpty) return;

    final classes = await Future.wait(operations.map(getClassDefinition));
    final library = Library((lib) => lib.body.addAll(classes));

    await buildStep.writeAsString(
      resultFile,
      DartFormatter().format('${library.accept(DartEmitter())}'),
    );
  }

  String? resolvePath(String relativePath, String filePath) {
    final parts = filePath.split('/')..removeLast();
    return chopPath(parts.join('/'), relativePath);
  }

  String? chopPath(String path, String relativePath) {
    final segments = relativePath.split('/');
    final resultingPath = path.split('/');
    while (segments.isNotEmpty) {
      if (resultingPath.isEmpty) return null;
      final seg = segments.removeAt(0);
      if (RegExp(r'^\.\.?').hasMatch(seg)) {
        if (seg.length == 2) resultingPath.removeLast();
        continue;
      }
      resultingPath.add(seg);
    }
    return resultingPath.join('/');
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.graphql': ['.g.dart'],
        '.gql': ['.g.dart'],
      };
}
