import 'dart:io';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:quizai/modes/quiz10/quiz10_LUNA_Prompt.dart';
import 'package:quizai/modes/quiz10/quiz10_REVIEW_Prompt.dart';
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

String _formatPatch(Quiz10ReviewPatch patch) {
  final buffer = StringBuffer()..writeln('${patch.number}.');
  for (final change in patch.changes) {
    buffer.writeln('${change.field}: ${change.value}');
  }
  return buffer.toString().trimRight();
}

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
        '[--quiz10 --muestras 1-20 --semilla N]',
      );
      exitCode = 64;
      return;
    }

    final parsedSamples = int.tryParse(args[2]);
    final parsedSeed = int.tryParse(args[4]);
    if (parsedSamples == null ||
        parsedSamples < 1 ||
        parsedSamples > 20 ||
        parsedSeed == null ||
        parsedSeed < 0 ||
        parsedSeed > 1000000000) {
      stderr.writeln('Muestras 1-20 y semilla 0-1000000000.');
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

  final pipeline = AiQuiz10Pipeline(
    client: client,
    lunaModel: env['AI_APPS_LUNA_MODEL'] ?? 'gpt-5.6-luna',
    reviewerModel: env['AI_APPS_QUIZ10_REVIEW_MODEL'] ?? 'gpt-5.6-luna',
  );

  final lunaRates = _rates(pipeline.luna.model);
  final reviewRates = _rates(pipeline.reviewer.model);

  final timestamp = DateTime.now()
      .toIso8601String()
      .substring(0, 19)
      .replaceFirst('T', '_')
      .replaceAll(':', '-');

  final path =
      'Quiz10_${_modelLabel(pipeline.luna.model)}+'
      '${_modelLabel(pipeline.reviewer.model)}_PIPELINE_'
      '${samples}T_${samples * 10}L_${samples}R_'
      's${seed}_$timestamp.txt';

  final report = File(path).openWrite();

  final totalDurations = <int>[];
  final lunaDurations = <int>[];
  final reviewDurations = <int>[];

  var completeTests = 0;
  var failedTests = 0;
  var correctedTests = 0;
  var correctedQuestions = 0;
  var correctedFields = 0;
  var finalRowsWithIssues = 0;

  var lunaInput = 0;
  var lunaOutput = 0;
  var lunaReasoning = 0;
  var reviewInput = 0;
  var reviewOutput = 0;
  var reviewReasoning = 0;
  var lunaUsageTests = 0;
  var reviewUsageTests = 0;
  var totalCost = 0.0;
  var lunaCostTotal = 0.0;
  var reviewerCostTotal = 0.0;
  var completePackCostTotal = 0.0;
  var fullyPricedPacks = 0;
  var pricedStages = 0;

  try {
    report.writeln('AUDITORÍA QUIZ10 — PIPELINE LUNA → REVISIÓN → DART');
    report.writeln('Fecha: ${DateTime.now()}');
    report.writeln('Luna: ${pipeline.luna.model}');
    report.writeln('Revisor: ${pipeline.reviewer.model}');
    report.writeln(
      'Ejecución por test: 10 llamadas Luna simultáneas, '
      '1 revisión global, aplicación de parches, orden y shuffle en Dart.',
    );
    report.writeln('Prompt Luna:\n$quiz10LunaPrompt');
    report.writeln('Prompt revisor:\n$quiz10ReviewPrompt');
    report.writeln(
      'Semilla: $seed | Tests: $samples | '
      'Llamadas Luna: ${samples * 10} | '
      'Llamadas revisor: $samples.',
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

        final lunaUsage = result.lunaGeneration.usage;
        final reviewerUsage = result.review.usage;

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
        if (lunaCost != null) {
          totalCost += lunaCost;
          lunaCostTotal += lunaCost;
          pricedStages++;
        }
        if (reviewerCost != null) {
          totalCost += reviewerCost;
          reviewerCostTotal += reviewerCost;
          pricedStages++;
        }
        final packCost = lunaCost != null && reviewerCost != null
            ? lunaCost + reviewerCost
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

        report.writeln(
          '========== TEST $test/$samples — '
          '${(totalWatch.elapsedMilliseconds / 1000).toStringAsFixed(2)} s '
          '(Luna ${(result.lunaDuration.inMilliseconds / 1000).toStringAsFixed(2)} s '
          '+ revisión ${(result.reviewDuration.inMilliseconds / 1000).toStringAsFixed(2)} s) ==========',
        );

        report.writeln('\n--- SALIDA LUNA ---');
        for (var rowIndex = 0; rowIndex < result.lunaRows.length; rowIndex++) {
          final row = result.lunaRows[rowIndex];
          report.writeln(
            '${rowIndex + 1}. ${row.slot.pivot.code} ${row.slot.dimension.code} | '
            'F: ${row.fact} | Q: ${row.question} | '
            'O: ${[
              for (var option = 0; option < row.options.length; option++)
                "${option + 1}=${row.options[option]}",
            ].join(" / ")} | C: ${row.correctPosition} | R: ${row.correct}',
          );
        }

        report.writeln('\n--- ENTRADA REVISOR ---');
        report.writeln(result.reviewInput);

        report.writeln('\n--- SALIDA REVISOR RAW ---');
        report.writeln(result.review.rawText);

        report.writeln('\n--- ORDEN ---');
        report.writeln(result.review.order);

        report.writeln('\n--- CORRECCIONES ---');
        if (result.review.patches.isEmpty) {
          report.writeln('(ninguna)');
        } else {
          for (final patch in result.review.patches) {
            report.writeln(_formatPatch(patch));
          }
        }

        report.writeln('\n--- TEST TRAS REVISIÓN Y ORDEN ---');
        for (var finalIndex = 0;
            finalIndex < result.reviewedItems.length;
            finalIndex++) {
          final item = result.reviewedItems[finalIndex];
          final original = item.source.slot.number;
          report.writeln(
            '${finalIndex + 1}. [original $original] '
            'Q: ${item.question} | R: ${item.correct} | '
            'a1: ${item.distractors[0]} | '
            'a2: ${item.distractors[1]} | '
            'a3: ${item.distractors[2]}',
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
          'Luna: entrada ${_known(li)}, salida ${_known(lo)}, '
          'razonamiento ${_known(lr)}, coste ${_usd(lunaCost)} | '
          'Revisor: entrada ${_known(ri)}, salida ${_known(ro)}, '
          'razonamiento ${_known(rr)}, coste ${_usd(reviewerCost)}',
        );
        report.writeln();
        await report.flush();

        stdout.writeln(
          'Test $test/$samples | '
          'Luna ${(result.lunaDuration.inMilliseconds / 1000).toStringAsFixed(2)} s | '
          'revisión ${(result.reviewDuration.inMilliseconds / 1000).toStringAsFixed(2)} s | '
          'correcciones ${result.review.patches.length} pregunta(s) | '
          'coste pack ${_usd(packCost)} | '
          'acumulado ${pricedStages == 0 ? "n/d" : _usd(totalCost)}',
        );
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
        lunaReasoning + reviewReasoning;
    final totalOutput =
        lunaOutput + reviewOutput;
    final reasoningPercent = totalOutput == 0
        ? 0.0
        : totalReasoning * 100 / totalOutput;

    report.writeln('========== ESTADÍSTICAS FINALES ==========');
    report.writeln(
      'Tests: $samples | completos: $completeTests | fallidos: $failedTests | '
      'filas finales con incidencia local: $finalRowsWithIssues.',
    );
    report.writeln(
      'Revisión: tests con correcciones $correctedTests/$completeTests | '
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
        'Luna: media '
        '${(lunaDurations.reduce((a, b) => a + b) / lunaDurations.length / 1000).toStringAsFixed(2)} s | '
        'mediana ${(_percentile(lunaDurations, 0.5) / 1000).toStringAsFixed(2)} s.',
      );
    }
    if (reviewDurations.isNotEmpty) {
      report.writeln(
        'Revisor: media '
        '${(reviewDurations.reduce((a, b) => a + b) / reviewDurations.length / 1000).toStringAsFixed(2)} s | '
        'mediana ${(_percentile(reviewDurations, 0.5) / 1000).toStringAsFixed(2)} s | '
        'p95 ${(_percentile(reviewDurations, 0.95) / 1000).toStringAsFixed(2)} s.',
      );
    }

    report.writeln(
      'Tokens Luna: entrada $lunaInput | salida $lunaOutput | '
      'razonamiento $lunaReasoning | uso $lunaUsageTests/$completeTests.',
    );
    report.writeln(
      'Tokens revisor: entrada $reviewInput | salida $reviewOutput | '
      'razonamiento $reviewReasoning | uso $reviewUsageTests/$completeTests.',
    );
    report.writeln(
      'Tokens combinados: entrada ${lunaInput + reviewInput} | '
      'salida $totalOutput | razonamiento $totalReasoning '
      '(${reasoningPercent.toStringAsFixed(1)}% de salida).',
    );
    final averagePackCost = fullyPricedPacks == 0
        ? null
        : completePackCostTotal / fullyPricedPacks;

    report.writeln(
      'Coste estimado combinado: '
      '${pricedStages == 0 ? "n/d" : _usd(totalCost)} '
      '($pricedStages/${completeTests * 2} etapas calculables).',
    );
    report.writeln(
      'Coste Luna: ${_usd(lunaCostTotal)} | '
      'revisor: ${_usd(reviewerCostTotal)} | '
      'media por pack: ${_usd(averagePackCost)}.',
    );
    report.writeln(
      'No evaluado automáticamente: exactitud factual profunda, '
      'calidad semántica de las correcciones y validez real del orden de dificultad.',
    );

    await report.flush();
    stdout.writeln(
      'Coste total estimado: '
      '${pricedStages == 0 ? "n/d" : _usd(totalCost)} | '
      'media por pack ${_usd(averagePackCost)} | '
      'Luna ${_usd(lunaCostTotal)} | '
      'revisor ${_usd(reviewerCostTotal)}',
    );
    stdout.writeln('Informe: $path');

    if (failedTests > 0) exitCode = 1;
  } finally {
    await report.close();
    client.close();
  }
}
