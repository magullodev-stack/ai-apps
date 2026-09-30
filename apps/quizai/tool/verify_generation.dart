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
    } else if (args.length >= 5 &&
        args.length <= 7 &&
        args[0] == '--luna' &&
        args[1] == '--muestras' &&
        args[3] == '--semilla' &&
        args.skip(5).every((flag) => flag == '--sin-d' || flag == '--con-u') &&
        args.skip(5).toSet().length == args.length - 5 &&
        (!args.contains('--con-u') || args.contains('--sin-d'))) {
      final samples = int.tryParse(args[2]);
      final seed = int.tryParse(args[4]);
      if (samples == null ||
          samples < 1 ||
          samples > 200 ||
          seed == null ||
          seed < 0 ||
          seed > 1000000000) {
        throw const FormatException('Muestras 1-200 y semilla 0-1000000000.');
      }
      await _verifyLuna(
        client, samples, seed,
        env['AI_APPS_LUNA_MODEL'] ?? 'gpt-5.6-luna',
        sinD: args.contains('--sin-d'),
        conU: args.contains('--con-u'),
      );
    } else if (args.length == 7 &&
        args[0] == '--luna' &&
        args[1] == '--muestras' &&
        args[3] == '--semilla' &&
        args[5] == '--banco-d' &&
        (args[6] == '15' || args[6] == '86')) {
      final samples = int.tryParse(args[2]);
      final seed = int.tryParse(args[4]);
      if (samples == null ||
          samples < 1 ||
          samples > 200 ||
          seed == null ||
          seed < 0 ||
          seed > 1000000000) {
        throw const FormatException('Muestras 1-200 y semilla 0-1000000000.');
      }
      await _verifyLuna(
        client, samples, seed,
        env['AI_APPS_LUNA_MODEL'] ?? 'gpt-5.6-luna',
        bancoD: int.parse(args[6]),
      );
    } else {
      throw const FormatException(
        'Uso: verify_generation.dart [--luna --muestras 1-200 --semilla N [--sin-d] [--con-u]] '
        'o [--luna --muestras 1-200 --semilla N --banco-d 15|86]',
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
  bool sinD = false,
  bool conU = false,
  int? bancoD,
}) async {
  if (bancoD != null && bancoD != 15 && bancoD != 86) {
    throw ArgumentError.value(bancoD, 'bancoD');
  }
  if (bancoD != null && (conU || sinD)) {
    throw ArgumentError('La comparación de bancos utiliza D y no utiliza U.');
  }
  if (conU && !sinD) {
    throw ArgumentError('El experimento con U requiere --sin-d.');
  }
  final outputDir = Directory('../../.ai-apps/experimentos-luna-pd');
  await outputDir.create(recursive: true);
  final runId = DateTime.now().toUtc().toIso8601String()
      .replaceAll(':', '-').replaceAll('.', '-');
  final filePrefix = bancoD != null
      ? 'luna-banco-d$bancoD'
      : conU ? 'luna-pu' : sinD ? 'luna-p' : 'luna-pd';
  final raw = File('${outputDir.path}/$filePrefix-$runId.jsonl');
  final questions = File('${outputDir.path}/$filePrefix-$runId.md');
  final observed = <_Observed>[];
  final historyU = <String>[];
  var inputTokens = 0;
  var outputTokens = 0;
  var usageComplete = true;

  await questions.writeAsString(
    '# Quiz10 — Preguntas reales ${sinD ? 'P' : 'P × D'} → Q, R\n\n'
    'Modelo: $model · Semilla: $seed · '
    '${bancoD == null ? 'Prompt de referencia' : 'Comparación banco D$bancoD; prompt bloques 4/3/2/1; Q 4-24; R 1-8'} · '
    '${conU ? 'U por bloques de diez llamadas' : 'Sin historial U'} · '
    'Llamadas previstas: $samples.\n\n'
    'Estas preguntas no han sido verificadas factualmente por Terra.\n',
    flush: true,
  );
  stdout.writeln('Luna: $samples llamadas × 10 preguntas, '
      '${sinD ? 'sin D' : 'con D'}, '
      '${conU ? 'U reiniciada cada diez llamadas' : 'sin U'}.');
  stdout.writeln('Modelo: $model; semilla inicial: $seed.');
  stdout.writeln('Resultados: ${questions.path}');
  for (var index = 0; index < samples; index++) {
    if (conU && index % 10 == 0) historyU.clear();
    final historySent = List<String>.unmodifiable(historyU);
    final timer = Stopwatch()..start();
    final plan = bancoD != null
        ? selectQuiz10LunaPlanBancoD(
            Random(seed + index),
            bancoD: bancoD,
            callIndex: index,
            seed: seed,
          )
        : selectQuiz10LunaPlan(Random(seed + index));
    final prompt = bancoD != null
        ? quiz10LunaPromptComparacionBancosD(plan)
        : sinD
            ? quiz10LunaPromptSinD(
                plan, historialU: conU ? historySent : null,
              )
            : quiz10LunaPrompt(plan);
    String? rawOutput;
    final base = <String, Object?>{
      'llamada': index + 1,
      'semilla': seed + index,
      'modelo': model,
      'historialU': conU,
      'modo': bancoD == null
          ? (conU ? 'P-U' : sinD ? 'P' : 'P-D')
          : 'P-D$bancoD',
      if (bancoD != null) 'bancoD': bancoD,
      if (bancoD != null) 'asignacionD': 'equilibrada-por-posicion',
      if (bancoD != null) 'promptVersion': 'bancos-d-v1-4-3-2-1-q4-24-r1-8',
      if (conU) 'bloque': index ~/ 10 + 1,
      if (conU) 'posicionBloque': index % 10 + 1,
      if (conU) 'U': historySent,
      'plan': [
        for (final slot in plan)
          {
            'id': slot.number,
            'pivote': slot.pivot,
            if (!sinD) 'dimension': slot.dimension.code,
            if (!sinD) 'familia': slot.dimension.familyCode,
            if (!sinD) 'instruccion': slot.dimension.instruction,
            'dificultad': slot.difficulty,
          },
      ],
      'prompt': prompt,
    };
    try {
      // Es exactamente el prompt, schema y parser del generador real de Luna.
      final result = await client.generate(
        application: 'quiz10',
        model: model,
        input: prompt,
        schemaName: 'quiz10_luna_questions',
        schema: quiz10LunaSchema(),
      ).timeout(const Duration(seconds: 120));
      rawOutput = result.text;
      final rows = parseQuiz10LunaOutput(result.text, plan);
      final repeatedAgainstU = conU
          ? rows.where((row) => historySent.any(
              (answer) => _answerKey(answer) == _answerKey(row.correct),
            )).map((row) => row.correct).toList()
          : <String>[];
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
                if (!sinD) 'dimension': row.slot.dimension.code,
                if (!sinD) 'familia': row.slot.dimension.familyCode,
                'dificultad': row.slot.difficulty,
                'pregunta': row.question,
                'respuesta_correcta': row.correct,
              },
          ],
          'respuestaBruta': rawOutput,
          if (conU) 'repetidasEnU': repeatedAgainstU,
          'tokensEntrada': inTokens,
          'tokensSalida': outTokens,
          'duracionMs': timer.elapsedMilliseconds,
        })}\n',
        mode: FileMode.append,
        flush: true,
      );
      observed.addAll([for (final row in rows) (call: index + 1, row: row)]);
      if (conU) {
        final seen = historyU.map(_answerKey).toSet();
        for (final row in rows) {
          if (seen.add(_answerKey(row.correct))) historyU.add(row.correct);
        }
      }
      final buffer = StringBuffer()
        ..writeln('\n## Llamada ${index + 1}/$samples')
        ..writeln()
        ..writeln(sinD
            ? '| Nº | P | Dificultad | Pregunta Q | Respuesta R |'
            : '| Nº | P | D | Instrucción D | Dificultad | Pregunta Q | Respuesta R |')
        ..writeln(sinD
            ? '|---:|---|---|---|---|'
            : '|---:|---|---|---|---|---|---|');
      for (final row in rows) {
        if (sinD) {
          buffer.writeln(
            '| ${row.slot.number} | ${_cell(row.slot.pivot)} | '
            '${_cell(row.slot.difficulty)} | '
            '${_cell(row.question)} | ${_cell(row.correct)} |',
          );
        } else {
          buffer.writeln(
            '| ${row.slot.number} | ${_cell(row.slot.pivot)} | '
            '${row.slot.dimension.code} | '
            '${_cell(row.slot.dimension.instruction)} | '
            '${_cell(row.slot.difficulty)} | '
            '${_cell(row.question)} | ${_cell(row.correct)} |',
          );
        }
      }
      await questions.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
      final suffix = conU
          ? ' Bloque ${index ~/ 10 + 1}, U: ${historySent.length} R, '
              'coincidencias con U: ${repeatedAgainstU.length}.'
          : '';
      stdout.writeln(
        'Llamada ${index + 1}/$samples: 10 Q/R guardadas; '
        '${timer.elapsedMilliseconds} ms.$suffix',
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

  final summary = conU
      ? _lunaSummaryConU(observed)
      : sinD ? _lunaSummarySinD(observed) : _lunaSummary(observed);
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
      'hecho. Solo una comparación posterior sin D, manteniendo el mismo '
      'plan de pivotes y dificultades, permitirá aislar el efecto causal de D.');
  return buffer.toString();
}

