import 'dart:convert';
import 'dart:io';
import 'package:ai_apps_ai/ai_apps_ai.dart';

/// Piloto aislado de generación de respuestas; no modifica los catálogos de QuizAI.
Future<void> main(List<String> args) async {
  final model = args.isNotEmpty ? args.first.trim() : '';
  final option = args.indexOf('--muestras');
  final sinU = args.contains('--sin-u');
  final excluirTop3 = args.contains('--excluir-top3');
  final resumen = args.contains('--resumen');
  final int? samples = option < 0
      ? 1
      : option + 1 < args.length ? int.tryParse(args[option + 1]) : null;
  if (model.isEmpty || samples == null || samples < 1 || samples > 100) {
    stderr.writeln('Uso: <modelo> [--ruta] [--muestras 1-100] [--sin-u] [--excluir-top3] [--resumen]');
    exitCode = 1;
    return;
  }
  final sessionFile = File('../../.ai-apps/dart-service.json');
  if (!await sessionFile.exists()) {
    stderr.writeln('El servicio de IA no está iniciado. Arráncalo con run.ps1.');
    exitCode = 1;
    return;
  }
  final session = jsonDecode(await sessionFile.readAsString());
  if (session is! Map || session['endpoint'] is! String ||
      session['token'] is! String) {
    stderr.writeln('Sesión del servicio de IA inválida.');
    exitCode = 1;
    return;
  }
  final endpoint = Uri.tryParse(session['endpoint'] as String);
  if (endpoint == null || endpoint.scheme != 'http' ||
      endpoint.host != '127.0.0.1') {
    stderr.writeln('Endpoint local del servicio de IA inválido.');
    exitCode = 1;
    return;
  }
  final client = AiAppsClient(
    endpoint: endpoint,
    authorization: session['token'] as String,
  );
  final resultsDir = Directory('../../.ai-apps/experimentos-pivotes');
  await resultsDir.create(recursive: true);
  final runId = DateTime.now().toUtc().toIso8601String()
      .replaceAll(':', '-').replaceAll('.', '-');
  final rawFile = File('${resultsDir.path}/pivotes-$runId.jsonl');
  final summaryFile = File('${resultsDir.path}/pivotes-$runId-resumen.md');
  final watch = Stopwatch()..start();
  final batches = <List<ResponseItem>>[];
  var inputSum = 0;
  var outputSum = 0;
  var completeUsage = true;
  try {
    stdout.writeln('Modelo: ' + model);
    stdout.writeln('Historial U: ${sinU ? 'desactivado' : 'reinicio cada 10 llamadas'}');
    if (excluirTop3) stdout.writeln('P excluidos: Historia, Geografía, Biología');
    for (var sample = 0; sample < samples; sample++) {
      final callWatch = Stopwatch()..start();
      if (samples > 1 && sample % historyBlockSize == 0) {
        stdout.writeln('\n## Lote ${sample ~/ historyBlockSize + 1}/${(samples + historyBlockSize - 1) ~/ historyBlockSize}');
      }
      if (samples > 1 && !resumen) stdout.writeln('\n## Llamada ${sample + 1}/$samples');
      final result = await client.generate(
        application: 'quizai',
        model: model,
        input: buildResponsePrompt(
          sinU ? const <String>[] : responseHistoryForCall(batches),
          sinU: sinU,
          excluirTop3: excluirTop3,
        ),
        schemaName: 'quizai_response_selection',
        schema: _schema(),
      ).timeout(const Duration(seconds: 90));
      final batch = parseResponseItems(result.text);
      batches.add(batch);
      if (!resumen) stdout.writeln(formatResponseTable(batch));
      final usage = result.usage;
      final inputTokens = usage?['inputTokens'];
      final outputTokens = usage?['outputTokens'];
      final totalTokens = usage?['totalTokens'];
      final rates = _modelRates[model.toLowerCase()];
      final inputRate = rates?.inputUsdPerMillion;
      final outputRate = rates?.outputUsdPerMillion;
      String priceFor(Object? tokens, double? rate) =>
          tokens is int && rate != null
              ? (tokens * rate / 1000000).toStringAsFixed(6) + ' USD'
              : 'no disponible';
      final total = totalTokens is int
          ? totalTokens
          : inputTokens is int && outputTokens is int
              ? inputTokens + outputTokens
              : null;
      final totalPrice = inputTokens is int &&
              outputTokens is int &&
              inputRate != null &&
              outputRate != null
          ? ((inputTokens * inputRate + outputTokens * outputRate) / 1000000)
              .toStringAsFixed(6) + ' USD'
          : 'no disponible';
      if (!resumen) {
        stdout.writeln('Entrada: ${inputTokens is int ? inputTokens : 'no disponible'} tokens | ${priceFor(inputTokens, inputRate)}');
        stdout.writeln('Salida: ${outputTokens is int ? outputTokens : 'no disponible'} tokens | ${priceFor(outputTokens, outputRate)}');
        stdout.writeln('Total: ${total ?? 'no disponible'} tokens | $totalPrice');
        stdout.writeln('Tiempo: ${callWatch.elapsedMilliseconds} ms');
      }
      final observation = {
        'llamada': sample + 1,
        'lote': sample ~/ historyBlockSize + 1,
        'modelo': model,
        'sinU': sinU,
        'excluirTop3': excluirTop3,
        'items': [
          for (final item in batch)
            {'campo': item.campo, 'respuesta': item.respuesta},
        ],
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
      };
      await rawFile.writeAsString(
        '${jsonEncode(observation)}\n',
        mode: FileMode.append,
        flush: true,
      );
      if (inputTokens is int && outputTokens is int) {
        inputSum += inputTokens;
        outputSum += outputTokens;
      } else {
        completeUsage = false;
      }
    }
    if (samples > 1) {
      stdout.writeln('\n## Comparación de las $samples llamadas');
      if (!resumen) stdout.writeln(compareResponseBatches(batches));
      final rates = _modelRates[model.toLowerCase()];
      final cost = completeUsage && rates != null
          ? ((inputSum * rates.inputUsdPerMillion +
                  outputSum * rates.outputUsdPerMillion) / 1000000)
              .toStringAsFixed(6) + ' USD'
          : 'no disponible';
      stdout.writeln(
        'Acumulado: ${completeUsage ? inputSum : 'no disponible'} tokens de entrada; '
        '${completeUsage ? outputSum : 'no disponible'} tokens de salida; $cost',
      );
      stdout.writeln('Tiempo acumulado: ${watch.elapsedMilliseconds} ms');
    }
    final report = formatExperimentReport(batches);
    await summaryFile.writeAsString(report, flush: true);
    if (resumen) stdout.writeln(report);
    stdout.writeln('Datos completos: ${rawFile.path}');
    stdout.writeln('Informe: ${summaryFile.path}');
  } catch (error) {
    stderr.writeln('ERROR: ' + error.toString());
    stderr.writeln('Datos generados hasta el error: ${rawFile.path}');
    exitCode = 1;
  } finally {
    client.close();
  }
}

