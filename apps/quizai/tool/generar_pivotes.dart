import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
  final selectedA1 = planInitialAttractors(samples);
  final usedReferents = <String>[];
  var inputSum = 0;
  var outputSum = 0;
  var completeUsage = true;
  try {
    stdout.writeln('Modelo: ' + model);
    for (var sample = 0; sample < samples; sample++) {
      final callWatch = Stopwatch()..start();
      if (samples > 1) stdout.writeln('\n## Llamada ${sample + 1}/$samples');
      if (samples > 1) stdout.writeln('Referentes A5 previos en U: ${usedReferents.length}');
      final result = await client.generate(
        application: 'quizai',
        model: model,
        input: buildExpansionPrompt(
          selectedA1[sample],
          usedReferents: usedReferents,
        ),
        schemaName: 'quizai_semantic_expansion',
        schema: _schema(),
      ).timeout(const Duration(seconds: 90));
      final data = jsonDecode(result.text);
      if (data is! Map || data['table'] is! String) {
        throw const FormatException('Respuesta inválida: falta la tabla.');
      }
      final markdown = (data['table'] as String).trim();
      final table = parseExpansionTable(markdown, selectedA1[sample]);
      tables.add(table);
      usedReferents.addAll(
        _pivotNames.map((pivot) => table[pivot]!.last),
      );
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
      stdout.writeln(compareExpansionTables(tables, selectedA1));
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

/// Índice oficial de puertas de entrada A1, revisable independientemente del prompt.
const initialAttractorsByPivot = <String, List<String>>{
  'Ciencias naturales': <String>[
    'Física', 'Química', 'Biología', 'Ciencias de la Tierra', 'Astronomía',
  ],
  'Ciencias formales': <String>[
    'Matemáticas', 'Lógica', 'Estadística', 'Computación teórica',
  ],
  'Ciencias sociales': <String>[
    'Sociología', 'Economía', 'Antropología', 'Ciencia política',
    'Demografía', 'Geografía humana', 'Psicología',
    'Ciencias de la comunicación',
  ],
  'Historia': <String>[
    'Prehistoria', 'Antigua', 'Medieval', 'Moderna', 'Contemporánea',
    'Política', 'Social', 'Económica', 'Cultural', 'Militar',
  ],
  'Humanidades': <String>[
    'Filosofía', 'Lingüística', 'Filología', 'Literatura',
    'Estudios religiosos', 'Estudios culturales',
  ],
  'Tecnología e ingeniería': <String>[
    'Informática', 'Ingeniería mecánica', 'Ingeniería eléctrica',
    'Ingeniería civil', 'Ingeniería química', 'Ingeniería industrial',
    'Ingeniería de materiales', 'Telecomunicaciones',
  ],
  'Artes': <String>[
    'Música', 'Artes visuales', 'Artes escénicas', 'Artes audiovisuales',
    'Literatura', 'Arquitectura', 'Diseño',
  ],
  'Salud y medicina': <String>[
    'Medicina', 'Salud pública', 'Ciencias biomédicas',
  ],
};

/// Muestreo aleatorio equilibrado: se baraja cada lista y se agota antes de
/// volver a barajarla. Con listas de menos de N elementos, A1 se reutiliza.
List<Map<String, String>> planInitialAttractors(
  int sampleCount, {
  Random? random,
}) {
  if (sampleCount < 1) throw ArgumentError.value(sampleCount, 'sampleCount');
  final rng = random ?? Random.secure();
  final bags = <String, List<String>>{
    for (final pivot in _pivotNames) pivot: <String>[],
  };
  return List.generate(sampleCount, (_) {
    final chosen = <String, String>{};
    for (final pivot in _pivotNames) {
      final bag = bags[pivot]!;
      if (bag.isEmpty) {
        bag.addAll(initialAttractorsByPivot[pivot]!);
        bag.shuffle(rng);
      }
      chosen[pivot] = bag.removeLast();
    }
    return Map<String, String>.unmodifiable(chosen);
  });
}

const _promptHeader = r'''# PROMPT · EXPANSIÓN SEMÁNTICA

Sea $S_n^{(p)}=(x_0^{(p)},x_1^{(p)},\ldots,x_n^{(p)})$,
con $(x_0^{(p)},x_1^{(p)},x_2^{(p)})=(C,P_p,A_1^{(p)})$.

$$
\boxed{
\begin{aligned}
x_{n+1}^{(p)} &\in F(x_{n-1}^{(p)},x_n^{(p)}\mid S_n^{(p)}),
    && n=2,\ldots,5,\\
\rho(S_{n+1}^{(p)}) &> \rho(S_n^{(p)}),
    && n=2,\ldots,5,\\
x_{n+1}^{(p)} &\not\equiv_S x_i^{(p)},
    && 0\le i\le n,\\
x_6^{(p)} &\in \mathcal R_{\mathrm{concreta}},\\
\operatorname{id}(x_6^{(p)}) &\notin U,\\
\operatorname{id}(x_6^{(p)}) &\ne \operatorname{id}(x_6^{(q)}),
    && p\ne q.
\end{aligned}
}
$$

$F$: admisibilidad semántica según el recorrido acumulado.
$\rho$: resolución semántica del recorrido acumulado.
$\equiv_S$: identidad semántica, incluidas reformulaciones del mismo referente.
$\mathcal R_{\mathrm{concreta}}$: referentes concretos, identificables y consultables; no campos generales de estudio.
$\operatorname{id}$: identidad del referente, independiente de cómo se nombre.
$U$: referentes A5 de llamadas anteriores, indicados debajo.

## Objetivo

Completa los atractores A2, A3, A4 y A5 de cada fila.

Los A1 han sido seleccionados previamente. En cada desplazamiento, el pivote
anterior pasa a ser contexto y el atractor anterior pasa a ser pivote.

Conserva literalmente los pivotes y atractores A1 proporcionados.''';

const _tableHeader = r'''## Contexto: Conocimiento general

| Pivote | Atractor 1 | Atractor 2 | Atractor 3 | Atractor 4 | Atractor 5 |
|---|---|---|---|---|---|''';

const _promptFooter = '''

## Formato de salida

Devuelve exclusivamente la tabla completada en Markdown.''';

String buildExpansionPrompt(
  Map<String, String> initialA1, {
  Iterable<String> usedReferents = const <String>[],
}) {
  if (initialA1.length != _pivotNames.length ||
      _pivotNames.any((pivot) =>
          !initialAttractorsByPivot[pivot]!.contains(initialA1[pivot]))) {
    throw ArgumentError('Los A1 deben proceder del índice oficial.');
  }
  final used = usedReferents.toList(growable: false);
  final history = used.isEmpty
      ? '∅'
      : used.map((referent) => '- $referent').join('\n');
  final rows = [
    for (final pivot in _pivotNames)
      '| $pivot | ${initialA1[pivot]} | | | | |',
  ].join('\n');
  return '$_promptHeader\n\n## U · Referentes A5 ya utilizados\n$history\n\n'
      '$_tableHeader\n$rows\n$_promptFooter';
}

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

/// Acepta tablas Markdown con o sin delimitadores de bloque.
Map<String, List<String>> parseExpansionTable(
  String markdown,
  Map<String, String> expectedA1,
) {
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
  for (final pivot in _pivotNames) {
    if (rows[pivot]!.first != expectedA1[pivot]) {
      throw FormatException('El modelo modificó A1 de $pivot.');
    }
  }
  return rows;
}

String _key(String name) =>
    name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

String _prefix(List<String> row, int n) =>
    row.take(n).map(_key).join('\u001f');

/// Separa el A1 escogido por Dart de las continuaciones A2–A5 de Luna.
/// «Variantes Luna» cuenta rutas adicionales para A1 que se han reutilizado.
String compareExpansionTables(
  List<Map<String, List<String>>> tables,
  List<Map<String, String>> selectedA1,
) {
  if (tables.isEmpty) throw ArgumentError('No hay tablas para comparar.');
  if (tables.length != selectedA1.length) {
    throw ArgumentError('Debe haber una selección A1 por llamada.');
  }
  for (var i = 0; i < tables.length; i++) {
    for (final pivot in _pivotNames) {
      if (tables[i][pivot]?.first != selectedA1[i][pivot]) {
        throw ArgumentError('La tabla no coincide con los A1 de la llamada.');
      }
    }
  }
  final output = StringBuffer()
    ..writeln('A1 distintos: diversidad asignada por Dart.')
    ..writeln('A1–A2…A1–A5: prefijos textuales distintos tras continuar Luna.')
    ..writeln('Variantes Luna: rutas nuevas para A1 ya repetidos.')
    ..writeln('| Pivote | A1 (Dart) | A1–A2 | A1–A3 | A1–A4 | A1–A5 | Variantes Luna | Rutas repetidas |')
    ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|');
  var totalInitial = 0;
  var totalUnique = 0;
  var totalVariants = 0;
  final coincidences = <String>[];
  for (final pivot in _pivotNames) {
    final rows = [for (final table in tables) table[pivot]!];
    final initialCount = selectedA1.map((call) => call[pivot]).toSet().length;
    final counts = [
      for (var n = 1; n <= 5; n++)
        rows.map((row) => _prefix(row, n)).toSet().length,
    ];
    final variants = counts.last - initialCount;
    totalInitial += initialCount;
    totalUnique += counts.last;
    totalVariants += variants;
    output.writeln(
      '| $pivot | $initialCount | ${counts.skip(1).join(' | ')} | $variants | ${rows.length - counts.last} |',
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
    '\nDart: $totalInitial A1 distintos en '
    '${tables.length * _pivotNames.length} asignaciones.',
  );
  output.writeln(
    'Luna: $totalVariants variantes adicionales con el mismo A1.',
  );
  output.writeln(
    'Recorridos completos distintos: $totalUnique de '
    '${tables.length * _pivotNames.length} generados.',
  );
  if (coincidences.isEmpty) {
    output.writeln('No hay recorridos completos idénticos dentro del mismo pivote.');
  } else {
    output.writeln('\nRepeticiones exactas:');
    for (final item in coincidences) {
      output.writeln('- $item');
    }
  }
  final referentLocations = <String, List<String>>{};
  for (var sample = 0; sample < tables.length; sample++) {
    for (final pivot in _pivotNames) {
      final referent = tables[sample][pivot]!.last;
      referentLocations
          .putIfAbsent(_key(referent), () => <String>[])
          .add('llamada ${sample + 1}, $pivot');
    }
  }
  final duplicatedDestinations = referentLocations.values
      .where((locations) => locations.length > 1)
      .toList();
  output.writeln(
    '\nReferentes A5 textualmente distintos: ${referentLocations.length} de '
    '${tables.length * _pivotNames.length}.',
  );
  if (duplicatedDestinations.isNotEmpty) {
    output.writeln('A5 repetidos textualmente entre filas o llamadas:');
    for (final locations in duplicatedDestinations) {
      output.writeln('- ${locations.join('; ')}');
    }
  } else {
    output.writeln('No hay A5 repetidos textualmente entre filas o llamadas.');
  }
  output.writeln(
    '\nComparación textual normalizada: no detecta sinónimos '
    'ni comprueba la corrección semántica.',
  );
  return output.toString();
}
