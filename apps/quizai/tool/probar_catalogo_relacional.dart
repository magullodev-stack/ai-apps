import 'dart:convert';
import 'dart:io';

import 'package:quizai/semantic_catalog/relational_semantic_catalog_generator.dart';

Future<void> main() async {
  stdout.write('Contexto: ');
  final context = stdin.readLineSync(encoding: utf8) ?? '';
  final generator = RelationalSemanticCatalogGenerator();
  final stopwatch = Stopwatch()..start();
  Object? result;
  Object? error;
  try {
    final catalog = await generator.generateCatalog(context);
    result = {
      'context': catalog.context,
      'pivots': [
        for (final p in catalog.pivots)
          {'name': p.name, 'attractors': [for (final a in p.attractors) a.name]},
      ],
    };
  } catch (caught) {
    error = caught;
    exitCode = 1;
  }
  stopwatch.stop();
  final root = File.fromUri(Platform.script).parent.parent.parent.parent;
  final output = File('${root.path}/.ai-apps/catalogo_relacional.json');
  await output.parent.create(recursive: true);
  final envelope = {
    'timeMilliseconds': stopwatch.elapsedMilliseconds,
    'error': error?.toString(),
    'report': generator.report,
  };
  await output.writeAsString('${const JsonEncoder.withIndent('  ').convert(result ?? envelope)}\n');
  stdout.writeln('Tiempo: ${stopwatch.elapsedMilliseconds} ms');
  stdout.writeln('Informe: ${generator.report}');
  stdout.writeln('Resultado: ${output.path}');
  if (error != null) stderr.writeln('ERROR: $error');
}