// Tarifas USD por millón de tokens facilitadas para este proyecto.
typedef _ModelRates = ({double inputUsdPerMillion, double outputUsdPerMillion});

const Map<String, _ModelRates> _modelRates = {
  'gpt-5.6-terra': (inputUsdPerMillion: 2.0, outputUsdPerMillion: 12.0),
  'gpt-5.6-sol': (inputUsdPerMillion: 4.0, outputUsdPerMillion: 20.0),
  'gpt-5.6-luna': (inputUsdPerMillion: 0.20, outputUsdPerMillion: 1.20),
  'gpt-5.4-mini': (inputUsdPerMillion: 0.75, outputUsdPerMillion: 4.50),
};

/// Pareja directa: campo de conocimiento y respuesta, sin niveles A1-A5.
typedef ResponseItem = ({String campo, String respuesta});

const int historyBlockSize = 10;

/// Solo las respuestas de las llamadas anteriores del lote actual entran en U.
/// Las llamadas completas siguen conservándose en [batches] para el informe global.
List<String> responseHistoryForCall(List<List<ResponseItem>> batches) {
  final blockStart = (batches.length ~/ historyBlockSize) * historyBlockSize;
  final seen = <String>{};
  final history = <String>[];
  for (final batch in batches.skip(blockStart)) {
    for (final item in batch) {
      if (seen.add(_key(item.respuesta))) history.add(item.respuesta);
    }
  }
  return history;
}

