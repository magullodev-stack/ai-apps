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
  final method = generator.report['method'] ?? 'sin resultado';
  stdout.writeln('Método: $method');
  if (result != null) {
    final pivots = (result as Map<String, Object?>)['pivots'] as List;
    stdout.writeln('Pivotes: ${pivots.length}/10; atractores: '
        '${pivots.fold<int>(0, (n, p) => n + ((p as Map)['attractors'] as List).length)}/200');
    for (var i = 0; i < pivots.length; i++) {
      final p = pivots[i] as Map;
      stdout.writeln('P${(i + 1).toString().padLeft(2, '0')} ${p['name']}');
      final attractors = p['attractors'] as List;
      for (var j = 0; j < attractors.length; j++) {
        stdout.writeln('  A${(j + 1).toString().padLeft(2, '0')} ${attractors[j]}');
      }
    }
  } else {
    stdout.writeln('Informe: ${generator.report}');
  }
  stdout.writeln('Resultado: ${output.path}');
  if (error != null) stderr.writeln('ERROR: $error');
}
