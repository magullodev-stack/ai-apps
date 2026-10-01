import 'dart:io';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:quizai/modes/quiz10/quiz10_DART_Pi+Di.dart';
import 'package:quizai/modes/quiz10/quiz10_LUNA_Prompt.dart';

final class _Question {
  const _Question(this.call, this.position, this.p, this.d, this.q, this.r);

  final int call;
  final int position;
  final String p;
  final String d;
  final String q;
  final String r;

  String get reference => 'L$call/F$position [$p/$d]';
}

String _key(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _lexical(String text) => _key(text)
    .replaceAll(RegExp(r'[¿?¡!.,;:()"“”‘’\[\]{}]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int _words(String text) => text.trim().split(RegExp(r'\s+')).length;

int? _usage(Map<String, dynamic>? usage, String key) {
  final value = usage?[key];
  return value is int && value >= 0 ? value : null;
}

String _known(int? count) => count?.toString() ?? 'n/d';

double? _rate(Map<String, String> env, String key) {
  final raw = env[key]?.trim();
  if (raw == null || raw.isEmpty) return null;
  final price = double.tryParse(raw.replaceAll(',', '.'));
  if (price == null || !price.isFinite || price < 0) {
    throw FormatException('Tarifa inválida para $key: $raw');
  }
  return price;
}

double? _estimatedCost({
  required int? input,
  required int? output,
  required int? cached,
  required double? inputRate,
  required double? outputRate,
  required double? cachedRate,
}) {
  if (input == null || output == null ||
      inputRate == null || outputRate == null ||
      (cached != null && cached > input)) {
    return null;
  }
  // La caché sin tarifa explícita se valora a tarifa de entrada normal.
  // La cifra es una estimación conservadora, no el importe facturado.
  final pricedCached = cached ?? 0;
  return ((input - pricedCached) * inputRate +
          pricedCached * (cachedRate ?? inputRate) +
          output * outputRate) /
      1000000;
}

String _usd(double? value) =>
    value == null ? 'n/d' : 'USD ${value.toStringAsFixed(6)}';

Map<String, List<_Question>> _groups(
  List<_Question> rows,
  String Function(_Question) key,
) {
  final groups = <String, List<_Question>>{};
  for (final row in rows) {
    groups.putIfAbsent(key(row), () => <_Question>[]).add(row);
  }
  return groups;
}

void _reportDuplicates(
  IOSink report,
  String label,
  Map<String, List<_Question>> groups, {
  required String Function(_Question) value,
}) {
  final repeated = groups.values.where((group) => group.length > 1).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  var extra = 0;
  var within = 0;
  var across = 0;
  var crossCallGroups = 0;
  var laterCallOccurrences = 0;
  var repeatSameP = 0;
  var repeatOtherP = 0;
  var repeatSameD = 0;
  var repeatOtherD = 0;
  var repeatSamePD = 0;
  var repeatOtherPD = 0;

  for (final group in repeated) {
    final counts = <int, int>{};
    for (final item in group) {
      counts.update(item.call, (n) => n + 1, ifAbsent: () => 1);
    }
    extra += group.length - 1;
    within += group.length - counts.length;
    across += counts.length - 1;
    if (counts.length > 1) crossCallGroups++;

    // Solo comparamos apariciones con llamadas anteriores, no la misma.
    for (final current in group) {
      final earlier = group.where((item) => item.call < current.call).toList();
      if (earlier.isEmpty) continue;
      laterCallOccurrences++;
      if (earlier.any((item) => item.p == current.p)) {
        repeatSameP++;
      } else {
        repeatOtherP++;
      }
      if (earlier.any((item) => item.d == current.d)) {
        repeatSameD++;
      } else {
        repeatOtherD++;
      }
      if (earlier.any(
        (item) => item.p == current.p && item.d == current.d,
      )) {
        repeatSamePD++;
      } else {
        repeatOtherPD++;
      }
    }
  }

  report.writeln('\n$label');
  report.writeln(
    'Únicos: ${groups.length} | Grupos repetidos: ${repeated.length} '
    '(entre llamadas: $crossCallGroups) | '
    'Apariciones adicionales: $extra '
    '(dentro de llamadas: $within; entre llamadas: $across).',
  );
  report.writeln(
    'La cuenta entre llamadas registra una nueva aparición por cada '
    'llamada adicional; el detalle incluye TODAS las apariciones.',
  );
  report.writeln(
    'Apariciones en llamadas posteriores: $laterCallOccurrences | '
    'misma P: $repeatSameP; otra P: $repeatOtherP | '
    'misma D: $repeatSameD; otra D: $repeatOtherD | '
    'misma pareja P-D: $repeatSamePD; otra pareja: $repeatOtherPD.',
  );

  if (repeated.isEmpty) {
    report.writeln('Ninguna coincidencia textual.');
    return;
  }

  for (final group in repeated) {
    report.writeln('  ${group.length} veces: "${value(group.first)}"');
    for (final row in group) {
      report.writeln(
        '    ${row.reference} | Q: ${row.q} | R: ${row.r}',
      );
    }
  }
}

void _distribution(IOSink report, String name, Map<String, int> counts) {
  final entries = counts.keys.toList()..sort();
  report.writeln('\nFrecuencias $name (${entries.length} códigos observados):');
  for (final code in entries) {
    report.writeln('  $code: ${counts[code]}');
  }
}

void _nearQuestions(IOSink report, List<_Question> rows) {
  final tokens = [
    for (final row in rows) _lexical(row.q).split(' ').toSet(),
  ];
  var detected = 0;
  report.writeln(
    '\nPREGUNTAS PARECIDAS ENTRE LLAMADAS (candidatas léxicas, '
    'Jaccard de palabras ≥ 0.80; no equivale a similitud semántica):',
  );
  for (var i = 0; i < rows.length; i++) {
    final a = tokens[i];
    if (a.length < 4) continue;
    for (var j = i + 1; j < rows.length; j++) {
      if (rows[i].call == rows[j].call ||
          _key(rows[i].q) == _key(rows[j].q)) {
        continue;
      }
      final b = tokens[j];
      if (b.length < 4) continue;
      final common = a.intersection(b).length;
      if (common == 0) continue;
      final similarity = common / (a.length + b.length - common);
      if (similarity >= 0.80) {
        detected++;
        report.writeln(
          '  ${rows[i].reference} ↔ ${rows[j].reference} '
          '| similitud: ${(100 * similarity).toStringAsFixed(1)}%',
        );
        report.writeln('    A: ${rows[i].q} → ${rows[i].r}');
        report.writeln('    B: ${rows[j].q} → ${rows[j].r}');
      }
    }
  }
  report.writeln('Pares candidatos: $detected.');
}

int _percentile(List<int> values, double fraction) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final requested = (sorted.length * fraction).ceil() - 1;
  final index = requested < 0
      ? 0
      : (requested >= sorted.length ? sorted.length - 1 : requested);
  return sorted[index];
}

/// Auditoría real: Dart selecciona P-D, Luna devuelve Q-R, sin Terra.
Future<void> main(List<String> args) async {
  var samples = 1;
  var seed = 20260929;
  if (args.isNotEmpty) {
    if (args.length != 5 ||
        args[0] != '--luna' ||
        args[1] != '--muestras' ||
        args[3] != '--semilla') {
      stderr.writeln(
        'Uso: verify_generation.dart [--luna --muestras 1-20 --semilla N]',
      );
      exitCode = 64;
      return;
    }
    final n = int.tryParse(args[2]);
    final s = int.tryParse(args[4]);
    if (n == null || n < 1 || n > 20 ||
        s == null || s < 0 || s > 1000000000) {
      stderr.writeln('Muestras 1-20 y semilla 0-1000000000.');
      exitCode = 64;
      return;
    }
    samples = n;
    seed = s;
  }

  final env = Platform.environment;
  final promptLigero = env['AI_APPS_LUNA_PROMPT_LIGERO'] == '1';
  double? inputRate;
  double? outputRate;
  double? cachedRate;
  try {
    inputRate = _rate(env, 'AI_APPS_LUNA_INPUT_USD_PER_M');
    outputRate = _rate(env, 'AI_APPS_LUNA_OUTPUT_USD_PER_M');
    cachedRate = _rate(env, 'AI_APPS_LUNA_CACHED_INPUT_USD_PER_M');
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
    return;
  }

  final client = AiAppsClient(
    endpoint: Uri.parse(env['AI_APPS_AI_URL'] ?? 'http://127.0.0.1:8787'),
    authorization: env['AI_APPS_GAME_TOKEN'] ?? '',
  );

  try {
    final luna = AiQuiz10LunaGenerator(
      client: client,
      model: env['AI_APPS_LUNA_MODEL'] ?? 'gpt-5.6-luna',
      promptLigero: promptLigero,
    );
    // Tarifas indicadas para gpt-5.6-luna, USD por millón de tokens.
    // Los parámetros de run.ps1 / variables de entorno pueden sobrescribirlas.
    // No asignar automáticamente estas tarifas a modelos diferentes.
    if (luna.model == 'gpt-5.6-luna') {
      inputRate ??= 0.20;
      outputRate ??= 1.20;
    }
    final timestamp = DateTime.now().toIso8601String()
        .substring(0, 19)
        .replaceFirst('T', '_')
        .replaceAll(':', '-');
    final variant = promptLigero ? 'Ligero' : 'Completo';
    final path = 'Quiz10_Luna_Q+R_${variant}_$timestamp.txt';
    final report = File(path).openWrite();

    try {
      report.writeln('AUDITORÍA QUIZ10 — LUNA — Q+R');
      report.writeln('Fecha: ${DateTime.now()}');
      report.writeln('Modelo: ${luna.model}');
      report.writeln('Variante de prompt: $variant');
      report.writeln(
        'Prompt literal:\n${promptLigero ? quiz10LunaPromptLigero : quiz10LunaPrompt}',
      );
      report.writeln('Semilla: $seed | Llamadas solicitadas: $samples');
      report.writeln('P: ${quiz10Pivots.length}; D: ${quiz10Dimensions.length}.');
      report.writeln(
        'Tarifas USD/1M tokens: entrada ${inputRate ?? "n/d"}, '
        'salida ${outputRate ?? "n/d"}, '
        'entrada en caché ${cachedRate ?? "tarifa de entrada normal (sin descuento)"}.',
      );
      report.writeln(
        'Los importes son ESTIMACIONES, no facturas. '
        'Se calculan solo cuando existen tokens y tarifas suficientes. '
        'Sin tarifa específica de caché se cobra la entrada en caché '
        'como entrada normal en el cálculo (puede sobreestimar el coste). '
        'Si el proveedor omite el uso de caché se supone 0. '
        'Los tokens de razonamiento ya están incluidos en los de salida.',
      );
      report.writeln(
        'Coincidencia textual = mismo texto ignorando mayúsculas y '
        'espacios repetidos. Los parecidos léxicos son orientativos.',
      );
      report.writeln();

      final clock = Stopwatch()..start();
      final observations = <_Question>[];
      final pivotCounts = <String, int>{};
      final dimensionCounts = <String, int>{};
      final pairCounts = <String, int>{};
      final failures = <String, int>{};
      final durations = <int>[];
      final requestDurations = <int>[];
      final parseDurations = <int>[];
      final latencySamples = <({
        int call,
        int requestMillis,
        int outputTokens,
        int reasoningTokens,
      })>[];
      var reasoningReported = 0;
      var outputsWithReasoning = 0;
      var reasoningInCovered = 0;
      var succeeded = 0;
      var failed = 0;
      var qOutOfRange = 0;
      var rOutOfRange = 0;
      var leakedOwnAnswer = 0;
      var leakedOtherAnswer = 0;
      var totalQWords = 0;
      var totalRWords = 0;
      var tokenCalls = 0;
      var pricedCalls = 0;
      var totalInput = 0;
      var totalOutput = 0;
      var totalCached = 0;
      var totalReasoning = 0;
      var costSum = 0.0;

      for (var i = 0; i < samples; i++) {
        final call = i + 1;
        final watch = Stopwatch()..start();
        final requestWatch = Stopwatch();
        final parseWatch = Stopwatch();
        AiGeneration? raw;
        List<Quiz10LunaRow>? rows;
        Object? failure;

        try {
          final plan = selectQuiz10Pairs(Random(seed + i));
          requestWatch.start();
          raw = await luna.generateResponse(plan);
          requestWatch.stop();
          parseWatch.start();
          rows = parseQuiz10LunaOutput(raw.text, plan);
          parseWatch.stop();
          succeeded++;
          final callObservations = <_Question>[];

          for (final row in rows) {
            final entry = _Question(
              call,
              row.slot.number,
              row.slot.pivot.code,
              row.slot.dimension.code,
              row.question,
              row.correct,
            );
            callObservations.add(entry);
            observations.add(entry);
            pivotCounts.update(entry.p, (n) => n + 1, ifAbsent: () => 1);
            dimensionCounts.update(entry.d, (n) => n + 1, ifAbsent: () => 1);
            pairCounts.update(
              '${entry.p}/${entry.d}',
              (n) => n + 1,
              ifAbsent: () => 1,
            );
            final qWords = _words(entry.q);
            final rWords = _words(entry.r);
            totalQWords += qWords;
            totalRWords += rWords;
            if (qWords < 4 || qWords > 24) {
              qOutOfRange++;
            }
            if (rWords < 1 || rWords > 8) {
              rOutOfRange++;
            }
            if (' ${_lexical(entry.q)} '.contains(' ${_lexical(entry.r)} ')) {
              leakedOwnAnswer++;
              report.writeln(
                'AVISO [${entry.reference}]: Q contiene R literalmente.',
              );
            }
          }

          for (final question in callObservations) {
            for (final answer in callObservations) {
              if (question.position == answer.position) continue;
              final q = ' ${_lexical(question.q)} ';
              final r = ' ${_lexical(answer.r)} ';
              if (q.contains(r)) {
                leakedOtherAnswer++;
                report.writeln(
                  'AVISO [${question.reference}]: Q contiene R '
                  'de ${answer.reference} ("${answer.r}").',
                );
              }
            }
          }
        } catch (error) {
          failure = error;
          failed++;
          failures.update(
            '${error.runtimeType}: $error',
            (n) => n + 1,
            ifAbsent: () => 1,
          );
        } finally {
          requestWatch.stop();
          parseWatch.stop();
          watch.stop();
          durations.add(watch.elapsedMilliseconds);
          requestDurations.add(requestWatch.elapsedMilliseconds);
          parseDurations.add(parseWatch.elapsedMilliseconds);
          final inTokens = _usage(raw?.usage, 'inputTokens');
          final outTokens = _usage(raw?.usage, 'outputTokens');
          final cachedTokens = _usage(raw?.usage, 'cachedInputTokens');
          final reasoningTokens = _usage(raw?.usage, 'reasoningTokens');
          if (reasoningTokens != null &&
              outTokens != null &&
              reasoningTokens <= outTokens) {
            reasoningReported++;
            outputsWithReasoning += outTokens;
            reasoningInCovered += reasoningTokens;
            latencySamples.add((
              call: call,
              requestMillis: requestWatch.elapsedMilliseconds,
              outputTokens: outTokens,
              reasoningTokens: reasoningTokens,
            ));
          }
          if (inTokens != null && outTokens != null) {
            tokenCalls++;
            totalInput += inTokens;
            totalOutput += outTokens;
            if (cachedTokens != null) totalCached += cachedTokens;
            if (reasoningTokens != null) totalReasoning += reasoningTokens;
          }

          final price = _estimatedCost(
            input: inTokens,
            output: outTokens,
            cached: cachedTokens,
            inputRate: inputRate,
            outputRate: outputRate,
            cachedRate: cachedRate,
          );
          if (price != null) {
            pricedCalls++;
            costSum += price;
          }
          final secs = (watch.elapsedMilliseconds / 1000).toStringAsFixed(2);
          final waitSecs =
              (requestWatch.elapsedMilliseconds / 1000).toStringAsFixed(2);
          final visibleTokens = outTokens == null ||
                  reasoningTokens == null ||
                  reasoningTokens > outTokens
              ? null
              : outTokens - reasoningTokens;
          final reasoningPercent = visibleTokens == null || outTokens == 0
              ? 'n/d'
              : (100 * reasoningTokens! / outTokens!).toStringAsFixed(1);
          report.writeln(
            'Llamada $call/$samples | '
            '${failure == null ? "OK" : "ERROR"} | '
            '$secs s | '
            'espera servicio/red: $waitSecs s | '
            'parseo JSON: ${parseWatch.elapsedMilliseconds} ms | '
            'entrada: ${_known(inTokens)} | '
            'salida: ${_known(outTokens)} | '
            'caché: ${_known(cachedTokens)} | '
            'razonamiento: ${_known(reasoningTokens)} '
            '($reasoningPercent% de la salida) | '
            'salida visible estimada: ${_known(visibleTokens)} | '
            'coste estimado: ${_usd(price)}',
          );
          if (failure != null) {
            report.writeln('ERROR: $failure');
            if (raw != null) {
              report.writeln('Salida bruta no válida: ${raw.text}');
            }
          } else {
            for (final row in rows!) {
              report.writeln(
                '${row.slot.number}. ${row.slot.pivot.code} '
                '${row.slot.dimension.code} | '
                '${row.question} → ${row.correct}',
              );
            }
          }
          report.writeln();
          await report.flush();
          stdout.writeln('$call/$samples');
          stdout.writeln('Tiempo: $secs s');
          stdout.writeln('Tokens entrada: ${_known(inTokens)}');
          stdout.writeln('Tokens salida: ${_known(outTokens)}');
          stdout.writeln(
            'Tokens razonamiento: ${_known(reasoningTokens)} '
            '(${reasoningPercent == "n/d" ? "n/d" : "$reasoningPercent%"} de salida)',
          );
          stdout.writeln(
            'Tokens totales: ${inTokens == null || outTokens == null ? "n/d" : inTokens + outTokens}',
          );
          stdout.writeln('Precio: ${_usd(price)}');
          if (call < samples) stdout.writeln();
        }
      }
      clock.stop();

      final qGroups = _groups(observations, (q) => _key(q.q));
      final rGroups = _groups(observations, (q) => _key(q.r));
      final pairGroups = _groups(
        observations,
        (q) => '${_key(q.q)}\u001f${_key(q.r)}',
      );

      report.writeln('\n========== ESTADÍSTICAS FINALES ==========');
      report.writeln('Modelo: ${luna.model} | Semilla: $seed');
      report.writeln('Llamadas: $samples | OK: $succeeded | Fallidas: $failed');
      report.writeln(
        'Q-R válidas: ${observations.length} / ${samples * 10} solicitadas.',
      );
      report.writeln(
        'Duración total: ${(clock.elapsedMilliseconds / 1000).toStringAsFixed(2)} s '
        '| media por llamada: ${(durations.reduce((a, b) => a + b) / durations.length / 1000).toStringAsFixed(2)} s '
        '| mediana: ${(_percentile(durations, 0.5) / 1000).toStringAsFixed(2)} s '
        '| p95: ${(_percentile(durations, 0.95) / 1000).toStringAsFixed(2)} s '
        '| máxima: ${(_percentile(durations, 1) / 1000).toStringAsFixed(2)} s.',
      );
      report.writeln(
        'Tiempo de espera del servicio/red (aproxima la petición al '
        'modelo, pero incluye transporte y servicio local): '
        'media ${(requestDurations.reduce((a, b) => a + b) / requestDurations.length / 1000).toStringAsFixed(2)} s '
        '| mediana ${(_percentile(requestDurations, 0.5) / 1000).toStringAsFixed(2)} s '
        '| p95 ${(_percentile(requestDurations, 0.95) / 1000).toStringAsFixed(2)} s '
        '| máxima ${(_percentile(requestDurations, 1) / 1000).toStringAsFixed(2)} s.',
      );
      report.writeln(
        'Parseo JSON: total ${parseDurations.reduce((a, b) => a + b)} ms '
        '| media ${(parseDurations.reduce((a, b) => a + b) / parseDurations.length).toStringAsFixed(1)} ms.',
      );
      report.writeln(
        'Razonamiento informado: $reasoningReported/$samples llamadas; '
        'tokens de razonamiento / salida de esas llamadas: '
        '${outputsWithReasoning == 0 ? "n/d" : (100 * reasoningInCovered / outputsWithReasoning).toStringAsFixed(1)}%.',
      );
      final slowest = [...latencySamples]
        ..sort((a, b) => b.requestMillis.compareTo(a.requestMillis));
      report.writeln('Cinco esperas más largas con desglose de salida:');
      for (final sample in slowest.take(5)) {
        report.writeln(
          '  L${sample.call}: '
          '${(sample.requestMillis / 1000).toStringAsFixed(2)} s de espera; '
          '${sample.outputTokens} tokens de salida; '
          '${sample.reasoningTokens} de razonamiento '
          '(${(100 * sample.reasoningTokens / sample.outputTokens).toStringAsFixed(1)}%).',
        );
      }
      report.writeln(
        'Consumo observado en $tokenCalls/$samples llamadas '
        '(las demás pueden tener consumo desconocido):',
      );
      report.writeln(
        '  Entrada: $totalInput | Salida: $totalOutput | '
        'Total: ${totalInput + totalOutput} | '
        'Entrada en caché conocida: $totalCached | '
        'Razonamiento conocido (incluido en salida): $totalReasoning.',
      );
      report.writeln(
        '  Coste estimado conocido: ${_usd(pricedCalls == 0 ? null : costSum)} '
        '($pricedCalls/$samples llamadas calculables; '
        'NO equivale al coste total si faltan tarifas o datos de uso).',
      );
      if (inputRate == null || outputRate == null) {
        report.writeln(
          '  Para calcular USD configurar AI_APPS_LUNA_INPUT_USD_PER_M '
          'y AI_APPS_LUNA_OUTPUT_USD_PER_M; si hay caché, '
          'AI_APPS_LUNA_CACHED_INPUT_USD_PER_M.',
        );
      }
      report.writeln(
        'Longitud Q: fuera de 4-24 = $qOutOfRange; '
        'R: fuera de 1-8 = $rOutOfRange.',
      );
      if (observations.isNotEmpty) {
        report.writeln(
          'Media palabras: Q = '
          '${(totalQWords / observations.length).toStringAsFixed(2)}, '
          'R = ${(totalRWords / observations.length).toStringAsFixed(2)}.',
        );
      }
      report.writeln(
        'Posibles filtraciones literales: Q contiene su R = $leakedOwnAnswer; '
        'Q contiene R de otra fila de su llamada = $leakedOtherAnswer '
        '(indicadores léxicos, no semánticos).',
      );
      if (failures.isNotEmpty) {
        report.writeln('\nERRORES POR TIPO:');
        for (final entry in failures.entries) {
          report.writeln('  ${entry.value} × ${entry.key}');
        }
      }

      _distribution(report, 'P', pivotCounts);
      _distribution(report, 'D', dimensionCounts);
      _distribution(report, 'parejas P/D', pairCounts);
      _reportDuplicates(
        report, 'PREGUNTAS Q REPETIDAS (texto normalizado)',
        qGroups, value: (r) => r.q,
      );
      _reportDuplicates(
        report, 'RESPUESTAS R REPETIDAS (texto normalizado)',
        rGroups, value: (r) => r.r,
      );
      _reportDuplicates(
        report, 'PAREJAS Q+R COMPLETAS REPETIDAS',
        pairGroups, value: (r) => '${r.q} → ${r.r}',
      );

      var questionsDifferentAnswers = 0;
      report.writeln('\nMISMA Q CON RESPUESTAS DISTINTAS:');
      for (final group in qGroups.values) {
        if (group.map((r) => _key(r.r)).toSet().length < 2) continue;
        questionsDifferentAnswers++;
        report.writeln('  Q: "${group.first.q}"');
        for (final row in group) {
          report.writeln('    ${row.reference}: ${row.r}');
        }
      }
      report.writeln('Grupos: $questionsDifferentAnswers.');

      var answersDifferentQuestions = 0;
      report.writeln('\nMISMA R PARA PREGUNTAS DISTINTAS:');
      for (final group in rGroups.values) {
        if (group.map((r) => _key(r.q)).toSet().length < 2) continue;
        answersDifferentQuestions++;
        report.writeln('  R: "${group.first.r}"');
        for (final row in group) {
          report.writeln('    ${row.reference}: ${row.q}');
        }
      }
      report.writeln('Grupos: $answersDifferentQuestions.');

      _nearQuestions(report, observations);
      report.writeln(
        '\nNo evaluado automáticamente: exactitud factual, '
        'equivalencias semánticas, alias de respuestas y orden '
        'real de dificultad. Requieren revisión semántica.',
      );

      await report.flush();
      // El resumen completo y la ruta quedan exclusivamente en el .txt.
      if (failed > 0) exitCode = 1;
    } finally {
      await report.close();
    }
  } catch (error) {
    stderr.writeln('Falló la auditoría Q-R de Luna: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}
