import 'dart:io';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:quizai/modes/quiz10/quiz.dart';
import 'package:quizai/modes/quiz10/quiz_generation.dart';

/// Explicit live check. Never included in flutter test.
Future<void> main() async {
  final env = Platform.environment;
  final client = AiAppsClient(
    endpoint: Uri.parse(env['AI_APPS_AI_URL'] ?? 'http://127.0.0.1:8787'),
    authorization: env['AI_APPS_GAME_TOKEN'] ?? '',
  );
  try {
    final generator = AiQuizGenerator(client: client, model: 'gpt-4.1-mini');
    final questions = await generator.generate(selectQuizAreas(Random()));
    // Exercise the same validator and game entry point as the mobile UI.
    final game = QuizGame(questions);
    if (game.questions.length != 10) throw StateError('No hay diez preguntas.');
    stdout.writeln(
      'OK: gpt-4.1-mini devolvió 10 preguntas validadas por Quiz10.',
    );
    for (final question in questions) {
      stdout.writeln('${question.slot.difficulty} | ${question.slot.area}');
    }
  } catch (error) {
    stderr.writeln('Falló la generación real: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}
