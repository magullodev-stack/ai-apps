import 'dart:io';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:quizai/modes/quiz10/quiz10_DART_Pi+Di.dart';
import 'package:quizai/modes/quiz10/quiz10_LUNA_Prompt.dart';

String _key(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

int? _usage(Map<String, dynamic>? usage, String key) {
  final value = usage?[key];
  return value is int && value >= 0 ? value : null;
}

String _known(int? count) => count?.toString() ?? 'n/d';

String _id(String text) {
  var hash = 0x811c9dc5;
  for (final char in text.runes) {
    hash = ((hash ^ char) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

double? _rate(Map<String, String> env, String key) {
  final raw = env[key]?.trim();
  if (raw == null || raw.isEmpty) return null;
  final value = double.tryParse(raw.replaceAll(',', '.'));
  if (value == null || !value.isFinite || value < 0) {
    throw FormatException('Tarifa inválida para $key: $raw');
  }
  return value;
}

double? _cost({
  required int? input,
  required int? output,
  required int? cached,
  required double? inputRate,
  required double? outputRate,
  required double? cachedRate,
}) {
  if (input == null ||
      output == null ||
      inputRate == null ||
      outputRate == null ||
      (cached != null && cached > input)) {
    return null;
  }
  final c = cached ?? 0;
  return ((input - c) * inputRate +
          c * (cachedRate ?? inputRate) +
          output * outputRate) /
      1000000;
}

String _usd(double? value) =>
    value == null ? 'n/d' : 'USD ${value.toStringAsFixed(6)}';

int _percentile(List<int> values, double fraction) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final requested = (sorted.length * fraction).ceil() - 1;
  final index = requested < 0
      ? 0
      : (requested >= sorted.length ? sorted.length - 1 : requested);
  return sorted[index];
}

void _distribution(IOSink report, String name, Map<String, int> counts) {
  final keys = counts.keys.toList()..sort();
  report.writeln('\n$name (${keys.length} valores):');
  for (final key in keys) {
    report.writeln('  $key: ${counts[key]}');
  }
}

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
    if (n == null ||
        n < 1 ||
        n > 20 ||
        s == null ||
        s < 0 ||
        s > 1000000000) {
      stderr.writeln('Muestras 1-20 y semilla 0-1000000000.');
      exitCode = 64;
      return;
    }
    samples = n;
    seed = s;
  }

  final env = Platform.environment;
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
    );

    if (luna.model == 'gpt-5.6-luna') {
      inputRate ??= 0.20;
      outputRate ??= 1.20;
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceFirst('T', '_')
        .replaceAll(':', '-');
    final modelLabel =
        luna.model.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');
    final promptId = _id(quiz10LunaPrompt);
    final catalogId = _id([
      for (final pivot in quiz10Pivots) '${pivot.code}:${pivot.name}',
      for (final dimension in quiz10Dimensions)
        '${dimension.code}:${dimension.instruction}',
    ].join('\n'));

    final path =
        'Quiz10_${modelLabel}_P-D_F+Q+R+A_${samples}T_${samples * 10}L_s${seed}_prompt-${promptId}_cat-${catalogId}_$timestamp.txt';
    final report = File(path).openWrite();

    try {
      report.writeln('AUDITORÍA QUIZ10 — LUNA — P-D → F,Q,R,A');
      report.writeln('Fecha: ${DateTime.now()}');
      report.writeln('Modelo: ${luna.model}');
      report.writeln(
        'Ejecución: cada test = 10 llamadas Luna simultáneas; '
        'los tests se ejecutan secuencialmente.',
      );
      report.writeln(
        'H: histórico factual por cruce P×D; cada llamada recibe los pares (F,R) '
        'previos de ese cruce y cada fila estructuralmente recibida avanza H.',
      );
      report.writeln(
        'La auditoría no rechaza filas por contenido: registra literalmente '
        'lo que devuelve Luna y marca las incidencias observables.',
      );
      report.writeln('Huella del prompt: $promptId');
      report.writeln('Huella del catálogo: $catalogId');
      report.writeln('Prompt oficial con variables:\n$quiz10LunaPrompt');
      report.writeln(
        'Semilla: $seed | Tests: $samples | '
        'Llamadas Luna: ${samples * 10}.',
      );
      report.writeln(
        'Tarifas USD/1M: entrada ${inputRate ?? "n/d"}, '
        'salida ${outputRate ?? "n/d"}, '
        'caché ${cachedRate ?? "entrada normal"}.',
      );
      report.writeln();

      final totalWatch = Stopwatch()..start();
      final durations = <int>[];
      final pCounts = <String, int>{};
      final dCounts = <String, int>{};
      final qCounts = <String, int>{};
      final rCounts = <String, int>{};
      final frByPivotDimensionCounts = <String, int>{};
      final failures = <String, int>{};
      final auditIssues = <String, int>{};

      var succeeded = 0;
      var failed = 0;
      var auditedRows = 0;
      var rowsWithIssues = 0;
      var totalInput = 0;
      var totalOutput = 0;
      var totalCached = 0;
      var totalReasoning = 0;
      var usageTests = 0;
      var usageCalls = 0;
      var pricedTests = 0;
      var totalCost = 0.0;

      void recordRows(int test, Iterable<Quiz10LunaRow> batchRows) {
        for (final row in batchRows) {
          auditedRows++;
          final p = row.slot.pivot.code;
          final d = row.slot.dimension.code;
          final pairKey =
              '$p\u001f$d\u001f${_key(row.fact)}\u001f${_key(row.correct)}';
          final issues = <String>[];

          if (_key(row.returnedPivot) != _key(row.slot.pivot.name)) {
            issues.add(
              'P devuelta "${row.returnedPivot}" != ${row.slot.pivot.name}',
            );
          }
          if (_key(row.returnedDimension) != _key(row.slot.dimension.code)) {
            issues.add(
              'D devuelta "${row.returnedDimension}" != ${row.slot.dimension.code}',
            );
          }
          if (row.fact.trim().isEmpty) issues.add('F vacía');
          if (row.question.trim().isEmpty) issues.add('Q vacía');
          if (row.correct.trim().isEmpty) issues.add('R vacía');

          final correct = row.correct.trim();
          if (correct.isNotEmpty && row.question.contains(correct)) {
            issues.add('Q contiene literalmente R');
          }

          if (row.distractors.length != 3) {
            issues.add(
              'A contiene ${row.distractors.length} elementos; se esperaban 3',
            );
          }
          final normalizedDistractors =
              row.distractors.map(_key).toList(growable: false);
          if (normalizedDistractors.toSet().length !=
              normalizedDistractors.length) {
            issues.add('A contiene distractores duplicados');
          }
          if (_key(row.correct).isNotEmpty &&
              normalizedDistractors.contains(_key(row.correct))) {
            issues.add('A contiene la propia R');
          }
          if ((frByPivotDimensionCounts[pairKey] ?? 0) > 0) {
            issues.add('H ya contenía el par factual (F,R)');
          }

          pCounts.update(p, (n) => n + 1, ifAbsent: () => 1);
          dCounts.update(d, (n) => n + 1, ifAbsent: () => 1);
          qCounts.update(_key(row.question), (n) => n + 1, ifAbsent: () => 1);
          rCounts.update(_key(row.correct), (n) => n + 1, ifAbsent: () => 1);
          frByPivotDimensionCounts.update(
            pairKey,
            (n) => n + 1,
            ifAbsent: () => 1,
          );

          report.writeln(
            '${row.slot.number}. $p $d | '
            'F: ${row.fact} | Q: ${row.question} | R: ${row.correct} | '
            'A: ${row.distractors.join(" / ")}',
          );

          if (issues.isNotEmpty) {
            rowsWithIssues++;
            for (final issue in issues) {
              auditIssues.update(issue, (n) => n + 1, ifAbsent: () => 1);
            }
            report.writeln('  INCIDENCIAS: ${issues.join(" | ")}');
            report.writeln('  RAW: ${row.rawText}');
            stdout.writeln(
              'T$test/F${row.slot.number} | $p $d | '
              'INCIDENCIAS: ${issues.join(" | ")}',
            );
          }
        }
      }

      for (var i = 0; i < samples; i++) {
        final test = i + 1;
        final plan = selectQuiz10Pairs(Random(seed + i));
        final watch = Stopwatch()..start();
        AiGeneration? raw;
        List<Quiz10LunaRow>? rows;
        Object? failure;
        Map<String, dynamic>? failureUsage;
        var completedCalls = 0;
        var rowFailures = <Quiz10LunaFailure>[];

        try {
          raw = await luna.generateResponse(plan);
          rows = parseQuiz10LunaOutput(raw.text, plan);
          succeeded++;

          report.writeln(
            'TEST $test/$samples — 10 llamadas simultáneas — '
            '${(watch.elapsedMilliseconds / 1000).toStringAsFixed(2)} s',
          );

          recordRows(test, rows);
        } on Quiz10LunaPackException catch (error) {
          failure = error;
          rows = error.rows;
          if (rows.isNotEmpty) {
            report.writeln(
              'TEST $test/$samples — PACK INCOMPLETO — '
              '${(watch.elapsedMilliseconds / 1000).toStringAsFixed(2)} s',
            );
            recordRows(test, rows);
          }
          failed++;
          failures.update(
            '${error.runtimeType}: $error',
            (n) => n + 1,
            ifAbsent: () => 1,
          );
          failureUsage = error.usage;
          completedCalls = error.completedCalls;
          rowFailures = error.failures;
        } catch (error) {
          failure = error;
          failed++;
          failures.update(
            '${error.runtimeType}: $error',
            (n) => n + 1,
            ifAbsent: () => 1,
          );
        } finally {
          watch.stop();
          durations.add(watch.elapsedMilliseconds);

          final observedUsage = raw?.usage ?? failureUsage;
          final input = _usage(observedUsage, 'inputTokens');
          final output = _usage(observedUsage, 'outputTokens');
          final cached = _usage(observedUsage, 'cachedInputTokens');
          final reasoning = _usage(observedUsage, 'reasoningTokens');

          if (input != null && output != null) {
            usageTests++;
            usageCalls += raw != null ? 10 : completedCalls;
            totalInput += input;
            totalOutput += output;
            totalCached += cached ?? 0;
            totalReasoning += reasoning ?? 0;
          }

          final price = _cost(
            input: input,
            output: output,
            cached: cached,
            inputRate: inputRate,
            outputRate: outputRate,
            cachedRate: cachedRate,
          );
          if (price != null) {
            pricedTests++;
            totalCost += price;
          }

          final seconds =
              (watch.elapsedMilliseconds / 1000).toStringAsFixed(2);
          stdout.writeln(
            'Test $test/$samples — 10 llamadas Luna laterales',
          );
          stdout.writeln('Tiempo: $seconds s');
          stdout.writeln('Tokens entrada: ${_known(input)}');
          stdout.writeln('Tokens salida: ${_known(output)}');
          final reasoningPercent =
              output != null && output > 0 && reasoning != null
              ? reasoning * 100 / output
              : null;
          final visibleOutput =
              output != null && reasoning != null ? output - reasoning : null;
          stdout.writeln(
            'Tokens razonamiento: ${_known(reasoning)}'
            '${reasoningPercent == null ? "" : " (${reasoningPercent.toStringAsFixed(1)}% de salida)"}',
          );
          stdout.writeln('Salida visible estimada: ${_known(visibleOutput)}');
          stdout.writeln('Precio: ${_usd(price)}');
          if (failure != null) {
            stdout.writeln('ERROR: $failure');
            report.writeln('TEST $test/$samples — ERROR — $seconds s');
            report.writeln('$failure');
            if (rowFailures.isNotEmpty) {
              for (final item in rowFailures) {
                final slot = item.slot;
                report.writeln('T$test/F${slot.number}');
                report.writeln('P = ${slot.pivot.code} (${slot.pivot.name})');
                report.writeln('D = ${slot.dimension.code}');
                report.writeln('Etapa = ${item.stage}');
                report.writeln('causa = ${item.cause}');
                if (item.rawText != null) {
                  report.writeln('RAW = ${item.rawText}');
                }
                stdout.writeln(
                  'T$test/F${slot.number} | '
                  '${slot.pivot.code} ${slot.dimension.code} | '
                  '${item.stage}: ${item.cause}',
                );
              }
            }
          }
          report.writeln();
          await report.flush();
        }
      }

      totalWatch.stop();

      final repeatedQ =
          qCounts.values.where((count) => count > 1).length;
      final repeatedR =
          rCounts.values.where((count) => count > 1).length;
      final repeatedFactAnswerForSamePivotDimension =
          frByPivotDimensionCounts.values.where((count) => count > 1).length;

      report.writeln('========== ESTADÍSTICAS FINALES ==========');
      report.writeln(
        'Tests: $samples | Packs completos: $succeeded | '
        'Packs incompletos: $failed | Ítems solicitados: ${samples * 10} | '
        'Filas observadas: $auditedRows | Filas con incidencias: $rowsWithIssues.',
      );
      report.writeln(
        'Duración total: '
        '${(totalWatch.elapsedMilliseconds / 1000).toStringAsFixed(2)} s | '
        'media/test: '
        '${(durations.reduce((a, b) => a + b) / durations.length / 1000).toStringAsFixed(2)} s | '
        'mediana: ${(_percentile(durations, 0.5) / 1000).toStringAsFixed(2)} s | '
        'p95: ${(_percentile(durations, 0.95) / 1000).toStringAsFixed(2)} s | '
        'máxima: ${(_percentile(durations, 1) / 1000).toStringAsFixed(2)} s.',
      );
      final aggregateReasoningPercent =
          totalOutput > 0 ? totalReasoning * 100 / totalOutput : 0.0;
      final aggregateVisibleOutput = totalOutput - totalReasoning;
      report.writeln(
        'Consumo agregado: entrada $totalInput | salida $totalOutput | '
        'total ${totalInput + totalOutput} | caché $totalCached | '
        'razonamiento $totalReasoning '
        '(${aggregateReasoningPercent.toStringAsFixed(1)}% de salida) | '
        'salida visible estimada $aggregateVisibleOutput | '
        'uso recuperado en $usageTests/$samples packs, $usageCalls llamadas.',
      );
      report.writeln(
        'Coste estimado: ${_usd(pricedTests == 0 ? null : totalCost)} '
        '($pricedTests/$samples tests calculables).',
      );
      report.writeln(
        'Duplicados exactos: grupos Q=$repeatedQ | grupos R=$repeatedR | '
        'pares (F,R) repetidos dentro del mismo P×D='
        '$repeatedFactAnswerForSamePivotDimension.',
      );
      report.writeln(
        'La última cifra se observa, no se bloquea: H se envía a Luna, '
        'pero Dart no rechaza una fila si Luna reutiliza un par (F,R).',
      );

      _distribution(report, 'Frecuencias P', pCounts);
      _distribution(report, 'Frecuencias D', dCounts);

      if (auditIssues.isNotEmpty) {
        report.writeln('\nINCIDENCIAS DE CONTENIDO:');
        for (final entry in auditIssues.entries) {
          report.writeln('  ${entry.value} × ${entry.key}');
        }
      }

      if (failures.isNotEmpty) {
        report.writeln('\nERRORES DE LLAMADA/ESTRUCTURA:');
        for (final entry in failures.entries) {
          report.writeln('  ${entry.value} × ${entry.key}');
        }
      }

      report.writeln(
        '\nNo evaluado automáticamente: exactitud factual, '
        'equivalencia semántica de F/H y plausibilidad factual de distractores.',
      );

      await report.flush();
      if (failed > 0) exitCode = 1;
    } finally {
      await report.close();
    }
  } catch (error) {
    stderr.writeln('Falló la auditoría de Luna: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}
