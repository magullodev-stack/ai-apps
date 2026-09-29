import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';

/// Auditoría experimental aislada: no modifica Quiz10 ni sus catálogos.
Future<void> main(List<String> args) async {
  final model = args.isNotEmpty ? args.first.trim() : '';
  final option = args.indexOf('--muestras');
  final samples = option < 0
      ? 30
      : option + 1 < args.length ? int.tryParse(args[option + 1]) : null;
  if (model.isEmpty || samples == null || samples < 1 || samples > 30) {
    stderr.writeln('Uso: <modelo> [--muestras 1-30]');
    exitCode = 1;
    return;
  }

  final dimensionsFile = File('tool/dimensiones_factuales_86.md');
  final dimensions = parseDimensions(await dimensionsFile.readAsString());
  final sessionFile = File('../../.ai-apps/dart-service.json');
  if (!await sessionFile.exists()) {
    stderr.writeln('El servicio de IA no está iniciado. Arráncalo con run.ps1.');
    exitCode = 1;
    return;
  }
  final session = jsonDecode(await sessionFile.readAsString());
  if (session is! Map || session['endpoint'] is! String ||
      session['token'] is! String) {
    throw const FormatException('Sesión del servicio de IA inválida.');
  }
  final endpoint = Uri.tryParse(session['endpoint'] as String);
  if (endpoint == null || endpoint.scheme != 'http' ||
      endpoint.host != '127.0.0.1') {
    throw const FormatException('Endpoint local del servicio de IA inválido.');
  }

  final client = AiAppsClient(
    endpoint: endpoint,
    authorization: session['token'] as String,
  );
  final outputDir = Directory('../../.ai-apps/experimentos-dimensiones');
  await outputDir.create(recursive: true);
  final runId = DateTime.now().toUtc().toIso8601String()
      .replaceAll(':', '-').replaceAll('.', '-');
  final raw = File('${outputDir.path}/revision-d-$runId.jsonl');
  final report = File('${outputDir.path}/revision-d-$runId-resumen.md');
  final evaluations = <DimensionEvaluation>[];
  var inputTokens = 0;
  var outputTokens = 0;
  var completeUsage = true;

  stdout.writeln('Modelo: $model');
  stdout.writeln('Dimensiones: ${dimensions.length}; evaluaciones: $samples');
  stdout.writeln('Las llamadas son independientes: sin U ni resultados previos.');
  try {
    for (var i = 0; i < samples; i++) {
      // Cambiar la posición de las D permite observar sesgos de orden.
      // La semilla facilita reproducir exactamente el orden utilizado.
      final ordered = dimensions.entries.toList()
        ..shuffle(Random(20260929 + i));
      final start = Stopwatch()..start();
      final response = await client.generate(
        application: 'quizai',
        model: model,
        input: dimensionAuditPrompt(ordered),
        schemaName: 'quizai_dimension_audit',
        schema: dimensionAuditSchema(dimensions.keys.toList()),
      ).timeout(const Duration(seconds: 120));
      final evaluation = parseDimensionEvaluation(
        response.text,
        dimensions.keys.toSet(),
      );
      evaluations.add(evaluation);
      final usage = response.usage;
      final usedInput = usage?['inputTokens'];
      final usedOutput = usage?['outputTokens'];
      if (usedInput is int && usedOutput is int) {
        inputTokens += usedInput;
        outputTokens += usedOutput;
      } else {
        completeUsage = false;
      }
      final risks = evaluation.status.values
          .where((value) => value == 'riesgo').length;
      final problems = evaluation.status.values
          .where((value) => value == 'problematica').length;
      stdout.writeln('Evaluación ${i + 1}/$samples: '
          '$risks riesgos; $problems problemáticas; '
          '${start.elapsedMilliseconds} ms');
      await raw.writeAsString(
        '${jsonEncode({
          'evaluacion': i + 1,
          'modelo': model,
          'orden': ordered.map((entry) => entry.key).toList(),
          'estados': evaluation.status,
          'alertas': [
            for (final entry in evaluation.alerts.entries)
              {
                'codigo': entry.key,
                'motivo': entry.value.reason,
                'ejemplo_fallido': entry.value.badExample,
              },
          ],
          'inputTokens': usedInput,
          'outputTokens': usedOutput,
        })}\n',
        mode: FileMode.append,
        flush: true,
      );
    }
    final summary = formatDimensionAuditReport(evaluations);
    await report.writeAsString(summary, flush: true);
    stdout.writeln('\n$summary');
    stdout.writeln('Uso: ${completeUsage ? inputTokens : 'incompleto'} '
        'tokens de entrada; '
        '${completeUsage ? outputTokens : 'incompleto'} tokens de salida.');
    stdout.writeln('Datos: ${raw.path}');
    stdout.writeln('Informe: ${report.path}');
  } catch (error) {
    stderr.writeln('ERROR: $error');
    stderr.writeln('Datos de las evaluaciones completadas: ${raw.path}');
    exitCode = 1;
  } finally {
    client.close();
  }
}

