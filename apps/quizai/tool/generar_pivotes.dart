import 'dart:convert';
import 'dart:io';
import 'package:ai_apps_ai/ai_apps_ai.dart';

/// Piloto aislado de expansión semántica; no modifica los catálogos de QuizAI.
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
  final tables = <Map<String, List<String>>>[];
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
      input: _prompt,
      schemaName: 'quizai_semantic_expansion',
      schema: _schema(),
    ).timeout(const Duration(seconds: 90));
    final data = jsonDecode(result.text);
    if (data is! Map || data['table'] is! String) {
      throw const FormatException('Respuesta inválida: falta la tabla.');
    }
    final markdown = (data['table'] as String).trim();
    tables.add(parseExpansionTable(markdown));
    stdout.writeln(markdown);
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
      stdout.writeln(compareExpansionTables(tables));
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

const _prompt = r'''# PROMPT · EXPANSIÓN SEMÁNTICA

Sea una secuencia de conceptos:

$$
S=(x_0,x_1,\ldots,x_n)
$$

Cada nuevo elemento se obtiene mediante:

$$
\boxed{x_{n+1}\in F(x_{n-1},x_n\mid S)}
$$

Donde $F representa el conjunto de atractores semánticamente admisibles para la configuración actual, considerando el significado acumulado de la secuencia.


Devuelve exclusivamente la tabla completada en bloque md``` literal.

---

# TABLA

## Contexto: Conocimiento general

| Pivote | Atractor 1 | Atractor 2 | Atractor 3 | Atractor 4 | Atractor 5 |
|---|---|---|---|---|---|
| Ciencias naturales | Química | Orgánica | Hidrocarburos | Aromáticos | Benceno |
| Ciencias formales | | | | | |
| Ciencias sociales | | | | | |
| Historia | | | | | |
| Humanidades | | | | | |
| Tecnología e ingeniería | | | | | |
| Artes | | | | | |
| Salud y medicina | | | | | |

---''';

Map<String, Object?> _schema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['table'],
  'properties': {
    'table': {'type': 'string'},
  },
};

const _pivotNames = <String>[
  'Ciencias naturales', 'Ciencias formales', 'Ciencias sociales',
  'Historia', 'Humanidades', 'Tecnología e ingeniería', 'Artes',
  'Salud y medicina',
];

const _fixedExample = <String>[
  'Química', 'Orgánica', 'Hidrocarburos', 'Aromáticos', 'Benceno',
];

/// Acepta tablas Markdown con o sin delimitadores de bloque.
Map<String, List<String>> parseExpansionTable(String markdown) {
  final rows = <String, List<String>>{};
  for (final raw in markdown.split('\n')) {
    final line = raw.trim();
    if (!line.startsWith('|') || !line.endsWith('|')) continue;
    final cells = line.substring(1, line.length - 1)
        .split('|').map((cell) => cell.trim()).toList();
    if (cells.first.toLowerCase() == 'pivote' ||
        RegExp(r'^:?-{3,}:?$').hasMatch(cells.first)) continue;
    if (cells.length != 6 ||
        !_pivotNames.contains(cells.first) ||
        cells.skip(1).any((cell) => cell.isEmpty) ||
        rows.containsKey(cells.first)) {
      throw const FormatException('Tabla de expansión inválida.');
    }
    rows[cells.first] = List.unmodifiable(cells.skip(1));
  }
  if (rows.length != _pivotNames.length) {
    throw const FormatException('Faltan pivotes en la tabla.');
  }
  for (var i = 0; i < _fixedExample.length; i++) {
    if (_key(rows[_pivotNames.first]![i]) != _key(_fixedExample[i])) {
      throw const FormatException('El modelo modificó la fila del ejemplo.');
    }
  }
  return rows;
}

String _key(String name) =>
    name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

String _prefix(List<String> row, int n) =>
    row.take(n).map(_key).join('\u001f');

/// A1..A5 muestran cuántos prefijos diferentes hay en cada profundidad.
/// La fila inicial no interviene: ya venía completada en el prompt.
String compareExpansionTables(List<Map<String, List<String>>> tables) {
  if (tables.isEmpty) throw ArgumentError('No hay tablas para comparar.');
  final output = StringBuffer()
    ..writeln('Se excluye Ciencias naturales (ejemplo fijo del prompt).')
    ..writeln('A1…A5: número de prefijos completos diferentes.')
    ..writeln('| Pivote | A1 | A1–A2 | A1–A3 | A1–A4 | A1–A5 | Repeticiones exactas |')
    ..writeln('|---|---:|---:|---:|---:|---:|---:|');
  var totalUnique = 0;
  final coincidences = <String>[];
  for (final pivot in _pivotNames.skip(1)) {
    final rows = [for (final table in tables) table[pivot]!];
    final counts = [
      for (var n = 1; n <= 5; n++)
        rows.map((row) => _prefix(row, n)).toSet().length,
    ];
    totalUnique += counts.last;
    output.writeln(
      '| $pivot | ${counts.join(' | ')} | ${rows.length - counts.last} |',
    );
    final groups = <String, List<int>>{};
    for (var i = 0; i < rows.length; i++) {
      groups.putIfAbsent(_prefix(rows[i], 5), () => []).add(i + 1);
    }
    for (final calls in groups.values) {
      if (calls.length > 1) {
        coincidences.add(
          '$pivot — llamadas ${calls.join(', ')}: '
          '${rows[calls.first - 1].join(' → ')}',
        );
      }
    }
  }
  output.writeln(
    '\nRecorridos distintos: $totalUnique de '
    '${tables.length * (_pivotNames.length - 1)} generados.',
  );
  if (coincidences.isEmpty) {
    output.writeln('No hay filas generadas idénticas dentro del mismo pivote.');
  } else {
    output.writeln('\nRepeticiones exactas:');
    for (final item in coincidences) {
      output.writeln('- $item');
    }
  }
  output.writeln(
    '\nComparación textual normalizada: no detecta sinónimos '
    'ni comprueba la corrección semántica.',
  );
  return output.toString();
}
