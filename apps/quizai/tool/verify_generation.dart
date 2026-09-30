import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:quizai/modes/quiz10/quiz.dart';
import 'package:quizai/modes/quiz10/quiz_generation.dart';
import 'package:quizai/modes/quiz10/quiz10_luna.dart';

/// Verificador existente de Quiz10; --luna usa la etapa definitiva P-D -> Q-R.
Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final client = AiAppsClient(
    endpoint: Uri.parse(env['AI_APPS_AI_URL'] ?? 'http://127.0.0.1:8787'),
    authorization: env['AI_APPS_GAME_TOKEN'] ?? '',
  );
  try {
    if (args.isEmpty) {
      await _verifyCurrentQuiz10(client);
    } else if ((args.length == 5 ||
            (args.length == 7 && args[5] == '--banco-d' &&
                (args[6] == '15' || args[6] == '86'))) &&
        args[0] == '--luna' && args[1] == '--muestras' &&
        args[3] == '--semilla') {
      final samples = int.tryParse(args[2]);
      final seed = int.tryParse(args[4]);
      if (samples == null || samples < 1 || samples > 200 ||
          seed == null || seed < 0 || seed > 1000000000) {
        throw const FormatException('Muestras 1-200 y semilla 0-1000000000.');
      }
      await _verifyLuna(client, samples, seed,
          env['AI_APPS_LUNA_MODEL'] ?? 'gpt-5.6-luna',
          bancoD: args.length == 7 ? int.parse(args[6]) : null);
    } else {
      throw const FormatException(
        'Uso: verify_generation.dart [--luna --muestras 1-200 --semilla N '
        '[--banco-d 15|86]]',
      );
    }
  } catch (error) {
    stderr.writeln('Falló la generación real: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}

/// Conserva sin cambios el verificador de partida preexistente.
Future<void> _verifyCurrentQuiz10(AiAppsClient client) async {
  final generator = AiQuizGenerator(client: client, model: 'gpt-4.1-mini');
  final questions = await generator.generate(selectQuizAreas(Random()));
  final game = QuizGame(questions);
  if (game.questions.length != 10) throw StateError('No hay diez preguntas.');
  stdout.writeln('OK: gpt-4.1-mini devolvió 10 preguntas validadas por Quiz10.');
  for (final question in questions) {
    stdout.writeln('${question.slot.difficulty} | ${question.slot.area}');
  }
}

typedef _Observed = ({int call, Quiz10LunaRow row});

Future<void> _verifyLuna(
  AiAppsClient client,
  int samples,
  int seed,
  String model, {
  int? bancoD,
}) async {
  if (bancoD != null && bancoD != 15 && bancoD != 86) {
    throw ArgumentError.value(bancoD, 'bancoD');
  }
  final outputDir = Directory('../../.ai-apps/experimentos-luna-pd');
  await outputDir.create(recursive: true);
  final runId = DateTime.now().toUtc().toIso8601String()
      .replaceAll(':', '-').replaceAll('.', '-');
  final filePrefix = bancoD == null ? 'luna-pd' : 'luna-banco-d$bancoD';
  final raw = File('${outputDir.path}/$filePrefix-$runId.jsonl');
  final questions = File('${outputDir.path}/$filePrefix-$runId.md');
  final observed = <_Observed>[];
  var inputTokens = 0;
  var outputTokens = 0;
  var usageComplete = true;

  await questions.writeAsString(
    '# Quiz10 — Preguntas reales P × D → Q, R\n\n'
    'Modelo: $model · Semilla: $seed · Prompt único de Luna · '
    'Sin historial U · Llamadas previstas: $samples.\n\n'
    'Estas preguntas no han sido verificadas factualmente por Terra.\n',
    flush: true,
  );
  stdout.writeln('Luna: $samples llamadas × 10 preguntas, con D y sin U.');
  stdout.writeln('Modelo: $model; semilla inicial: $seed.');
  stdout.writeln('Resultados: ${questions.path}');
  for (var index = 0; index < samples; index++) {
    final timer = Stopwatch()..start();
    final plan = bancoD != null
        ? selectQuiz10LunaPlanBancoD(
            Random(seed + index),
            bancoD: bancoD,
            callIndex: index,
            seed: seed,
          )
        : selectQuiz10LunaPlan(Random(seed + index));
    final prompt = quiz10LunaPrompt(plan);
    String? rawOutput;
    final base = <String, Object?>{
      'llamada': index + 1,
      'semilla': seed + index,
      'modelo': model,
      'historialU': false,
      'modo': bancoD == null ? 'P-D' : 'P-D$bancoD',
      if (bancoD != null) 'bancoD': bancoD,
      if (bancoD != null) 'asignacionD': 'equilibrada-por-posicion',
      'promptVersion': 'quiz10-luna-unico',
      'plan': [
        for (final slot in plan)
          {
            'id': slot.number,
            'pivote': slot.pivot,
            'dimension': slot.dimension.code,
            'familia': slot.dimension.familyCode,
            'instruccion': slot.dimension.instruction,
            'dificultad': slot.difficulty,
          },
      ],
      'prompt': prompt,
    };
    try {
      // Usa el mismo prompt, esquema y parser del generador de Luna.
      final result = await client.generate(
        application: 'quiz10',
        model: model,
        input: prompt,
        schemaName: 'quiz10_luna_questions',
        schema: quiz10LunaSchema(),
      ).timeout(const Duration(seconds: 120));
      rawOutput = result.text;
      final rows = parseQuiz10LunaOutput(result.text, plan);
      final inTokens = result.usage?['inputTokens'];
      final outTokens = result.usage?['outputTokens'];
      if (inTokens is int && outTokens is int) {
        inputTokens += inTokens;
        outputTokens += outTokens;
      } else {
        usageComplete = false;
      }
      await raw.writeAsString(
        '${jsonEncode({
          ...base,
          'estado': 'ok',
          'filas': [
            for (final row in rows)
              {
                'id': row.slot.number,
                'pivote': row.slot.pivot,
                'dimension': row.slot.dimension.code,
                'familia': row.slot.dimension.familyCode,
                'dificultad': row.slot.difficulty,
                'pregunta': row.question,
                'respuesta_correcta': row.correct,
              },
          ],
          'respuestaBruta': rawOutput,
          'tokensEntrada': inTokens,
          'tokensSalida': outTokens,
          'duracionMs': timer.elapsedMilliseconds,
        })}\n',
        mode: FileMode.append,
        flush: true,
      );
      observed.addAll([for (final row in rows) (call: index + 1, row: row)]);
      final buffer = StringBuffer()
        ..writeln('\n## Llamada ${index + 1}/$samples')
        ..writeln()
        ..writeln('| Nº | P | D | Instrucción D | Dificultad | Pregunta Q | Respuesta R |')
        ..writeln('|---:|---|---|---|---|---|---|');
      for (final row in rows) {
        buffer.writeln(
          '| ${row.slot.number} | ${_cell(row.slot.pivot)} | '
          '${row.slot.dimension.code} | '
          '${_cell(row.slot.dimension.instruction)} | '
          '${_cell(row.slot.difficulty)} | '
          '${_cell(row.question)} | ${_cell(row.correct)} |',
        );
      }
      await questions.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
      stdout.writeln(
        'Llamada ${index + 1}/$samples: 10 Q/R guardadas; '
        '${timer.elapsedMilliseconds} ms.',
      );
    } catch (error) {
      await raw.writeAsString(
        '${jsonEncode({
          ...base,
          'estado': 'error',
          'error': error.toString(),
          'respuestaBruta': rawOutput,
          'duracionMs': timer.elapsedMilliseconds,
        })}\n',
        mode: FileMode.append,
        flush: true,
      );
      stdout.writeln(
        'Se conservan ${observed.length} preguntas de las llamadas terminadas.',
      );
      rethrow;
    }
  }

  final summary = _lunaSummary(observed);
  await questions.writeAsString(
    '\n$summary\n\n'
    'Tokens de entrada: ${usageComplete ? inputTokens : 'datos incompletos'}. '
    'Tokens de salida: ${usageComplete ? outputTokens : 'datos incompletos'}.\n',
    mode: FileMode.append,
    flush: true,
  );
  stdout.writeln('\n$summary');
  stdout.writeln('Datos por llamada: ${raw.path}');
  stdout.writeln('Preguntas e informe: ${questions.path}');
}

