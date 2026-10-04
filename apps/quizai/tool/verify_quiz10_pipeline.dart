import 'dart:io';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:quizai/modes/quiz10/Quiz10_PROMPT_G.dart';
import 'package:quizai/modes/quiz10/Quiz10_PROMPT_R.dart';
import 'package:quizai/modes/quiz10/Quiz10_PROMPT_S.dart';
import 'package:quizai/modes/quiz10/quiz10_pipeline.dart';

String _key(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

int? _usage(Map<String, dynamic>? usage, String key) {
  final value = usage?[key];
  return value is int && value >= 0 ? value : null;
}

String _known(int? value) => value?.toString() ?? 'n/d';

double? _cost(
  Map<String, dynamic>? usage, {
  required double? inputRate,
  required double? outputRate,
}) {
  final input = _usage(usage, 'inputTokens');
  final output = _usage(usage, 'outputTokens');
  if (input == null ||
      output == null ||
      inputRate == null ||
      outputRate == null) {
    return null;
  }
  return (input * inputRate + output * outputRate) / 1000000;
}

String _usd(double? value) =>
    value == null ? 'n/d' : 'USD ${value.toStringAsFixed(6)}';

int _percentile(List<int> values, double fraction) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final requested = (sorted.length * fraction).ceil() - 1;
  final index = requested.clamp(0, sorted.length - 1).toInt();
  return sorted[index];
}

String _modelLabel(String model) =>
    model.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');

({double? input, double? output}) _rates(String model) {
  return switch (model) {
    'gpt-5.6-luna' => (input: 0.20, output: 1.20),
    'gpt-5.6-terra' => (input: 2.0, output: 12.0),
    _ => (input: null, output: null),
  };
}

String _originalReviewValue(
  Quiz10LunaRow row,
  String field,
) {
  return switch (field) {
    'Q' => row.question,
    'R' => row.correct,
    'd1' => row.distractors[0],
    'd2' => row.distractors[1],
    'd3' => row.distractors[2],
    _ => throw ArgumentError.value(field, 'field'),
  };
}

String _formatPatch(
  Quiz10ReviewPatch patch,
  List<Quiz10LunaRow> rows,
) {
  final buffer = StringBuffer();
  final row = rows[patch.number - 1];

  for (final change in patch.changes) {
    buffer.writeln('${patch.number}.${change.field}');
    buffer.writeln(
      '  G: ${_originalReviewValue(row, change.field)}',
    );
    buffer.writeln('  R: ${change.value}');
  }

  return buffer.toString().trimRight();
}


String _cell(String value, int width) {
  if (value.length >= width) return value.substring(0, width);
  return value.padRight(width);
}

String _rule(int width) => List.filled(width, '─').join();

void _printMetricsTable(
  List<(String, String, String, String, String)> rows,
) {
  const labelWidth = 20;
  const valueWidth = 14;
  final top =
      '┌${_rule(labelWidth)}┬${_rule(valueWidth)}┬${_rule(valueWidth)}┬${_rule(valueWidth)}┬${_rule(valueWidth)}┐';
  final mid =
      '├${_rule(labelWidth)}┼${_rule(valueWidth)}┼${_rule(valueWidth)}┼${_rule(valueWidth)}┼${_rule(valueWidth)}┤';
  final bottom =
      '└${_rule(labelWidth)}┴${_rule(valueWidth)}┴${_rule(valueWidth)}┴${_rule(valueWidth)}┴${_rule(valueWidth)}┘';

  stdout.writeln(top);
  stdout.writeln(
    '│${_cell('', labelWidth)}│${_cell('G', valueWidth)}│'
    '${_cell('R', valueWidth)}│${_cell('S', valueWidth)}│'
    '${_cell('TOTAL', valueWidth)}│',
  );
  stdout.writeln(mid);
  for (final row in rows) {
    stdout.writeln(
      '│${_cell(row.$1, labelWidth)}│${_cell(row.$2, valueWidth)}│'
      '${_cell(row.$3, valueWidth)}│${_cell(row.$4, valueWidth)}│'
      '${_cell(row.$5, valueWidth)}│',
    );
  }
  stdout.writeln(bottom);
}
void _printResultTable(List<(String, String)> rows) {
  const labelWidth = 28;
  const valueWidth = 14;
  final top = '┌${_rule(labelWidth)}┬${_rule(valueWidth)}┐';
  final mid = '├${_rule(labelWidth)}┼${_rule(valueWidth)}┤';
  final bottom = '└${_rule(labelWidth)}┴${_rule(valueWidth)}┘';

  stdout.writeln(top);
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    stdout.writeln(
      '│${_cell(row.$1, labelWidth)}│${_cell(row.$2, valueWidth)}│',
    );
    if (i == 0) stdout.writeln(mid);
  }
  stdout.writeln(bottom);
}