/// Informe del control P + dificultad: ninguna D participa en los datos.
String _lunaSummarySinD(List<_Observed> observed) {
  final byPivot = <String, List<_Observed>>{};
  for (final item in observed) {
    byPivot.putIfAbsent(item.row.slot.pivot, () => <_Observed>[]).add(item);
  }
  final normalized = observed.map((item) => _answerKey(item.row.correct));
  final buffer = StringBuffer()
    ..writeln('## Diversidad de respuestas R sin D (comparación textual)')
    ..writeln()
    ..writeln('Filas: ${observed.length}. '
        'R diferentes globales: ${normalized.toSet().length}. '
        'Repeticiones globales: '
        '${observed.length - normalized.toSet().length}.')
    ..writeln()
    ..writeln('| Pivote P | Filas | R diferentes | R repetidas |')
    ..writeln('|---|---:|---:|---:|');
  final pivots = byPivot.keys.toList()..sort();
  var repeatedAcrossPivots = 0;
  final repeatedDetails = <String>[];
  for (final pivot in pivots) {
    final items = byPivot[pivot]!;
    final byAnswer = <String, List<_Observed>>{};
    for (final item in items) {
      byAnswer.putIfAbsent(
        _answerKey(item.row.correct), () => <_Observed>[],
      ).add(item);
    }
    repeatedAcrossPivots += items.length - byAnswer.length;
    buffer.writeln('| ${_cell(pivot)} | ${items.length} | '
        '${byAnswer.length} | ${items.length - byAnswer.length} |');
    for (final group in byAnswer.values.where((items) => items.length > 1)) {
      repeatedDetails.add('- ${_cell(pivot)} — '
          '**${_cell(group.first.row.correct)}**: '
          '${group.map((item) => 'llamada ${item.call}').join('; ')}.');
    }
  }
  buffer
    ..writeln()
    ..writeln('Respuestas repetidas dentro del mismo pivote: '
        '$repeatedAcrossPivots.')
    ..writeln()
    ..writeln('### Coincidencias de R dentro del mismo P');
  if (repeatedDetails.isEmpty) {
    buffer.writeln('Ninguna repetición textual dentro del mismo P.');
  } else {
    for (final detail in repeatedDetails) {
      buffer.writeln(detail);
    }
  }
  buffer.writeln('\nLa comparación ignora diferencias de mayúsculas y '
      'espacios; no identifica sinónimos ni equivalencias semánticas.');
  return buffer.toString();
}

