import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'quiz10_DART_Pi+Di.dart';

// Una unidad de generación = una posición del test.
// Dart fija P, D, dificultad e H; Luna devuelve F, Q, R y tres distractores.
// Las diez unidades del Quiz10 se ejecutan simultáneamente.

const String quiz10LunaPrompt = r'''## Entrada

P := {{P}}
D := {{D}}
Dificultad := {{Dificultad}}

H := {{H}}

D → (
ρ := {{rho}}
π := {{pi}}
τ := {{tau}}
Γ := {{gamma}}
)


## Generación

Elige un hecho factual f de P tal que:

f instancia ρ

Γ(f) = verdadero

F := f

R := π(f)

type(R) ∈ τ

(F, R) ∉ H

Formula Q a partir de:

f[π := ?]

Genera tres distractores:

A := {a₁, a₂, a₃}

Para cada aᵢ:

type(aᵢ) ∈ τ

Γ(f[π := aᵢ]) = verdadero

f[π := aᵢ] = falso

aᵢ debe corresponder a un hecho real del mismo contexto que pueda confundirse con R.

difficulty(Q, R, A | P, D) = Dificultad


## Salida

| P | D | F | Q | R | A |
|---|---|---|---|---|---|''';

String _historyLiteral(List<Quiz10HistoryEntry> history) {
  if (history.isEmpty) return '∅';
  return '{${history.map((entry) => '(F := ${jsonEncode(entry.fact)}, R := ${jsonEncode(entry.answer)})').join(', ')}}';
}

String quiz10LunaInput(
  Quiz10Pair slot,
  List<Quiz10HistoryEntry> history,
) {
  return quiz10LunaPrompt
      .replaceAll('{{P}}', slot.pivot.name)
      .replaceAll('{{D}}', slot.dimension.code)
      .replaceAll('{{Dificultad}}', slot.difficulty)
      .replaceAll('{{H}}', _historyLiteral(history))
      .replaceAll('{{rho}}', slot.dimension.relation)
      .replaceAll('{{pi}}', slot.dimension.projection)
      .replaceAll('{{tau}}', slot.dimension.expectedType)
      .replaceAll('{{gamma}}', slot.dimension.constraints);
}

Map<String, Object?> quiz10LunaSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['P', 'D', 'F', 'Q', 'R', 'A'],
  'properties': {
    'P': {'type': 'string'},
    'D': {'type': 'string'},
    'F': {'type': 'string'},
    'Q': {'type': 'string'},
    'R': {'type': 'string'},
    'A': {
      'type': 'array',
      'items': {'type': 'string'},
    },
  },
};