const _promptHeader = r'''Selecciona 10 campos de conocimiento aleatorios y distintos (P).

Pᵢ: nombre de un campo de conocimiento.
Rᵢ: término, nombre o expresión concreta e identificable de Pᵢ.

Cada valor contiene únicamente su denominación.

Sea d(Rᵢ) la dificultad estimada de que una persona
con cultura general conozca Rᵢ.

d(R₁) < d(R₂) < ... < d(R₁₀)''';

const _withHistoryConstraint = r'''id(Rᵢ) ∉ U ∪ {id(Rⱼ) : j < i}

U:''';

const _withoutHistoryConstraint = r'''id(Rᵢ) ∉ {id(Rⱼ) : j < i}''';

const _excludedTop3Constraint = r'Pᵢ ∉ {Historia, Geografía, Biología}';

String buildResponsePrompt(
  Iterable<String> usedResponses, {
  bool sinU = false,
  bool excluirTop3 = false,
}) {
  final header = excluirTop3
      ? '$_promptHeader\n\n$_excludedTop3Constraint'
      : _promptHeader;
  if (sinU) return '$header\n\n$_withoutHistoryConstraint';
  final history = usedResponses.toList(growable: false);
  return '$header\n\n$_withHistoryConstraint\n'
      '${history.isEmpty ? '∅' : history.map((item) => '- $item').join('\n')}';
}

/// La estructura de salida pertenece a Dart, no al prompt de Luna.
Map<String, Object?> _schema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['items'],
  'properties': {
    'items': {
      'type': 'array',
      'minItems': 10,
      'maxItems': 10,
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['campo', 'respuesta'],
        'properties': {
          'campo': {'type': 'string'},
          'respuesta': {'type': 'string'},
        },
      },
    },
  },
};

List<ResponseItem> parseResponseItems(String response) {
  final decoded = jsonDecode(response);
  if (decoded is! Map || decoded['items'] is! List) {
    throw const FormatException('Respuesta inválida: faltan las respuestas.');
  }
  final rawItems = decoded['items'] as List;
  if (rawItems.length != 10) {
    throw const FormatException('Se esperaban exactamente 10 respuestas.');
  }
  final items = <ResponseItem>[];
  for (final raw in rawItems) {
    if (raw is! Map || raw['campo'] is! String ||
        raw['respuesta'] is! String) {
      throw const FormatException('Cada fila necesita campo y respuesta.');
    }
    final campo = (raw['campo'] as String).trim();
    final respuesta = (raw['respuesta'] as String).trim();
    if (campo.isEmpty || respuesta.isEmpty) {
      throw const FormatException('Los campos y las respuestas no pueden estar vacíos.');
    }
    items.add((campo: campo, respuesta: respuesta));
  }
  return List<ResponseItem>.unmodifiable(items);
}

String _key(String value) =>
    value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

