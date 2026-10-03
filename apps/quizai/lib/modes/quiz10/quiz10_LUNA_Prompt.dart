import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'quiz10_DART_Pi+Di.dart';

// Una unidad de generación = una posición del test.
// Dart fija i, P, D, dificultad e H; Luna devuelve Q, R y tres distractores.
// Las diez unidades del Quiz10 se ejecutan simultáneamente.

const String quiz10LunaPrompt = r'''## Entrada

i := {{i}}
P := {{P}}
D := {{D}}
Dificultad := {{Dificultad}}

H := {{H}}

D = ρ[π]

## Generación

Genera una pregunta de cultura general tipo «¿Quién quiere ser millonario?».

Elige un hecho factual f compatible con P y ρ.

R := π(f)

R no puede pertenecer a H.

Formula Q sin utilizar palabras de R.

Genera tres distractores A := {a₁,a₂,a₃}.

Cada distractor debe:
- ser del mismo tipo que R;
- ser falso para Q;
- corresponder a un hecho real del mismo contexto que pueda confundirse con R.

El ítem completo (Q,R,A) debe tener dificultad {{Dificultad}}.

## Salida

P, Q, R, A''';

String _historyLiteral(List<String> history) {
  if (history.isEmpty) return '∅';
  return '{${history.map(jsonEncode).join(', ')}}';
}

String quiz10LunaInput(
  Quiz10Pair slot,
  List<String> history,
) {
  return quiz10LunaPrompt
      .replaceAll('{{i}}', slot.number.toString())
      .replaceAll('{{P}}', slot.pivot.name)
      .replaceAll(
        '{{D}}',
        '${slot.dimension.code}[${slot.dimension.instruction}]',
      )
      .replaceAll('{{Dificultad}}', slot.difficulty)
      .replaceAll('{{H}}', _historyLiteral(history));
}

Map<String, Object?> quiz10LunaSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['P', 'Q', 'R', 'A'],
  'properties': {
    'P': {'type': 'string'},
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
    required this.question,
    required this.correct,
    required this.distractors,
  });

  final Quiz10Pair slot;
  final String question;
  final String correct;
  final List<String> distractors;
}

Quiz10LunaRow parseQuiz10LunaRowOutput(
  String text,
  Quiz10Pair slot, {
  List<String> history = const [],
}) {
  const invalid = FormatException(
    'La respuesta de Luna no cumple el formato de una unidad de Quiz10.',
  );

  final decoded = jsonDecode(text);

  if (decoded is! Map<String, dynamic> ||
      decoded['P'] is! String ||
      decoded['Q'] is! String ||
      decoded['R'] is! String ||
      decoded['A'] is! List) {
    throw invalid;
  }

  final pivot = (decoded['P'] as String).trim();
  final question = (decoded['Q'] as String).trim();
  final correct = (decoded['R'] as String).trim();
  final rawDistractors = decoded['A'] as List;

  if (_normalized(pivot) != _normalized(slot.pivot.name) ||
      question.isEmpty ||
      correct.isEmpty ||
      rawDistractors.length != 3 ||
      rawDistractors.any((value) => value is! String)) {
    throw invalid;
  }

  final distractors = [
    for (final value in rawDistractors) (value as String).trim(),
  ];

  if (distractors.any((value) => value.isEmpty) ||
      distractors.map(_normalized).toSet().length != 3 ||
      distractors.any(
        (value) => _normalized(value) == _normalized(correct),
      ) ||
      history.any(
        (value) => _normalized(value) == _normalized(correct),
      )) {
    throw invalid;
  }

  return Quiz10LunaRow(
    slot: slot,
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

final class AiQuiz10LunaGenerator implements Quiz10LunaGenerator {
  AiQuiz10LunaGenerator({
    required this.client,
    required this.model,
  });

  final AiAppsClient client;
  final String model;

  // Histórico de respuestas por cruce P×D durante la vida de esta instancia.
  final Map<Quiz10HistoryKey, List<String>> _historyByPivotDimension = {};

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
        List<String>.unmodifiable(
          _historyByPivotDimension[quiz10HistoryKey(slot)] ??
              const <String>[],
        ),
    ];

    final calls = await Future.wait([
      for (var i = 0; i < plan.length; i++)
        _generateRowResponse(plan[i], histories[i]),
    ]);

    final rows = <Quiz10LunaRow>[
      for (var i = 0; i < plan.length; i++)
        parseQuiz10LunaRowOutput(
          calls[i].text,
          plan[i],
          history: histories[i],
        ),
    ];

    // H solo avanza cuando el pack completo de diez unidades es válido.
    for (final row in rows) {
      _historyByPivotDimension
          .putIfAbsent(quiz10HistoryKey(row.slot), () => <String>[])
          .add(row.correct);
    }

    return AiGeneration(
      text: jsonEncode({
        'preguntas': [
          for (final row in rows)
            {
              'P': row.slot.pivot.name,
              'Q': row.question,
              'R': row.correct,
              'A': row.distractors,
            },
        ],
      }),
      usage: _aggregateUsage(calls),
    );
  }

  Future<AiGeneration> _generateRowResponse(
    Quiz10Pair slot,
    List<String> history,
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
