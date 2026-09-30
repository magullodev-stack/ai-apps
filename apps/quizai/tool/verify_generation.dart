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

    // STATS_LUNA_200: solo resultados reales, sin modificar el prompt.
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
        stdout.writeln(
          'Luna: llamada ${i + 1}/$samples, '
          '${rows.length} Q-R, '
          '${callTimer.elapsedMilliseconds} ms.',
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

          stdout.writeln(
            '${row.slot.number}. $pivot $dimension | '
            '${row.question} → ${row.correct}',
          );
        }
      } catch (error) {
        callTimer.stop();
        totalMillis += callTimer.elapsedMilliseconds;
        failed++;
        stderr.writeln('Luna: llamada ${i + 1}/$samples FALLÓ: $error');
      }
    }
    timer.stop();

    stdout.writeln('\n=== ESTADÍSTICAS LUNA P-D → Q-R ===');
    stdout.writeln('Modelo: ${luna.model} | Semilla inicial: $seed');
    stdout.writeln('Llamadas: $samples | Correctas: $successful | Fallidas: $failed');
    stdout.writeln('Q-R obtenidas: $generated');
    stdout.writeln('Tiempo total: ${timer.elapsed.inSeconds} s');
    stdout.writeln(
      'Tiempo medio por llamada: '
      '${(totalMillis / samples / 1000).toStringAsFixed(2)} s',
    );
    stdout.writeln('Preguntas fuera de 4-24 palabras: $badQuestions');
    stdout.writeln('Respuestas fuera de 1-8 palabras: $badAnswers');
    stdout.writeln(
      'Media palabras Q: '
      '${generated == 0 ? "n/d" : (totalQuestionWords / generated).toStringAsFixed(2)}',
    );
    stdout.writeln(
      'Media palabras R: '
      '${generated == 0 ? "n/d" : (totalAnswerWords / generated).toStringAsFixed(2)}',
    );
    stdout.writeln('Respuestas distintas (texto normalizado): ${answers.length}');
    stdout.writeln(
      'Repeticiones textuales R dentro de una llamada: '
      '$answersRepeatedInCall',
    );
    stdout.writeln(
      'Repeticiones textuales R por P con la misma D: '
      '$answersRepeatedSameD',
    );
    stdout.writeln(
      'Repeticiones textuales R por P con distinta D: '
      '$answersRepeatedOtherD',
    );
    stdout.writeln(
      'Q que contienen R como subcadena (indicador aproximado): '
      '$answersInQuestions',
    );
    stdout.writeln('Frecuencias de pivotes P:');
    for (final code in pivots.keys.toList()..sort()) {
      stdout.writeln('  $code: ${pivots[code]}');
    }
    stdout.writeln('Frecuencias de dimensiones D:');
    for (final code in dimensions.keys.toList()..sort()) {
      stdout.writeln('  $code: ${dimensions[code]}');
    }
    stdout.writeln(
      'No evaluado automáticamente: verdad factual, '
      'dificultad de conocimiento, sinónimos ni equivalencia semántica.',
    );
    if (failed > 0) exitCode = 1;
  } catch (error) {
    stderr.writeln('Falló la generación Q-R de Luna: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}
