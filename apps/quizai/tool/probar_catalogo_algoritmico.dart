import 'dart:convert';
import 'dart:io';

import 'package:quizai/semantic_catalog/algorithmic_semantic_catalog_generator.dart';
import 'package:quizai/semantic_catalog/semantic_catalog.dart';

Future<void> main() async {
  stdout.write('Contexto: ');
  final context = stdin.readLineSync(encoding: utf8) ?? '';
  final timer = Stopwatch()..start();
  final generator = AlgorithmicSemanticCatalogGenerator(log: (message) => stderr.writeln('[Wikidata] $message'));
  SemanticCatalog? catalog;
  String? problem;
  try {
    catalog = await generator.generateCatalog(context);
  } catch (error) {
    problem = error.toString();
    exitCode = 1;
  }
  timer.stop();
  final root = File.fromUri(Platform.script).parent.parent.parent.parent;
  final output = File('${root.path}/.ai-apps/catalogo_algoritmico.json');
  await output.parent.create(recursive: true);
  final report = generator.report
    ..['elapsedMilliseconds'] = timer.elapsedMilliseconds
    ..['generatedAt'] = DateTime.now().toUtc().toIso8601String()
    ..['error'] = problem;
  final data = catalog == null
      ? null
      : {
          'context': catalog.context,
          'pivots': [
            for (final p in catalog.pivots)
              {
                'name': p.name,
                'attractors': [for (final a in p.attractors) a.name],
              },
          ],
        };
  // Successful output is directly loadable by SemanticCatalog.fromJson.
  // Failure replaces stale success with an explicitly unsuccessful report.
  const encoder = JsonEncoder.withIndent('  ');
  await output.writeAsString('${encoder.convert(data ?? report)}\n');
  await File('${root.path}/.ai-apps/catalogo_algoritmico.evidencias.json')
      .writeAsString('${encoder.convert(report)}\n');
  final pivots =
      data?['pivots'] as List? ??
      report['partialAxes'] as List? ??
      (report['partialCatalog'] as Map?)?['pivots'] as List? ??
      [];
  final title = catalog == null
      ? 'EJES PARCIALES (CATÁLOGO NO VALIDADO): $context'
      : 'CATÁLOGO: $context';
  final lines = <String>[title, ''];
  for (var i = 0; i < pivots.length; i++) {
    final pivot = pivots[i] as Map;
    final attractors = pivot['attractors'] as List;
    lines.add('P${(i + 1).toString().padLeft(2, '0')} — ${pivot['name']} (${attractors.length} ejes)');
    for (var j = 0; j < attractors.length; j++) {
      lines.add(
        '    A${(j + 1).toString().padLeft(2, '0')} — ${attractors[j]}',
      );
    }
    lines.add('');
  }
  final readable = lines.join('\n');
  stdout.write(readable);
  final readableOutput = File(
    '${root.path}/.ai-apps/catalogo_algoritmico.salida.txt',
  );
  await readableOutput.writeAsString(readable, encoding: utf8);
  stdout.writeln(
    '\nTiempo total de generación: ${(timer.elapsedMilliseconds / 1000).toStringAsFixed(3)} s',
  );
  final observed = pivots.fold<int>(
    0,
    (total, row) => total + ((row as Map)['attractors'] as List).length,
  );
  stdout.writeln('Pivotes mostrados: ${pivots.length}/10');
  stdout.writeln('Ejes documentados: $observed');
  stdout.writeln('Pivotes con 20 ejes: ${report['validPivots'] ?? 0}/10');
  stdout.writeln(
    problem == null
        ? 'Catálogo validado con SemanticCatalog.'
        : 'ERROR: $problem',
  );
  stdout.writeln('Resultado JSON: ${output.path}');
  stdout.writeln('Lista ordenada: ${readableOutput.path}');
}