String _normalized(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class Quiz10LunaRow {
  const Quiz10LunaRow({
    required this.slot,
    required this.fact,
    required this.question,
    required this.correct,
    required this.distractors,
  });

  final Quiz10Pair slot;
  final String fact;
  final String question;
  final String correct;
  final List<String> distractors;
}

Quiz10LunaRow parseQuiz10LunaRowOutput(
  String text,
  Quiz10Pair slot, {
  List<Quiz10HistoryEntry> history = const [],
}) {
  FormatException invalid(String cause) => FormatException(cause);

  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } catch (error) {
    throw invalid('JSON inválido: $error');
  }

  if (decoded is! Map<String, dynamic>) {
    throw invalid('La salida no es un objeto JSON.');
  }
  if (decoded['P'] is! String) throw invalid('P ausente o no textual.');
  if (decoded['D'] is! String) throw invalid('D ausente o no textual.');
  if (decoded['F'] is! String) throw invalid('F ausente o no textual.');
  if (decoded['Q'] is! String) throw invalid('Q ausente o no textual.');
  if (decoded['R'] is! String) throw invalid('R ausente o no textual.');
  if (decoded['A'] is! List) throw invalid('A ausente o no es una lista.');

  final pivot = (decoded['P'] as String).trim();
  final dimension = (decoded['D'] as String).trim();
  final fact = (decoded['F'] as String).trim();
  final question = (decoded['Q'] as String).trim();
  final correct = (decoded['R'] as String).trim();
  final rawDistractors = decoded['A'] as List;

  if (_normalized(pivot) != _normalized(slot.pivot.name)) {
    throw invalid('P devuelta "$pivot" no coincide con ${slot.pivot.name}.');
  }

  final normalizedDimension = _normalized(dimension);
  final normalizedDimensionCode = _normalized(slot.dimension.code);
  if (normalizedDimension != normalizedDimensionCode &&
      !normalizedDimension.startsWith('$normalizedDimensionCode[')) {
    throw invalid(
      'D devuelta "$dimension" no coincide con ${slot.dimension.code}.',
    );
  }

  if (fact.isEmpty) throw invalid('F está vacío.');
  if (question.isEmpty) throw invalid('Q está vacía.');
  if (correct.isEmpty) throw invalid('R está vacía.');
  if (rawDistractors.length != 3) {
    throw invalid(
      'A contiene ${rawDistractors.length} distractores; se esperaban 3.',
    );
  }
  if (rawDistractors.any((value) => value is! String)) {
    throw invalid('A contiene un distractor no textual.');
  }

  final distractors = [
    for (final value in rawDistractors) (value as String).trim(),
  ];

  if (distractors.any((value) => value.isEmpty)) {
    throw invalid('A contiene un distractor vacío.');
  }
  if (distractors.map(_normalized).toSet().length != 3) {
    throw invalid('A contiene distractores duplicados.');
  }
  if (distractors.any(
    (value) => _normalized(value) == _normalized(correct),
  )) {
    throw invalid('A contiene la propia R.');
  }

  final repeatedPair = history.any(
    (entry) =>
        _normalized(entry.fact) == _normalized(fact) &&
        _normalized(entry.answer) == _normalized(correct),
  );
  if (repeatedPair) {
    throw invalid('H ya contiene el par factual (F,R).');
  }

  return Quiz10LunaRow(
    slot: slot,
    fact: fact,
    question: question,
    correct: correct,
    distractors: List.unmodifiable(distractors),
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
  });

  final Quiz10Pair slot;
  final String stage;
  final Object cause;
}

class Quiz10LunaPackException implements Exception {
  const Quiz10LunaPackException({
    required this.failures,
    required this.usage,
    required this.completedCalls,
  });

  final List<Quiz10LunaFailure> failures;
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

  // Histórico factual (F,R) por cruce P×D durante la vida de esta instancia.
  final Map<Quiz10HistoryKey, List<Quiz10HistoryEntry>>
      _historyByPivotDimension = {};

  @override
  Future<List<Quiz10LunaRow>> generate(List<Quiz10Pair> plan) async {
    final response = await generateResponse(plan);
    return parseQuiz10LunaOutput(response.text, plan);
  }

  Future<AiGeneration> generateResponse(List<Quiz10Pair> plan) async {
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
            history: histories[i],
          ),
        );
      } catch (error) {
        failures.add(
          Quiz10LunaFailure(
            slot: plan[i],
            stage: 'validación',
            cause: error,
          ),
        );
      }
    }

    if (failures.isNotEmpty) {
      throw Quiz10LunaPackException(
        failures: List.unmodifiable(failures),
        usage: _aggregateUsage(calls),
        completedCalls: calls.length,
      );
    }

    // H solo avanza cuando el pack completo de diez unidades es válido.
    for (final row in rows) {
      _historyByPivotDimension
          .putIfAbsent(
            quiz10HistoryKey(row.slot),
            () => <Quiz10HistoryEntry>[],
          )
          .add((fact: row.fact, answer: row.correct));
    }

    return AiGeneration(
      text: jsonEncode({
        'preguntas': [
          for (final row in rows)
            {
              'P': row.slot.pivot.name,
              'D': row.slot.dimension.code,
              'F': row.fact,
              'Q': row.question,
              'R': row.correct,
              'A': row.distractors,
            },
        ],
      }),
      usage: _aggregateUsage(calls),
    );
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
