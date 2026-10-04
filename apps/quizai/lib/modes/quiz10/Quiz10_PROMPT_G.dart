import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'quiz10_DART_Pi+Di.dart';

// Una unidad de generación = una posición del test.
// Dart fija P, D e H; G devuelve F, Q, cuatro opciones O y la posición C.
// F es un andamiaje factual efímero de G: no entra en H, R ni en el test final.
// Las diez unidades de G del Quiz10 se ejecutan simultáneamente.

const String quiz10LunaPrompt = r'''P := {{P}}
D := {{D}}
I_D := {{instruction}}
H := {{H}}

(P,I_D,H) → F
(F,I_D) → Q
(F,Q) → O

F: base factual mínima de cultura general generalista, no especializada ni de detalle.

I_D define la relación semántica que Q debe realizar, no su redacción.

Q contiene únicamente el contexto necesario para interpretarse sin F ni H y realizar I_D.

O := {o₁,o₂,o₃,o₄}, opciones distintas, plausibles, homogéneas y concisas.

C := posición de la única opción correcta en O.

R := O_C

Q no contiene R ni una pista léxica evidente de R por forma, raíz, abreviación, símbolo, derivación o semejanza.

∀(Qᵢ,Rᵢ) ∈ H, Q pregunta un conocimiento materialmente distinto de Qᵢ.

R ∉ {R₁,...,Rₙ}
''';

String _historyLiteral(List<Quiz10HistoryEntry> history) {
  if (history.isEmpty) return '∅';
  return '{${history.map((entry) => '(Q := ${jsonEncode(entry.question)}, R := ${jsonEncode(entry.answer)})').join(', ')}}';
}

String quiz10LunaInput(
  Quiz10Pair slot,
  List<Quiz10HistoryEntry> history,
) {
  return quiz10LunaPrompt
      .replaceAll('{{P}}', slot.pivot.name)
      .replaceAll('{{D}}', slot.dimension.code)
      .replaceAll('{{instruction}}', slot.dimension.instruction)
      .replaceAll('{{H}}', _historyLiteral(history));
}

Map<String, Object?> quiz10LunaSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['P', 'D', 'F', 'Q', 'O', 'C'],
  'properties': {
    'P': {'type': 'string'},
    'D': {'type': 'string'},
    'F': {'type': 'string'},
    'Q': {'type': 'string'},
    'O': {
      'type': 'object',
      'additionalProperties': false,
      'required': ['o1', 'o2', 'o3', 'o4'],
      'properties': {
        'o1': {'type': 'string'},
        'o2': {'type': 'string'},
        'o3': {'type': 'string'},
        'o4': {'type': 'string'},
      },
    },
    'C': {
      'type': 'integer',
      'enum': [1, 2, 3, 4],
    },
  },
};

class Quiz10LunaRow {
  const Quiz10LunaRow({
    required this.slot,
    required this.returnedPivot,
    required this.returnedDimension,
    required this.fact,
    required this.question,
    required this.options,
    required this.correctPosition,
    required this.rawText,
  });

  final Quiz10Pair slot;
  final String returnedPivot;
  final String returnedDimension;
  final String fact;
  final String question;
  final List<String> options;
  final int correctPosition;
  final String rawText;

  String get correct {
    final index = correctPosition - 1;
    if (index < 0 || index >= options.length) return '';
    return options[index];
  }

  List<String> get distractors {
    final index = correctPosition - 1;
    return List.unmodifiable([
      for (var i = 0; i < options.length; i++)
        if (i != index) options[i],
    ]);
  }
}

Quiz10LunaRow parseQuiz10LunaRowOutput(
  String text,
  Quiz10Pair slot,
) {
  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } catch (error) {
    throw FormatException('JSON inválido: $error');
  }

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('La salida no es un objeto JSON.');
  }
  if (decoded['P'] is! String ||
      decoded['D'] is! String ||
      decoded['F'] is! String ||
      decoded['Q'] is! String ||
      decoded['O'] is! Map<String, dynamic> ||
      decoded['C'] is! int) {
    throw const FormatException(
      'La salida no conserva la estructura P,D,F,Q,O,C esperada.',
    );
  }

  final rawOptions = decoded['O'] as Map<String, dynamic>;
  const keys = ['o1', 'o2', 'o3', 'o4'];
  if (keys.any((key) => rawOptions[key] is! String)) {
    throw const FormatException('O no contiene cuatro opciones textuales.');
  }

  return Quiz10LunaRow(
    slot: slot,
    returnedPivot: decoded['P'] as String,
    returnedDimension: decoded['D'] as String,
    fact: decoded['F'] as String,
    question: decoded['Q'] as String,
    options: List.unmodifiable([
      for (final key in keys) rawOptions[key] as String,
    ]),
    correctPosition: decoded['C'] as int,
    rawText: text,
  );
}

List<Quiz10LunaRow> parseQuiz10LunaOutput(
  String text,
  List<Quiz10Pair> plan,
) {
  const invalid = FormatException(
    'La respuesta agregada de Luna no cumple el formato de Quiz10.',
  );

  if (plan.length != 10) throw invalid;

  final decoded = jsonDecode(text);

  if (decoded is! Map<String, dynamic> ||
      decoded['preguntas'] is! List) {
    throw invalid;
  }

  final rows = decoded['preguntas'] as List;

  if (rows.length != 10) throw invalid;

  return List.unmodifiable([
    for (var i = 0; i < 10; i++)
      if (rows[i] is Map<String, dynamic>)
        parseQuiz10LunaRowOutput(jsonEncode(rows[i]), plan[i])
      else
        throw invalid,
  ]);
}

abstract interface class Quiz10LunaGenerator {
  Future<List<Quiz10LunaRow>> generate(
    List<Quiz10Pair> plan,
  );
}