/// Lee exclusivamente las 86 definiciones literales, sin interpretarlas.
Map<String, String> parseDimensions(String content) {
  final regex = RegExp(
    r'^-\s+\*\*(D\d{2})\*\*:\s*(.+)$',
    multiLine: true,
  );
  final result = <String, String>{};
  for (final match in regex.allMatches(content)) {
    final code = match.group(1)!;
    if (result.containsKey(code)) {
      throw FormatException('Dimensión duplicada: $code');
    }
    result[code] = match.group(2)!.trim();
  }
  final expected = [
    for (var i = 1; i <= 86; i++)
      'D${i.toString().padLeft(2, '0')}',
  ];
  if (result.length != 86 ||
      !expected.every(result.containsKey)) {
    throw const FormatException('Faltan dimensiones D01-D86.');
  }
  return Map.unmodifiable(result);
}

String dimensionAuditPrompt(List<MapEntry<String, String>> dimensions) =>
    '''# Auditoría independiente de dimensiones factuales de Quiz10

Analiza LAS 86 definiciones que aparecen al final de este mensaje.

Objetivo: detectar qué definiciones, por su formulación, presentan un
RIESGO RELEVANTE de inducir preguntas artificiosas, ambiguas o ajenas
al formato de un concurso de cultura general tipo "¿Quién quiere ser
millonario?", incluso cuando se seleccionan campos y referentes adecuados.

Criterios:
1. La pregunta debe interrogar un hecho verdadero, concreto y comprobable;
   no debe inventar premisas para simular una deducción.
2. Debe tener una respuesta identificable e inequívoca y permitir tres
   distractores plausibles pero falsos.
3. Debe sonar como una pregunta natural de cultura general, sin copiar
   el vocabulario formal de la propia dimensión.
4. Debe interrogar fielmente la relación que define el código D,
   sin cambiarla por otra para construir la pregunta.

IMPORTANTE:
- NO exijas que cada D funcione con cualquier pareja concreta de
  pivote P y referente R. Puede ser perfectamente válida si funciona
  bien en ciertos territorios de conocimiento.
- NO exijas que el referente R sea literalmente la respuesta correcta:
  puede ser el objeto del hecho preguntado.
- NO penalices una dimensión solo por ser abstracta, especializada,
  menos frecuente o porque admitiría preguntas malas si se aplica mal.
- NO se te pide descartar las dimensiones, ni diseñar mejores dimensiones.
  Solo detectar posibles defectos estructurales y explicar los motivos.
- NO compares con otras evaluaciones; este juicio es independiente.
- Revisa las 86 entradas, sin omitir ninguna, independientemente del
  orden en que aparecen.
- Usa exactamente estos tres estados:
  "sin_objecion": no detectas problema estructural relevante.
  "riesgo": la definición presenta un riesgo justificable de ambigüedad,
    artificialidad o desplazamiento del hecho interrogado.
  "problematica": la definición empuja de forma especialmente marcada a
    preguntas poco naturales o a respuestas no factuales.
- Si dudas entre "sin_objecion" y "riesgo", indica "sin_objecion":
  buscamos defectos identificables, no especulaciones genéricas.
- Para CADA "riesgo" o "problematica", proporciona un motivo específico
  de la definición y un ejemplo breve de pregunta que ilustre el fallo.
  Los ejemplos fallidos no son evidencia de imposibilidad universal.

Devuelve exclusivamente JSON según el esquema.
"evaluaciones" debe contener exactamente 86 objetos {codigo, estado},
cada código una sola vez, sin importar el orden.
"alertas" debe contener exactamente una entrada por cada dimensión cuyo
estado NO sea "sin_objecion", con motivo y ejemplo_fallido.
No añadas alertas a las dimensiones sin objeción.

DIMENSIONES:
${dimensions.map((entry) => '${entry.key}: ${entry.value}').join('\n')}''';

Map<String, Object?> dimensionAuditSchema(List<String> codes) => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['evaluaciones', 'alertas'],
  'properties': {
    'evaluaciones': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['codigo', 'estado'],
        'properties': {
          'codigo': {'type': 'string', 'enum': codes},
          'estado': {
            'type': 'string',
            'enum': ['sin_objecion', 'riesgo', 'problematica'],
          },
        },
      },
    },
    'alertas': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['codigo', 'motivo', 'ejemplo_fallido'],
        'properties': {
          'codigo': {'type': 'string', 'enum': codes},
          'motivo': {'type': 'string'},
          'ejemplo_fallido': {'type': 'string'},
        },
      },
    },
  },
};

typedef DimensionAlert = ({String reason, String badExample});
typedef DimensionEvaluation = ({
  Map<String, String> status,
  Map<String, DimensionAlert> alerts,
});

