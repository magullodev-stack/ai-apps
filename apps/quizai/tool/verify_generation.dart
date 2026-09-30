import 'dart:io';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:quizai/modes/quiz10/quiz10_catalog.dart';
import 'package:quizai/modes/quiz10/quiz10_luna.dart';

/// Comprueba únicamente P-D → Luna → Q-R; Terra aún no está conectada.
Future<void> main(List<String> args) async {
  var samples = 1;
  var seed = 20260929;

  if (args.isNotEmpty) {
    if (args.length != 5 ||
        args[0] != '--luna' ||
        args[1] != '--muestras' ||
        args[3] != '--semilla') {
      stderr.writeln(
        'Uso: verify_generation.dart [--luna --muestras 1-200 --semilla N]',
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

  try {
    final luna = AiQuiz10LunaGenerator(
      client: client,
      model: env['AI_APPS_LUNA_MODEL'] ?? 'gpt-5.6-luna',
    );

    // El detalle queda en el informe; la terminal solo muestra el progreso.
    final timestamp = DateTime.now().toIso8601String()
        .substring(0, 19)
        .replaceFirst('T', '_')
        .replaceAll(':', '-');
    final reportPath = 'Q+R_$timestamp.txt';
    final report = File(reportPath).openWrite();

    try {
      report.writeln('AUDITORÍA Q+R — Luna');
      report.writeln('Fecha: ${DateTime.now()}');
      report.writeln('Modelo: ${luna.model}');
      report.writeln('Semilla: $seed | Llamadas solicitadas: $samples');
      report.writeln();

    final timer = Stopwatch()..start();
    final pivots = <String, int>{};
    final dimensions = <String, int>{};
    final answers = <String, int>{};
    final answersByPivot = <String, Map<String, String>>{};
    var successful = 0;
    var failed = 0;
    var generated = 0;
    var badQuestions = 0;
    var badAnswers = 0;
    var answersRepeatedInCall = 0;
    var answersRepeatedSameD = 0;
    var answersRepeatedOtherD = 0;
    var answersInQuestions = 0;
    var totalQuestionWords = 0;
    var totalAnswerWords = 0;
    var totalMillis = 0;

    for (var i = 0; i < samples; i++) {
      final callTimer = Stopwatch()..start();
      try {
        final plan = selectQuiz10Pairs(Random(seed + i));
        final rows = await luna.generate(plan);
        callTimer.stop();
        successful++;
        totalMillis += callTimer.elapsedMilliseconds;
        final withinCall = <String>{};
        report.writeln(
          'Llamada ${i + 1}/$samples | '
          '${rows.length} Q-R | '
          '${callTimer.elapsedMilliseconds} ms',
        );

        for (final row in rows) {
          generated++;
          final pivot = row.slot.pivot.code;
          final dimension = row.slot.dimension.code;
          pivots.update(pivot, (n) => n + 1, ifAbsent: () => 1);
          dimensions.update(dimension, (n) => n + 1, ifAbsent: () => 1);

          final questionWords = row.question.trim().split(RegExp(r'\s+')).length;
          final answerWords = row.correct.trim().split(RegExp(r'\s+')).length;
          totalQuestionWords += questionWords;
          totalAnswerWords += answerWords;
          if (questionWords < 4 || questionWords > 24) badQuestions++;
          if (answerWords < 1 || answerWords > 8) badAnswers++;

          final normalized = row.correct
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), ' ');
          answers.update(normalized, (n) => n + 1, ifAbsent: () => 1);
          if (!withinCall.add(normalized)) answersRepeatedInCall++;

          final previousByPivot = answersByPivot.putIfAbsent(
            pivot,
            () => <String, String>{},
          );
          final previousD = previousByPivot[normalized];
          if (previousD == null) {
            previousByPivot[normalized] = dimension;
          } else if (previousD == dimension) {
            answersRepeatedSameD++;
          } else {
            answersRepeatedOtherD++;
          }
          if (row.question.toLowerCase().contains(normalized)) {
            answersInQuestions++;
          }

          report.writeln(
            '${row.slot.number}. $pivot $dimension | '
            '${row.question} → ${row.correct}',
          );
        }
      } catch (error) {
        callTimer.stop();
        totalMillis += callTimer.elapsedMilliseconds;
        failed++;
        report.writeln('Llamada ${i + 1}/$samples | ERROR: $error');
      } finally {
        report.writeln();
        await report.flush();
        stdout.writeln('${i + 1}/$samples');
      }
    }
    timer.stop();

    report.writeln('\n=== ESTADÍSTICAS LUNA P-D → Q-R ===');
    report.writeln('Modelo: ${luna.model} | Semilla inicial: $seed');
    report.writeln('Llamadas: $samples | Correctas: $successful | Fallidas: $failed');
    report.writeln('Q-R obtenidas: $generated');
    report.writeln('Tiempo total: ${timer.elapsed.inSeconds} s');
    report.writeln(
      'Tiempo medio por llamada: '
      '${(totalMillis / samples / 1000).toStringAsFixed(2)} s',
    );
    report.writeln('Preguntas fuera de 4-24 palabras: $badQuestions');
    report.writeln('Respuestas fuera de 1-8 palabras: $badAnswers');
    report.writeln(
      'Media palabras Q: '
      '${generated == 0 ? "n/d" : (totalQuestionWords / generated).toStringAsFixed(2)}',
    );
    report.writeln(
      'Media palabras R: '
      '${generated == 0 ? "n/d" : (totalAnswerWords / generated).toStringAsFixed(2)}',
    );
    report.writeln('Respuestas distintas (texto normalizado): ${answers.length}');
    report.writeln(
      'Repeticiones textuales R dentro de una llamada: '
      '$answersRepeatedInCall',
    );
    report.writeln(
      'Repeticiones textuales R por P con la misma D: '
      '$answersRepeatedSameD',
    );
    report.writeln(
      'Repeticiones textuales R por P con distinta D: '
      '$answersRepeatedOtherD',
    );
    report.writeln(
      'Q que contienen R como subcadena (indicador aproximado): '
      '$answersInQuestions',
    );
    report.writeln('Frecuencias de pivotes P:');
    for (final code in pivots.keys.toList()..sort()) {
      report.writeln('  $code: ${pivots[code]}');
    }
    report.writeln('Frecuencias de dimensiones D:');
    for (final code in dimensions.keys.toList()..sort()) {
      report.writeln('  $code: ${dimensions[code]}');
    }
    report.writeln(
      'No evaluado automáticamente: verdad factual, '
      'dificultad de conocimiento, sinónimos ni equivalencia semántica.',
    );
    await report.flush();
    stdout.writeln('Auditoría guardada: $reportPath');
    stdout.writeln(
      'Correctas: $successful | Fallidas: $failed | Q-R: $generated',
    );
    if (failed > 0) exitCode = 1;
    } finally {
      await report.close();
    }
  } catch (error) {
    stderr.writeln('Falló la generación Q-R de Luna: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}
