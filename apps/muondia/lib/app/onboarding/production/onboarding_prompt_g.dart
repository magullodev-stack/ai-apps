import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'onboarding_dimensions.dart';

// Una unidad de generación = una posición del test.
// Dart fija P, D e H; G devuelve F, Q, cuatro opciones O y la posición C.
// F es un andamiaje factual efímero de G: no entra en H, R ni en el test final.
// Las diez unidades de G del OnboardingQuiz se ejecutan simultáneamente.

const String onboardingQuizLunaPrompt = r'''P := {{P}}
D := {{D}}
I_D := {{instruction}}
H := {{H}}

(P,I_D,H) → F
(F,I_D) → Q
(F,Q) → O

F: afirmación factual autónoma mínima de cultura general generalista, no especializada ni de detalle.

I_D define la relación semántica que Q debe realizar, no su redacción.

Q es concisa, directa y autosuficiente, realiza I_D y tiene como máximo 160 caracteres.

F no forma parte del contexto disponible al responder Q.

Todo referente contextual de Q se resuelve en Q u O, nunca en F.

O := {o₁,o₂,o₃,o₄}, opciones distintas, plausibles, homogéneas y concisas; cada opción tiene como máximo 70 caracteres.

C := posición de la única opción correcta en O.

R := O_C

Q no contiene R ni una pista léxica evidente de R por forma, raíz, abreviación, símbolo, derivación o semejanza.

∀(Qᵢ,Rᵢ) ∈ H, Q pregunta un conocimiento materialmente distinto de Qᵢ.

R ∉ {R₁,...,Rₙ}
''';

String _historyLiteral(List<OnboardingQuizHistoryEntry> history) {
  if (history.isEmpty) return '∅';
  return '{${history.map((entry) => '(Q := ${jsonEncode(entry.question)}, R := ${jsonEncode(entry.answer)})').join(', ')}}';
}

String onboardingQuizLunaInput(
  OnboardingQuizPair slot,
  List<OnboardingQuizHistoryEntry> history,
) {
  return onboardingQuizLunaPrompt
      .replaceAll('{{P}}', slot.pivot.name)
      .replaceAll('{{D}}', slot.dimension.code)
      .replaceAll('{{instruction}}', slot.dimension.instruction)
      .replaceAll('{{H}}', _historyLiteral(history));
}

Map<String, Object?> onboardingQuizLunaSchema() => {
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

class OnboardingQuizLunaRow {
  const OnboardingQuizLunaRow({
    required this.slot,
    required this.returnedPivot,
    required this.returnedDimension,
    required this.fact,
    required this.question,
    required this.options,
    required this.correctPosition,
    required this.rawText,
  });

  final OnboardingQuizPair slot;
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

OnboardingQuizLunaRow parseOnboardingQuizLunaRowOutput(
  String text,
  OnboardingQuizPair slot,
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

  return OnboardingQuizLunaRow(
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

List<OnboardingQuizLunaRow> parseOnboardingQuizLunaOutput(
  String text,
  List<OnboardingQuizPair> plan,
) {
  const invalid = FormatException(
    'La respuesta agregada de Luna no cumple el formato de OnboardingQuiz.',
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
        parseOnboardingQuizLunaRowOutput(jsonEncode(rows[i]), plan[i])
      else
        throw invalid,
  ]);
}

abstract interface class OnboardingQuizLunaGenerator {
  Future<List<OnboardingQuizLunaRow>> generate(
    List<OnboardingQuizPair> plan,
  );
}

class OnboardingQuizLunaFailure {
  const OnboardingQuizLunaFailure({
    required this.slot,
    required this.stage,
    required this.cause,
    this.rawText,
  });

  final OnboardingQuizPair slot;
  final String stage;
  final Object cause;
  final String? rawText;
}

class OnboardingQuizLunaPackException implements Exception {
  const OnboardingQuizLunaPackException({
    required this.failures,
    required this.rows,
    required this.usage,
    required this.completedCalls,
  });

  final List<OnboardingQuizLunaFailure> failures;
  final List<OnboardingQuizLunaRow> rows;
  final Map<String, dynamic>? usage;
  final int completedCalls;

  @override
  String toString() =>
      'OnboardingQuizLunaPackException: ${failures.length} fila(s) fallida(s).';
}

final class AiOnboardingQuizLunaGenerator implements OnboardingQuizLunaGenerator {
  AiOnboardingQuizLunaGenerator({
    required this.client,
    required this.model,
  });

  final AiAppsClient client;
  final String model;

  // Preguntas y respuestas finales ya usadas por cruce P×D.
  final Map<OnboardingQuizHistoryKey, List<OnboardingQuizHistoryEntry>>
      _historyByPivotDimension = {};

  @override
  Future<List<OnboardingQuizLunaRow>> generate(List<OnboardingQuizPair> plan) async {
    final response = await generateResponse(plan);
    return parseOnboardingQuizLunaOutput(response.text, plan);
  }

  Future<AiGeneration> generateResponse(
    List<OnboardingQuizPair> plan, {
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
        List<OnboardingQuizHistoryEntry>.unmodifiable(
          _historyByPivotDimension[onboardingQuizHistoryKey(slot)] ??
              const <OnboardingQuizHistoryEntry>[],
        ),
    ];

    final attempts = await Future.wait([
      for (var i = 0; i < plan.length; i++)
        _attemptRowResponse(plan[i], histories[i]),
    ]);

    final calls = <AiGeneration>[];
    final rows = <OnboardingQuizLunaRow>[];
    final failures = <OnboardingQuizLunaFailure>[];

    for (var i = 0; i < plan.length; i++) {
      final attempt = attempts[i];
      if (attempt.response == null) {
        failures.add(
          OnboardingQuizLunaFailure(
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
          parseOnboardingQuizLunaRowOutput(
            attempt.response!.text,
            plan[i],
          ),
        );
      } catch (error) {
        failures.add(
          OnboardingQuizLunaFailure(
            slot: plan[i],
            stage: 'estructura',
            cause: error,
            rawText: attempt.response!.text,
          ),
        );
      }
    }

    if (failures.isNotEmpty) {
      throw OnboardingQuizLunaPackException(
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
    List<OnboardingQuizLunaRow> rows,
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
            onboardingQuizHistoryKey(row.slot),
            () => <OnboardingQuizHistoryEntry>[],
          )
          .add((
            question: reviewedQuestions[i],
            answer: reviewedAnswers[i],
          ));
    }
  }

  Future<({AiGeneration? response, Object? error})> _attemptRowResponse(
    OnboardingQuizPair slot,
    List<OnboardingQuizHistoryEntry> history,
  ) async {
    try {
      final response = await _generateRowResponse(slot, history);
      return (response: response, error: null);
    } catch (error) {
      return (response: null, error: error);
    }
  }

  Future<AiGeneration> _generateRowResponse(
    OnboardingQuizPair slot,
    List<OnboardingQuizHistoryEntry> history,
  ) {
    return client.generate(
      application: 'onboardingQuiz',
      model: model,
      input: onboardingQuizLunaInput(slot, history),
      schemaName: 'onboardingQuiz_luna_item',
      schema: onboardingQuizLunaSchema(),
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