String _lunaSummary(List<_Observed> observed) {
  final byPivot = <String, List<_Observed>>{};
  final byPair = <String, List<_Observed>>{};
  for (final item in observed) {
    final pivot = item.row.slot.pivot;
    final pair = '$pivot|${item.row.slot.dimension.code}';
    byPivot.putIfAbsent(pivot, () => <_Observed>[]).add(item);
    byPair.putIfAbsent(pair, () => <_Observed>[]).add(item);
  }
  final answers = observed.map((item) => _answerKey(item.row.correct)).toList();
  final globalDistinct = answers.toSet().length;
  final buffer = StringBuffer()
    ..writeln('## Diversidad de respuestas R (comparación textual)')
    ..writeln()
    ..writeln('Filas: ${observed.length}. '
        'R diferentes globales: $globalDistinct. '
        'Repeticiones globales: ${answers.length - globalDistinct}.')
    ..writeln('P–D observados: ${byPair.length}. '
        'Parejas P–D repetidas: '
        '${byPair.values.where((items) => items.length > 1).length}.')
    ..writeln()
    ..writeln('| Pivote P | Filas | R diferentes | R repetidas | '
        'R que reaparecen con distintas D | R que reaparecen con la misma D |')
    ..writeln('|---|---:|---:|---:|---:|---:|');
  final pivots = byPivot.keys.toList()..sort();
  for (final pivot in pivots) {
    final items = byPivot[pivot]!;
    final answersByValue = <String, List<_Observed>>{};
    for (final item in items) {
      answersByValue.putIfAbsent(
        _answerKey(item.row.correct),
        () => <_Observed>[],
      ).add(item);
    }
    final acrossD = answersByValue.values.where(
      (rows) => rows.map((item) => item.row.slot.dimension.code).toSet().length > 1,
    ).length;
    final withinD = answersByValue.values.where((rows) {
      final seen = <String>{};
      return rows.any((item) => !seen.add(item.row.slot.dimension.code));
    }).length;
    buffer.writeln(
      '| ${_cell(pivot)} | ${items.length} | ${answersByValue.length} | '
      '${items.length - answersByValue.length} | $acrossD | $withinD |',
    );
  }
  buffer.writeln('\n### Respuestas repetidas dentro del mismo pivote');
  var found = false;
  for (final pivot in pivots) {
    final repeated = <String, List<_Observed>>{};
    for (final item in byPivot[pivot]!) {
      repeated.putIfAbsent(
        _answerKey(item.row.correct),
        () => <_Observed>[],
      ).add(item);
    }
    for (final rows in repeated.values) {
      if (rows.length < 2) continue;
      found = true;
      buffer.writeln(
        '- ${_cell(pivot)} — **${_cell(rows.first.row.correct)}**: '
        '${rows.map((item) => 'llamada ${item.call}, '
            '${item.row.slot.dimension.code}').join('; ')}.',
      );
    }
  }
  if (!found) buffer.writeln('Ninguna repetición textual dentro de un mismo P.');
  buffer.writeln('\nLa comparación normaliza mayúsculas y espacios; '
      'no detecta sinónimos ni distintas respuestas que remiten a un mismo '
      'hecho. Esta comparación textual no verifica equivalencias semánticas.');
  return buffer.toString();
}

String _answerKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _cell(String value) =>
    value.replaceAll('|', r'\|').replaceAll(RegExp(r'\s+'), ' ').trim();