class Quiz10LunaFailure {
  const Quiz10LunaFailure({
    required this.slot,
    required this.stage,
    required this.cause,
    this.rawText,
  });

  final Quiz10Pair slot;
  final String stage;
  final Object cause;
  final String? rawText;
}

class Quiz10LunaPackException implements Exception {
  const Quiz10LunaPackException({
    required this.failures,
    required this.rows,
    required this.usage,
    required this.completedCalls,
  });

  final List<Quiz10LunaFailure> failures;
  final List<Quiz10LunaRow> rows;
  final Map<String, dynamic>? usage;
  final int completedCalls;

  @override
  String toString() =>
      'Quiz10LunaPackException: ${failures.length} fila(s) fallida(s).';
}

final class AiQuiz10LunaGenerator implements Quiz10LunaGenerator {
  AiQuiz10LunaGenerator({
    required this.client,
    required this.model,
  });

  final AiAppsClient client;
  final String model;

  // Preguntas y respuestas finales ya usadas por cruce P×D.
  final Map<Quiz10HistoryKey, List<Quiz10HistoryEntry>>
      _historyByPivotDimension = {};

  @override
  Future<List<Quiz10LunaRow>> generate(List<Quiz10Pair> plan) async {
    final response = await generateResponse(plan);
    return parseQuiz10LunaOutput(response.text, plan);
  }

  Future<AiGeneration> generateResponse(
    List<Quiz10Pair> plan, {
    bool commitHistory = true,
  }) async {
    if (plan.length != 10) {
      throw ArgumentError('Luna requiere diez unidades P-D.');
    }
    if (model.trim().isEmpty ||
        client.authorization.trim().isEmpty) {
      throw StateError('Falta configurar Luna.');
    }

    final histories = [
      for (final slot in plan)
        List<Quiz10HistoryEntry>.unmodifiable(
          _historyByPivotDimension[quiz10HistoryKey(slot)] ??
              const <Quiz10HistoryEntry>[],
        ),
    ];

    final attempts = await Future.wait([
      for (var i = 0; i < plan.length; i++)
        _attemptRowResponse(plan[i], histories[i]),
    ]);

    final calls = <AiGeneration>[];
    final rows = <Quiz10LunaRow>[];
    final failures = <Quiz10LunaFailure>[];

    for (var i = 0; i < plan.length; i++) {
      final attempt = attempts[i];
      if (attempt.response == null) {
        failures.add(
          Quiz10LunaFailure(
            slot: plan[i],
            stage: 'llamada',
            cause: attempt.error ??
                StateError('La llamada no devolvió respuesta.'),
          ),
        );
        continue;
      }

      calls.add(attempt.response!);
      try {
        rows.add(
          parseQuiz10LunaRowOutput(
            attempt.response!.text,
            plan[i],
          ),
        );
      } catch (error) {
        failures.add(
          Quiz10LunaFailure(
            slot: plan[i],
            stage: 'estructura',
            cause: error,
            rawText: attempt.response!.text,
          ),
        );
      }
    }

    if (failures.isNotEmpty) {
      throw Quiz10LunaPackException(
        failures: List.unmodifiable(failures),
        rows: List.unmodifiable(rows),
        usage: _aggregateUsage(calls),
        completedCalls: calls.length,
      );
    }

    if (commitHistory) {
      commitReviewedQuestions(
        rows,
        rows.map((row) => row.question).toList(growable: false),
        rows.map((row) => row.correct).toList(growable: false),
      );
    }

    return AiGeneration(
      text: jsonEncode({
        'preguntas': [
          for (final row in rows) jsonDecode(row.rawText),
        ],
      }),
      usage: _aggregateUsage(calls),
    );
  }

  void commitReviewedQuestions(
    List<Quiz10LunaRow> rows,
    List<String> reviewedQuestions,
    List<String> reviewedAnswers,
  ) {
    if (rows.length != reviewedQuestions.length ||
        rows.length != reviewedAnswers.length) {
      throw ArgumentError('Filas, preguntas y respuestas revisadas no coinciden.');
    }

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      _historyByPivotDimension
          .putIfAbsent(
            quiz10HistoryKey(row.slot),
            () => <Quiz10HistoryEntry>[],
          )
          .add((
            question: reviewedQuestions[i],
            answer: reviewedAnswers[i],
          ));
    }
  }

  Future<({AiGeneration? response, Object? error})> _attemptRowResponse(
    Quiz10Pair slot,
    List<Quiz10HistoryEntry> history,
  ) async {
    try {
      final response = await _generateRowResponse(slot, history);
      return (response: response, error: null);
    } catch (error) {
      return (response: null, error: error);
    }
  }

  Future<AiGeneration> _generateRowResponse(
    Quiz10Pair slot,
    List<Quiz10HistoryEntry> history,
  ) {
    return client.generate(
      application: 'quiz10',
      model: model,
      input: quiz10LunaInput(slot, history),
      schemaName: 'quiz10_luna_item',
      schema: quiz10LunaSchema(),
    ).timeout(const Duration(seconds: 120));
  }

  Map<String, dynamic>? _aggregateUsage(List<AiGeneration> calls) {
    if (calls.isEmpty) return null;

    const keys = [
      'inputTokens',
      'outputTokens',
      'totalTokens',
      'reasoningTokens',
      'cachedInputTokens',
    ];
    final result = <String, dynamic>{};

    for (final key in keys) {
      var sum = 0;
      var complete = true;

      for (final call in calls) {
        final value = call.usage?[key];
        if (value is! int || value < 0) {
          complete = false;
          break;
        }
        sum += value;
      }

      if (complete) result[key] = sum;
    }

    return result.isEmpty ? null : result;
  }
}