/// Evalúa cada bloque de 10 llamadas sin penalizar repeticiones entre bloques.
String _lunaSummaryConU(List<_Observed> observed) {
  final buffer = StringBuffer()
    ..writeln('## Control P + dificultad con U')
    ..writeln()
    ..writeln('U recibe solo las R de las llamadas anteriores del mismo bloque.')
    ..writeln('Se reinicia en las llamadas 1, 11, 21, ..., 91.')
    ..writeln()
    ..writeln('| Bloque | Llamadas | Respuestas | R distintas | '
        'R repetidas desde llamadas anteriores (incumplen U) | '
        'R repetidas dentro de una llamada | R repetidas en el mismo P |')
    ..writeln('|---:|---:|---:|---:|---:|---:|---:|');
  var allPast = 0;
  var allCurrent = 0;
  var allSameP = 0;
  for (var start = 1; start <= observed.last.call; start += 10) {
    final block = observed.where(
      (item) => item.call >= start && item.call < start + 10,
    ).toList();
    final past = <String>{};
    final byPivot = <String>{};
    var pastDuplicates = 0;
    var currentDuplicates = 0;
    var samePivotDuplicates = 0;
    for (var call = start; call < start + 10; call++) {
      final current = <String>{};
      for (final item in block.where((row) => row.call == call)) {
        final normalized = _answerKey(item.row.correct);
        if (past.contains(normalized)) pastDuplicates++;
        if (!current.add(normalized)) currentDuplicates++;
        if (!byPivot.add('${item.row.slot.pivot}|$normalized')) {
          samePivotDuplicates++;
        }
      }
      past.addAll(current);
    }
    allPast += pastDuplicates;
    allCurrent += currentDuplicates;
    allSameP += samePivotDuplicates;
    buffer.writeln('| ${(start - 1) ~/ 10 + 1} | '
        '${block.map((item) => item.call).toSet().length} | '
        '${block.length} | ${past.length} | '
        '$pastDuplicates | $currentDuplicates | $samePivotDuplicates |');
  }
  buffer
    ..writeln()
    ..writeln('Repeticiones contra U: $allPast; '
        'dentro de llamada: $allCurrent; dentro del mismo P: $allSameP.')
    ..writeln('Las R repetidas entre bloques no incumplen U porque se reinicia.')
    ..writeln('La comparación es textual normalizada por mayúsculas y espacios; '
        'no unifica sinónimos ni hechos equivalentes.');
  return buffer.toString();
}

String _answerKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _cell(String value) =>
    value.replaceAll('|', r'\|').replaceAll(RegExp(r'\s+'), ' ').trim();