String _tokens(int? value) => value == null ? 'n/d' : value.toString();

String _reasoning(int reasoning, int output) =>
    output <= 0 ? 'n/d' : '${(reasoning * 100 / output).toStringAsFixed(1)}%';

String _seconds(double value) => '${value.toStringAsFixed(2)} s';

Future<void> main(List<String> args) async {
  var samples = 1;
  var seed = 20260929;

  if (args.isNotEmpty) {
    if (args.length != 5 ||
        args[0] != '--quiz10' ||
        args[1] != '--muestras' ||
        args[3] != '--semilla') {
      stderr.writeln(
        'Uso: verify_quiz10_pipeline.dart '
        '[--quiz10 --muestras 1-200 --semilla N]',
      );
      exitCode = 64;
      return;
    }

    final parsedSamples = int.tryParse(args[2]);
    final parsedSeed = int.tryParse(args[4]);
    if (parsedSamples == null ||
        parsedSamples < 1 ||
        parsedSamples > 200 ||
        parsedSeed == null ||
        parsedSeed < 0 ||
        parsedSeed > 1000000000) {
      stderr.writeln('Muestras 1-200 y semilla 0-1000000000.');
      exitCode = 64;
      return;
    }

    samples = parsedSamples;
    seed = parsedSeed;
  }

  final env = Platform.environment;
  final client = AiAppsClient(
    endpoint: Uri.parse(env['AI_APPS_AI_URL'] ?? 'http://127.0.0.1:8787'),
    authorization: env['AI_APPS_GAME_TOKEN'] ?? '',
  );

  final reviewModel =
      env['AI_APPS_QUIZ10_REVIEW_MODEL'] ?? 'gpt-5.6-luna';
  final pipeline = AiQuiz10Pipeline(
    client: client,
    lunaModel: env['AI_APPS_LUNA_MODEL'] ?? 'gpt-5.6-luna',
    reviewerModel: reviewModel,
    sorterModel: env['AI_APPS_QUIZ10_SORT_MODEL'] ?? reviewModel,
  );

  final lunaRates = _rates(pipeline.luna.model);
  final reviewRates = _rates(pipeline.reviewer.model);
  final sortRates = _rates(pipeline.sorter.model);

  final timestamp = DateTime.now()
      .toIso8601String()
      .substring(0, 19)
      .replaceFirst('T', '_')
      .replaceAll(':', '-');

  final path =
      'Quiz10_${_modelLabel(pipeline.luna.model)}+'
      '${_modelLabel(pipeline.reviewer.model)}+'
      '${_modelLabel(pipeline.sorter.model)}_PIPELINE_'
      '${samples}T_${samples * 10}G_${samples * 10}R_${samples}S_'
      's${seed}_$timestamp.txt';

  final report = File(path).openWrite();

  final totalDurations = <int>[];
  final lunaDurations = <int>[];
  final reviewDurations = <int>[];
  final sortDurations = <int>[];

  var completeTests = 0;
  var failedTests = 0;
  var correctedTests = 0;
  var correctedQuestions = 0;
  var correctedFields = 0;
  var questionFieldCorrections = 0;
  var answerFieldCorrections = 0;
  var distractorFieldCorrections = 0;
  var finalRowsWithIssues = 0;

  var lunaInput = 0;
  var lunaOutput = 0;
  var lunaReasoning = 0;
  var reviewInput = 0;
  var reviewOutput = 0;
  var reviewReasoning = 0;
  var sortInput = 0;
  var sortOutput = 0;
  var sortReasoning = 0;
  var lunaUsageTests = 0;
  var reviewUsageTests = 0;
  var sortUsageTests = 0;

  var totalCost = 0.0;
  var lunaCostTotal = 0.0;
  var reviewerCostTotal = 0.0;
  var sorterCostTotal = 0.0;
  var completePackCostTotal = 0.0;
  var fullyPricedPacks = 0;
  var lunaPricedTests = 0;
  var reviewerPricedTests = 0;
  var sorterPricedTests = 0;
  var pricedStages = 0;

  try {
    report.writeln('AUDITORÍA QUIZ10 — PIPELINE G → R → S → DART');
    report.writeln('Fecha: ${DateTime.now()}');
    report.writeln('G: ${pipeline.luna.model}');
    report.writeln('R: ${pipeline.reviewer.model}');
    report.writeln('S: ${pipeline.sorter.model}');
    report.writeln(
      'Ejecución por test: 10 llamadas G simultáneas, '
      '10 revisiones R simultáneas, 1 ordenación global S, '
      'aplicación de orden y shuffle en Dart.',
    );
    report.writeln(
      'Semilla: $seed | Tests: $samples | '
      'Llamadas G: ${samples * 10} | '
      'Llamadas R: ${samples * 10} | '
      'Llamadas S: $samples.',
    );
    report.writeln();

    for (var i = 0; i < samples; i++) {
      final test = i + 1;
      final totalWatch = Stopwatch()..start();

      try {
        final result = await pipeline.generateDetailed(
          planRandom: Random(seed + i),
          optionRandom: Random(seed + 100000 + i),
        );
        totalWatch.stop();

        completeTests++;
        totalDurations.add(totalWatch.elapsedMilliseconds);
        lunaDurations.add(result.lunaDuration.inMilliseconds);
        reviewDurations.add(result.reviewDuration.inMilliseconds);
        sortDurations.add(result.sortDuration.inMilliseconds);

        final lunaUsage = result.lunaGeneration.usage;
        final reviewerUsage = result.review.usage;
        final sorterUsage = result.sort.usage;

        final li = _usage(lunaUsage, 'inputTokens');
        final lo = _usage(lunaUsage, 'outputTokens');
        final lr = _usage(lunaUsage, 'reasoningTokens');
        if (li != null && lo != null) {
          lunaUsageTests++;
          lunaInput += li;
          lunaOutput += lo;
          lunaReasoning += lr ?? 0;
        }

        final ri = _usage(reviewerUsage, 'inputTokens');
        final ro = _usage(reviewerUsage, 'outputTokens');
        final rr = _usage(reviewerUsage, 'reasoningTokens');
        if (ri != null && ro != null) {
          reviewUsageTests++;
          reviewInput += ri;
          reviewOutput += ro;
          reviewReasoning += rr ?? 0;
        }

        final si = _usage(sorterUsage, 'inputTokens');
        final so = _usage(sorterUsage, 'outputTokens');
        final sr = _usage(sorterUsage, 'reasoningTokens');
        if (si != null && so != null) {
          sortUsageTests++;
          sortInput += si;
          sortOutput += so;
          sortReasoning += sr ?? 0;
        }

        final lunaCost = _cost(
          lunaUsage,
          inputRate: lunaRates.input,
          outputRate: lunaRates.output,
        );
        final reviewerCost = _cost(
          reviewerUsage,
          inputRate: reviewRates.input,
          outputRate: reviewRates.output,
        );
        final sorterCost = _cost(
          sorterUsage,
          inputRate: sortRates.input,
          outputRate: sortRates.output,
        );

        if (lunaCost != null) {
          totalCost += lunaCost;
          lunaCostTotal += lunaCost;
          lunaPricedTests++;
          pricedStages++;
        }
        if (reviewerCost != null) {
          totalCost += reviewerCost;
          reviewerCostTotal += reviewerCost;
          reviewerPricedTests++;
          pricedStages++;
        }
        if (sorterCost != null) {
          totalCost += sorterCost;
          sorterCostTotal += sorterCost;
          sorterPricedTests++;
          pricedStages++;
        }

        final packCost =
            lunaCost != null && reviewerCost != null && sorterCost != null
                ? lunaCost + reviewerCost + sorterCost
                : null;
        if (packCost != null) {
          completePackCostTotal += packCost;
          fullyPricedPacks++;
        }

        if (result.review.patches.isNotEmpty) correctedTests++;
        correctedQuestions += result.review.patches.length;
        correctedFields += result.review.patches.fold<int>(
          0,
          (sum, patch) => sum + patch.changes.length,
        );

        final questionCorrections = result.review.patches.fold<int>(
          0,
          (sum, patch) =>
              sum + patch.changes.where((change) => change.field == 'Q').length,
        );
        final answerCorrections = result.review.patches.fold<int>(
          0,
          (sum, patch) =>
              sum + patch.changes.where((change) => change.field == 'R').length,
        );
        final distractorCorrections = result.review.patches.fold<int>(
          0,
          (sum, patch) => sum +
              patch.changes
                  .where(
                    (change) =>
                        change.field == 'd1' ||
                        change.field == 'd2' ||
                        change.field == 'd3',
                  )
                  .length,
        );

        questionFieldCorrections += questionCorrections;
        answerFieldCorrections += answerCorrections;
        distractorFieldCorrections += distractorCorrections;

        final packInputTokens =
            li != null && ri != null && si != null ? li + ri + si : null;
        final packOutputTokens =
            lo != null && ro != null && so != null ? lo + ro + so : null;

        final generationReasoningPercent = lo != null && lo > 0 && lr != null
            ? '${(lr * 100 / lo).toStringAsFixed(1)}%'
            : 'n/d';
        final reviewReasoningPercent = ro != null && ro > 0 && rr != null
            ? '${(rr * 100 / ro).toStringAsFixed(1)}%'
            : 'n/d';
        final sortReasoningPercent = so != null && so > 0 && sr != null
            ? '${(sr * 100 / so).toStringAsFixed(1)}%'
            : 'n/d';

        report.writeln(
          '========== TEST $test/$samples — '
          '${(totalWatch.elapsedMilliseconds / 1000).toStringAsFixed(2)} s '
          '(G ${(result.lunaDuration.inMilliseconds / 1000).toStringAsFixed(2)} s '
          '+ R ${(result.reviewDuration.inMilliseconds / 1000).toStringAsFixed(2)} s '
          '+ S ${(result.sortDuration.inMilliseconds / 1000).toStringAsFixed(2)} s) ==========',
        );

        report.writeln('\n--- SALIDA G ---');
        for (var rowIndex = 0; rowIndex < result.lunaRows.length; rowIndex++) {
          final row = result.lunaRows[rowIndex];
          report.writeln(
            '${rowIndex + 1}. ${row.slot.pivot.code} ${row.slot.dimension.code} | '
            'F: ${row.fact} | '
            'Q: ${row.question} | '
            'O: ${[
              for (var option = 0; option < row.options.length; option++)
                "${option + 1}=${row.options[option]}",
            ].join(" / ")} | C: ${row.correctPosition} | R: ${row.correct}',
          );
        }

        report.writeln('\n--- ENTRADAS R (10 LLAMADAS PARALELAS) ---');
        for (final call in result.review.calls) {
          report.writeln('\n[R${call.number}]');
          report.writeln(call.input);
        }

        report.writeln('\n--- SALIDAS R RAW ---');
        for (final call in result.review.calls) {
          report.writeln('R${call.number}: ${call.rawText}');
        }

        report.writeln('\n--- CORRECCIONES R ---');
        if (result.review.patches.isEmpty) {
          report.writeln('(ninguna)');
        } else {
          for (final patch in result.review.patches) {
            report.writeln(_formatPatch(patch, result.lunaRows));
          }
        }

        report.writeln('\n--- TEST TRAS R ---');
        for (var itemIndex = 0;
            itemIndex < result.correctedItems.length;
            itemIndex++) {
          final item = result.correctedItems[itemIndex];
          report.writeln(
            '${itemIndex + 1}. Q: ${item.question} | R: ${item.correct} | '
            'd1: ${item.distractors[0]} | '
            'd2: ${item.distractors[1]} | '
            'd3: ${item.distractors[2]}',
          );
        }

        report.writeln('\n--- ENTRADA S ---');
        report.writeln(result.sortInput);

        report.writeln('\n--- SALIDA S RAW ---');
        report.writeln(result.sort.rawText);

        report.writeln('\n--- ORDEN S ---');
        report.writeln(result.sort.order);

        report.writeln('\n--- TEST TRAS R Y S ---');
        for (var finalIndex = 0;
            finalIndex < result.reviewedItems.length;
            finalIndex++) {
          final item = result.reviewedItems[finalIndex];
          final original = item.source.slot.number;
          report.writeln(
            '${finalIndex + 1}. [original $original] '
            'Q: ${item.question} | R: ${item.correct} | '
            'd1: ${item.distractors[0]} | '
            'd2: ${item.distractors[1]} | '
            'd3: ${item.distractors[2]}',
          );

          final normalized = [
            _key(item.correct),
            ...item.distractors.map(_key),
          ];
          if (normalized.toSet().length != 4 ||
              item.question.contains(item.correct)) {
            finalRowsWithIssues++;
            report.writeln('  INCIDENCIA FINAL ESTRUCTURAL/LOCAL');
          }
        }

        report.writeln('\n--- OPCIONES FINALES TRAS SHUFFLE DART ---');
        for (var finalIndex = 0;
            finalIndex < result.questions.length;
            finalIndex++) {
          final question = result.questions[finalIndex];
          report.writeln(
            '${finalIndex + 1}. ${question.question} | '
            'R: ${question.correct} | '
            'O: ${question.options.join(" / ")}',
          );
        }

        report.writeln(
          '\nUSO TEST $test | '
          'G: entrada ${_known(li)}, salida ${_known(lo)}, '
          'razonamiento ${_known(lr)}, coste ${_usd(lunaCost)} | '
          'R: entrada ${_known(ri)}, salida ${_known(ro)}, '
          'razonamiento ${_known(rr)}, coste ${_usd(reviewerCost)} | '
          'S: entrada ${_known(si)}, salida ${_known(so)}, '
          'razonamiento ${_known(sr)}, coste ${_usd(sorterCost)}',
        );
        report.writeln();
        await report.flush();

        final generationSeconds =
            result.lunaDuration.inMilliseconds / 1000;
        final reviewSeconds =
            result.reviewDuration.inMilliseconds / 1000;
        final sortSeconds =
            result.sortDuration.inMilliseconds / 1000;
        final pipelineSeconds =
            generationSeconds + reviewSeconds + sortSeconds;

        final totalReasoningPercent =
            lo != null &&
                    ro != null &&
                    so != null &&
                    lr != null &&
                    rr != null &&
                    sr != null &&
                    lo + ro + so > 0
                ? '${((lr + rr + sr) * 100 / (lo + ro + so)).toStringAsFixed(1)}%'
                : 'n/d';

        final correctionFields =
            questionCorrections + answerCorrections + distractorCorrections;
        final correctionLabel = result.review.patches.isEmpty
            ? '—'
            : 'Q$questionCorrections R$answerCorrections D$distractorCorrections';

        stdout.writeln();
        stdout.writeln('TEST $test/$samples');
        _printMetricsTable([
          (
            'Tiempo',
            _seconds(generationSeconds),
            _seconds(reviewSeconds),
            _seconds(sortSeconds),
            _seconds(pipelineSeconds),
          ),
          (
            'Tokens entrada',
            _tokens(li),
            _tokens(ri),
            _tokens(si),
            _tokens(packInputTokens),
          ),
          (
            'Tokens salida',
            _tokens(lo),
            _tokens(ro),
            _tokens(so),
            _tokens(packOutputTokens),
          ),
          (
            'Razonamiento',
            generationReasoningPercent,
            reviewReasoningPercent,
            sortReasoningPercent,
            totalReasoningPercent,
          ),
          (
            'Coste',
            _usd(lunaCost),
            _usd(reviewerCost),
            _usd(sorterCost),
            _usd(packCost),
          ),
          (
            'Correcciones',
            '—',
            correctionLabel,
            '—',
            '$correctionFields campos',
          ),
        ]);

        if (result.review.patches.isNotEmpty) {
          stdout.writeln('CAMBIOS');
          for (final patch in result.review.patches) {
            stdout.writeln(_formatPatch(patch, result.lunaRows));
          }
        } else {
          stdout.writeln('CAMBIOS: —');
        }
      } catch (error) {
        totalWatch.stop();
        failedTests++;
        totalDurations.add(totalWatch.elapsedMilliseconds);
        report.writeln(
          '========== TEST $test/$samples — ERROR — '
          '${(totalWatch.elapsedMilliseconds / 1000).toStringAsFixed(2)} s ==========',
        );
        report.writeln(error);
        report.writeln();
        await report.flush();
        stderr.writeln('Test $test/$samples: $error');
      }
    }

    final totalReasoning =
        lunaReasoning + reviewReasoning + sortReasoning;
    final totalOutput = lunaOutput + reviewOutput + sortOutput;
    final totalInput = lunaInput + reviewInput + sortInput;
    final reasoningPercent = totalOutput == 0
        ? 0.0
        : totalReasoning * 100 / totalOutput;

    report.writeln('========== ESTADÍSTICAS FINALES ==========');
    report.writeln(
      'Tests: $samples | completos: $completeTests | fallidos: $failedTests | '
      'filas finales con incidencia local: $finalRowsWithIssues.',
    );
    report.writeln(
      'Revisión R: tests con correcciones $correctedTests/$completeTests | '
      'preguntas corregidas $correctedQuestions | '
      'campos corregidos $correctedFields.',
    );

    if (totalDurations.isNotEmpty) {
      report.writeln(
        'Pipeline: media '
        '${(totalDurations.reduce((a, b) => a + b) / totalDurations.length / 1000).toStringAsFixed(2)} s | '
        'mediana ${(_percentile(totalDurations, 0.5) / 1000).toStringAsFixed(2)} s | '
        'p95 ${(_percentile(totalDurations, 0.95) / 1000).toStringAsFixed(2)} s | '
        'máxima ${(_percentile(totalDurations, 1) / 1000).toStringAsFixed(2)} s.',
      );
    }
    if (lunaDurations.isNotEmpty) {
      report.writeln(
        'G: media '
        '${(lunaDurations.reduce((a, b) => a + b) / lunaDurations.length / 1000).toStringAsFixed(2)} s | '
        'mediana ${(_percentile(lunaDurations, 0.5) / 1000).toStringAsFixed(2)} s.',
      );
    }
    if (reviewDurations.isNotEmpty) {
      report.writeln(
        'R: media '
        '${(reviewDurations.reduce((a, b) => a + b) / reviewDurations.length / 1000).toStringAsFixed(2)} s | '
        'mediana ${(_percentile(reviewDurations, 0.5) / 1000).toStringAsFixed(2)} s | '
        'p95 ${(_percentile(reviewDurations, 0.95) / 1000).toStringAsFixed(2)} s.',
      );
    }
    if (sortDurations.isNotEmpty) {
      report.writeln(
        'S: media '
        '${(sortDurations.reduce((a, b) => a + b) / sortDurations.length / 1000).toStringAsFixed(2)} s | '
        'mediana ${(_percentile(sortDurations, 0.5) / 1000).toStringAsFixed(2)} s | '
        'p95 ${(_percentile(sortDurations, 0.95) / 1000).toStringAsFixed(2)} s.',
      );
    }

    report.writeln(
      'Tokens G: entrada $lunaInput | salida $lunaOutput | '
      'razonamiento $lunaReasoning | uso $lunaUsageTests/$completeTests.',
    );
    report.writeln(
      'Tokens R: entrada $reviewInput | salida $reviewOutput | '
      'razonamiento $reviewReasoning | uso $reviewUsageTests/$completeTests.',
    );
    report.writeln(
      'Tokens S: entrada $sortInput | salida $sortOutput | '
      'razonamiento $sortReasoning | uso $sortUsageTests/$completeTests.',
    );
    report.writeln(
      'Tokens combinados: entrada $totalInput | '
      'salida $totalOutput | razonamiento $totalReasoning '
      '(${reasoningPercent.toStringAsFixed(1)}% de salida).',
    );

    final averagePackCost = fullyPricedPacks == 0
        ? null
        : completePackCostTotal / fullyPricedPacks;

    report.writeln(
      'Coste estimado combinado: '
      '${pricedStages == 0 ? "n/d" : _usd(totalCost)} '
      '($pricedStages/${completeTests * 3} etapas calculables).',
    );
    report.writeln(
      'Coste G: ${_usd(lunaCostTotal)} | '
      'R: ${_usd(reviewerCostTotal)} | '
      'S: ${_usd(sorterCostTotal)} | '
      'media por pack: ${_usd(averagePackCost)}.',
    );
    report.writeln(
      'No evaluado automáticamente: exactitud factual profunda, '
      'calidad semántica de las correcciones y validez real del orden de dificultad.',
    );

    report.writeln();
    report.writeln('========== PROMPTS DE ESTA EJECUCIÓN ==========');
    report.writeln();
    report.writeln('--- PROMPT G ---');
    report.writeln(quiz10LunaPrompt);
    report.writeln();
    report.writeln('--- PROMPT R ---');
    report.writeln(quiz10ReviewPrompt);
    report.writeln();
    report.writeln('--- PROMPT S ---');
    report.writeln(quiz10SortPrompt);
    report.writeln();

    await report.flush();

    final meanGSeconds = lunaDurations.isEmpty
        ? 0.0
        : lunaDurations.reduce((a, b) => a + b) /
            lunaDurations.length /
            1000;
    final meanRSeconds = reviewDurations.isEmpty
        ? 0.0
        : reviewDurations.reduce((a, b) => a + b) /
            reviewDurations.length /
            1000;
    final meanSSeconds = sortDurations.isEmpty
        ? 0.0
        : sortDurations.reduce((a, b) => a + b) /
            sortDurations.length /
            1000;
    final meanTotalSeconds = meanGSeconds + meanRSeconds + meanSSeconds;

    final gCostPerTest = lunaPricedTests == 0
        ? null
        : lunaCostTotal / lunaPricedTests;
    final rCostPerTest = reviewerPricedTests == 0
        ? null
        : reviewerCostTotal / reviewerPricedTests;
    final sCostPerTest = sorterPricedTests == 0
        ? null
        : sorterCostTotal / sorterPricedTests;

    stdout.writeln();
    stdout.writeln('RESUMEN $samples TESTS');
    _printMetricsTable([
      (
        'Tiempo medio',
        _seconds(meanGSeconds),
        _seconds(meanRSeconds),
        _seconds(meanSSeconds),
        _seconds(meanTotalSeconds),
      ),
      (
        'Tokens entrada',
        lunaInput.toString(),
        reviewInput.toString(),
        sortInput.toString(),
        totalInput.toString(),
      ),
      (
        'Tokens salida',
        lunaOutput.toString(),
        reviewOutput.toString(),
        sortOutput.toString(),
        totalOutput.toString(),
      ),
      (
        'Razonamiento',
        _reasoning(lunaReasoning, lunaOutput),
        _reasoning(reviewReasoning, reviewOutput),
        _reasoning(sortReasoning, sortOutput),
        _reasoning(totalReasoning, totalOutput),
      ),
      (
        'Coste total',
        lunaPricedTests == 0 ? 'n/d' : _usd(lunaCostTotal),
        reviewerPricedTests == 0 ? 'n/d' : _usd(reviewerCostTotal),
        sorterPricedTests == 0 ? 'n/d' : _usd(sorterCostTotal),
        pricedStages == 0 ? 'n/d' : _usd(totalCost),
      ),
      (
        'Coste / test',
        _usd(gCostPerTest),
        _usd(rCostPerTest),
        _usd(sCostPerTest),
        _usd(averagePackCost),
      ),
      (
        'Correcciones',
        '—',
        'Q$questionFieldCorrections R$answerFieldCorrections D$distractorFieldCorrections',
        '—',
        '$correctedFields campos',
      ),
    ]);

    stdout.writeln();
    stdout.writeln('RESULTADO');
    _printResultTable([
      ('Métrica', 'Valor'),
      ('Tests completos', '$completeTests/$samples'),
      ('Tests fallidos', '$failedTests'),
      ('Tests con correcciones', '$correctedTests/$completeTests'),
      ('Preguntas corregidas', '$correctedQuestions'),
      ('Respuestas corregidas', '$answerFieldCorrections'),
      ('Distractores corregidos', '$distractorFieldCorrections'),
      ('Incidencias finales', '$finalRowsWithIssues'),
    ]);
    stdout.writeln('Informe: $path');

    if (failedTests > 0) exitCode = 1;
  } finally {
    await report.close();
    client.close();
  }
}