/// Rechaza muestras parciales: sin 86 dictámenes no hay evaluación válida.
DimensionEvaluation parseDimensionEvaluation(
  String text,
  Set<String> expected,
) {
  final decoded = jsonDecode(text);
  if (decoded is! Map ||
      decoded.length != 2 ||
      decoded['evaluaciones'] is! List ||
      decoded['alertas'] is! List) {
    throw const FormatException('Auditoría JSON inválida.');
  }
  final rows = decoded['evaluaciones'] as List;
  if (rows.length != expected.length) {
    throw const FormatException('La auditoría no cubre las 86 dimensiones.');
  }
  final status = <String, String>{};
  for (final item in rows) {
    if (item is! Map || item.length != 2 ||
        item['codigo'] is! String || item['estado'] is! String) {
      throw const FormatException('Dictamen de dimensión inválido.');
    }
    final code = item['codigo'] as String;
    final state = item['estado'] as String;
    if (!expected.contains(code) ||
        !{'sin_objecion', 'riesgo', 'problematica'}.contains(state) ||
        status.containsKey(code)) {
      throw const FormatException('Código repetido o estado inválido.');
    }
    status[code] = state;
  }
  if (status.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(status.keys.toSet()).isNotEmpty) {
    throw const FormatException('Faltan códigos de dimensiones.');
  }
  final alerts = <String, DimensionAlert>{};
  for (final item in decoded['alertas'] as List) {
    if (item is! Map || item.length != 3 ||
        item['codigo'] is! String || item['motivo'] is! String ||
        item['ejemplo_fallido'] is! String) {
      throw const FormatException('Alerta de dimensión inválida.');
    }
    final code = item['codigo'] as String;
    final reason = (item['motivo'] as String).trim();
    final badExample = (item['ejemplo_fallido'] as String).trim();
    if (status[code] == null || status[code] == 'sin_objecion' ||
        alerts.containsKey(code) || reason.isEmpty || badExample.isEmpty) {
      throw const FormatException('Alerta inconsistente con su dictamen.');
    }
    alerts[code] = (reason: reason, badExample: badExample);
  }
  final flagged = status.entries
      .where((entry) => entry.value != 'sin_objecion')
      .map((entry) => entry.key)
      .toSet();
  if (flagged.length != alerts.length ||
      flagged.difference(alerts.keys.toSet()).isNotEmpty) {
    throw const FormatException('Faltan explicaciones de las objeciones.');
  }
  return (
    status: Map.unmodifiable(status),
    alerts: Map.unmodifiable(alerts),
  );
}

String _cell(String text) =>
    text.replaceAll('|', r'\|').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Frecuencia de objeciones: acuerdo del mismo modelo, no verificación factual.
String formatDimensionAuditReport(List<DimensionEvaluation> evaluations) {
  if (evaluations.isEmpty) {
    throw ArgumentError('Se necesita al menos una evaluación.');
  }
  final total = evaluations.length;
  final codes = evaluations.first.status.keys.toList()..sort();
  final ranking = [
    for (final code in codes)
      (
        code: code,
        risky: evaluations.where((e) => e.status[code] == 'riesgo').length,
        problematic: evaluations
            .where((e) => e.status[code] == 'problematica').length,
      ),
  ]..sort((a, b) {
      final objectionsA = a.risky + a.problematic;
      final objectionsB = b.risky + b.problematic;
      final byCount = objectionsB.compareTo(objectionsA);
      return byCount != 0 ? byCount : a.code.compareTo(b.code);
    });
  final output = StringBuffer()
    ..writeln('# Auditoría de dimensiones factuales D01-D86')
    ..writeln()
    ..writeln('Evaluaciones completas: $total. Un mismo modelo, '
        'criterio estable y orden de las D permutado.')
    ..writeln('Los números representan juicios del modelo, '
        'no tasas de éxito reales generando preguntas.')
    ..writeln()
    ..writeln('| D | Sin objeción | Riesgo | Problemática | Objeciones / $total |')
    ..writeln('|---|---:|---:|---:|---:|');
  for (final row in ranking) {
    final flagged = row.risky + row.problematic;
    output.writeln('| ${row.code} | ${total - flagged} | '
        '${row.risky} | ${row.problematic} | $flagged/$total |');
  }
  output.writeln('\n## Ejemplos y razones de las objeciones');
  for (final row in ranking.where(
      (item) => item.risky + item.problematic > 0)) {
    output.writeln('\n### ${row.code}: '
        '${row.risky + row.problematic}/$total objeciones');
    final examples = <String>{};
    for (var i = 0; i < evaluations.length; i++) {
      final alert = evaluations[i].alerts[row.code];
      if (alert == null) continue;
      final signature = '${alert.reason}\u0000${alert.badExample}';
      if (!examples.add(signature)) continue;
      output.writeln('- Evaluación ${i + 1}: '
          '${_cell(alert.reason)} '
          'Ejemplo fallido: ${_cell(alert.badExample)}');
      if (examples.length == 3) break;
    }
  }
  return output.toString();
}
