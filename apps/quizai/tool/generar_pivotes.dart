import 'dart:convert';
import 'dart:io';
import 'package:ai_apps_ai/ai_apps_ai.dart';

/// Piloto aislado de generación de respuestas; no modifica los catálogos de QuizAI.
Future<void> main(List<String> args) async {
  final model = args.isNotEmpty ? args.first.trim() : '';
  final option = args.indexOf('--muestras');
  final int? samples = option < 0
      ? 1
      : option + 1 < args.length ? int.tryParse(args[option + 1]) : null;
  if (model.isEmpty || samples == null || samples < 1 || samples > 100) {
    stderr.writeln('Uso: <modelo> [--ruta] [--muestras 1-100]');
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
  final watch = Stopwatch()..start();
  final batches = <List<ResponseItem>>[];
  final usedResponses = <String>[];
  final usedKeys = <String>{};
  var inputSum = 0;
  var outputSum = 0;
  var completeUsage = true;
  try {
    stdout.writeln('Modelo: ' + model);
    for (var sample = 0; sample < samples; sample++) {
      final callWatch = Stopwatch()..start();
      if (samples > 1) stdout.writeln('\n## Llamada ${sample + 1}/$samples');
      final result = await client.generate(
        application: 'quizai',
        model: model,
        input: buildResponsePrompt(usedResponses),
        schemaName: 'quizai_response_selection',
        schema: _schema(),
      ).timeout(const Duration(seconds: 90));
      final batch = parseResponseItems(result.text);
      batches.add(batch);
      stdout.writeln(formatResponseTable(batch));
      for (final item in batch) {
        if (usedKeys.add(_key(item.respuesta))) {
          usedResponses.add(item.respuesta);
        }
      }
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
      stdout.writeln('Entrada: ${inputTokens is int ? inputTokens : 'no disponible'} tokens | ${priceFor(inputTokens, inputRate)}');
      stdout.writeln('Salida: ${outputTokens is int ? outputTokens : 'no disponible'} tokens | ${priceFor(outputTokens, outputRate)}');
      stdout.writeln('Total: ${total ?? 'no disponible'} tokens | $totalPrice');
      stdout.writeln('Tiempo: ${callWatch.elapsedMilliseconds} ms');
      if (inputTokens is int && outputTokens is int) {
        inputSum += inputTokens;
        outputSum += outputTokens;
      } else {
        completeUsage = false;
      }
    }
    if (samples > 1) {
      stdout.writeln('\n## Comparación de las $samples llamadas');
      stdout.writeln(compareResponseBatches(batches));
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
  } catch (error) {
    stderr.writeln('ERROR: ' + error.toString());
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

const _promptHeader = r'''Selecciona 10 campos de conocimiento aleatorios y distintos (P).

En cada campo, encuentra un término, nombre o expresión (R)
que pueda servir como respuesta inequívoca a una pregunta de conocimiento.

Sea d(Rᵢ) la dificultad estimada de que una persona
con cultura general conozca Rᵢ.

d(R₁) < d(R₂) < ... < d(R₁₀)

id(Rᵢ) ∉ U ∪ {id(Rⱼ) : j < i}

U:''';

String buildResponsePrompt(Iterable<String> usedResponses) {
  final history = usedResponses.toList(growable: false);
  return '$_promptHeader\n${history.isEmpty ? '∅' : history.map((item) => '- $item').join('\n')}';
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
  for (var call = 0; call < batches.length; call++) {
    final items = batches[call];
    if (items.length != 10) {
      throw ArgumentError('Cada llamada debe contener 10 respuestas.');
    }
    fieldsPerCall.add(items.map((item) => _key(item.campo)).toSet().length);
    for (final item in items) {
      final key = _key(item.respuesta);
      names.putIfAbsent(key, () => item.respuesta);
      occurrences
          .putIfAbsent(key, () => <String>[])
          .add('llamada ${call + 1}, ${item.campo}');
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
  output.writeln(
    '\nNo se detectan equivalencias semánticas entre nombres distintos '
    'ni se verifica automáticamente la dificultad creciente.',
  );
  return output.toString();
}