String _markdownCell(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').replaceAll('|', r'\|').trim();

String formatResponseTable(List<ResponseItem> items) {
  final output = StringBuffer()
    ..writeln('| Campo de conocimiento | Respuesta |')
    ..writeln('|---|---|');
  for (final item in items) {
    output.writeln(
      '| ${_markdownCell(item.campo)} | ${_markdownCell(item.respuesta)} |',
    );
  }
  return output.toString();
}

/// Analiza repeticiones textuales sin bloquear la generación.
String compareResponseBatches(List<List<ResponseItem>> batches) {
  if (batches.isEmpty) throw ArgumentError('No hay llamadas para comparar.');
  final occurrences = <String, List<String>>{};
  final names = <String, String>{};
  final fieldsPerCall = <int>[];
  final fields = <String, int>{};
  final fieldNames = <String, String>{};
  final firstPosition = <String, int>{};
  final discoveredFields = <String>{};
  final newFieldsByBlock = <int>[];
  var newFieldsInBlock = 0;
  for (var call = 0; call < batches.length; call++) {
    final items = batches[call];
    if (items.length != 10) {
      throw ArgumentError('Cada llamada debe contener 10 respuestas.');
    }
    fieldsPerCall.add(items.map((item) => _key(item.campo)).toSet().length);
    for (var row = 0; row < items.length; row++) {
      final item = items[row];
      final fieldKey = _key(item.campo);
      fieldNames.putIfAbsent(fieldKey, () => item.campo);
      fields.update(fieldKey, (count) => count + 1, ifAbsent: () => 1);
      if (row == 0) {
        firstPosition.update(fieldKey, (count) => count + 1,
            ifAbsent: () => 1);
      }
      if (discoveredFields.add(fieldKey)) newFieldsInBlock++;

      final answerKey = _key(item.respuesta);
      names.putIfAbsent(answerKey, () => item.respuesta);
      occurrences
          .putIfAbsent(answerKey, () => <String>[])
          .add('llamada ${call + 1}, ${item.campo}');
    }
    if ((call + 1) % 10 == 0 || call + 1 == batches.length) {
      newFieldsByBlock.add(newFieldsInBlock);
      newFieldsInBlock = 0;
    }
  }
  final total = batches.length * 10;
  final output = StringBuffer()
    ..writeln('Campos distintos por llamada: ${fieldsPerCall.join(', ')} de 10.')
    ..writeln('Respuestas textualmente distintas: ${occurrences.length} de $total.')
    ..writeln('Repeticiones textuales: ${total - occurrences.length}.');
  final duplicateKeys = occurrences.keys
      .where((key) => occurrences[key]!.length > 1);
  for (final key in duplicateKeys) {
    output.writeln('- ${names[key]} — ${occurrences[key]!.join('; ')}');
  }

  final orderedFields = fields.keys.toList()
    ..sort((a, b) {
      final byFrequency = fields[b]!.compareTo(fields[a]!);
      return byFrequency != 0 ? byFrequency :
          fieldNames[a]!.compareTo(fieldNames[b]!);
    });
  output
    ..writeln('\n## Distribución empírica de pivotes P')
    ..writeln('Campos textualmente distintos: ${fields.length} de $total selecciones.')
    ..writeln('| Campo P | Frecuencia | Porcentaje | Primera posición |')
    ..writeln('|---|---:|---:|---:|');
  for (final key in orderedFields) {
    final count = fields[key]!;
    final percent = (100 * count / total).toStringAsFixed(1);
    output.writeln(
      '| ${_markdownCell(fieldNames[key]!)} | $count | $percent% | '
      '${firstPosition[key] ?? 0} |',
    );
  }
  output.writeln(
    'Campos nuevos descubiertos por bloque consecutivo de hasta 10 llamadas: '
    '${newFieldsByBlock.join(', ')}.',
  );
  output.writeln(
    '\nComparación textual normalizada: no unifica sinónimos ni elimina '
    'preguntas añadidas dentro del nombre del campo. La frecuencia de P '
    'describe las selecciones de este modelo y prompt, no la cantidad '
    'de respuestas existentes en cada disciplina.',
  );
  output.writeln(
    'No se detectan equivalencias semánticas entre nombres distintos '
    'ni se verifica automáticamente la dificultad creciente.',
  );
  return output.toString();
}


/// Informe persistente: cada lote se analiza por separado sin perder la
/// comparación global de todas las llamadas. No modifica el historial U.
String formatExperimentReport(List<List<ResponseItem>> batches) {
  if (batches.isEmpty) throw ArgumentError('No hay llamadas para comparar.');

  final output = StringBuffer()
    ..writeln('# Experimento de pivotes')
    ..writeln()
    ..writeln('Llamadas: ${batches.length}. '
        'Selecciones: ${batches.length * 10}.')
    ..writeln()
    ..writeln('## Evolución por lote')
    ..writeln('| Lote | Llamadas | P distintos | P nuevos | P acumulados | R distintas |')
    ..writeln('|---|---:|---:|---:|---:|---:|');

  final seenFields = <String>{};
  for (var start = 0; start < batches.length; start += historyBlockSize) {
    final block = batches.skip(start).take(historyBlockSize).toList();
    final fields = <String>{};
    final responses = <String>{};
    for (final items in block) {
      if (items.length != 10) {
        throw ArgumentError('Cada llamada debe contener 10 respuestas.');
      }
      for (final item in items) {
        fields.add(_key(item.campo));
        responses.add(_key(item.respuesta));
      }
    }
    final newFields = fields.difference(seenFields).length;
    seenFields.addAll(fields);
    output.writeln(
      '| B${start ~/ historyBlockSize + 1} | ${block.length} | '
      '${fields.length} | $newFields | ${seenFields.length} | '
      '${responses.length} |',
    );
  }

  output
    ..writeln()
    ..writeln('La novedad de P es textual: no fusiona sinónimos ni elimina '
        'contenido añadido dentro del campo.')
    ..writeln()
    ..writeln('## Comparación global')
    ..writeln(compareResponseBatches(batches));
  return output.toString();
}
