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

    for (var i = 0; i < samples; i++) {
      final plan = selectQuiz10Pairs(Random(seed + i));
      final rows = await luna.generate(plan);
      stdout.writeln('Luna: llamada ${i + 1}/$samples, ${rows.length} Q-R.');
      for (final row in rows) {
        stdout.writeln(
          '${row.slot.number}. ${row.slot.pivot.code} '
          '${row.slot.dimension.code} | ${row.question} → ${row.correct}',
        );
      }
    }
  } catch (error) {
    stderr.writeln('Falló la generación Q-R de Luna: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}
