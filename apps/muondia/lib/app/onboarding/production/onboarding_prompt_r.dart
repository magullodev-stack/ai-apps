import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'onboarding_prompt_g.dart';

const String onboardingQuizReviewPrompt = r'''t := {{ITEM}}

O := {R,d1,d2,d3}

C := {o ∈ O : o responde correctamente a Q}

A := {a ∈ Q : a requiere un referente contextual y referente(a,Q,O) = ∅}

C = {R} ⇒ Δ = ∅

C ≠ {R} ⇒ Δ contiene únicamente correcciones de R,d1,d2,d3 necesarias para que C = {R}.

A = ∅ ⇒ Q' = Q

A ≠ ∅ ⇒ Q' difiere de Q únicamente en sustituir cada a ∈ A por un referente explícito inferido de Q,O,R.

Cualquier otra modificación de Q está prohibida.
''';

String onboardingQuizReviewItemLiteral(OnboardingQuizLunaRow row) => [
  'Q: ${row.question}',
  'R: ${row.correct}',
  'd1: ${row.distractors[0]}',
  'd2: ${row.distractors[1]}',
  'd3: ${row.distractors[2]}',
].join('\n');

String onboardingQuizReviewInput(OnboardingQuizLunaRow row) =>
    onboardingQuizReviewPrompt.replaceAll('{{ITEM}}', onboardingQuizReviewItemLiteral(row));

Map<String, Object?> onboardingQuizReviewSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['correcciones'],
  'properties': {
    'correcciones': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['campo', 'valor'],
        'properties': {
          'campo': {
            'type': 'string',
            'enum': ['Q', 'R', 'd1', 'd2', 'd3'],
          },
          'valor': {'type': 'string'},
        },
      },
    },
  },
};

class OnboardingQuizReviewChange {
  const OnboardingQuizReviewChange({
    required this.field,
    required this.value,
  });

  final String field;
  final String value;
}

class OnboardingQuizReviewPatch {
  const OnboardingQuizReviewPatch({
    required this.number,
    required this.changes,
  });

  final int number;
  final List<OnboardingQuizReviewChange> changes;
}

class OnboardingQuizReviewCall {
  const OnboardingQuizReviewCall({
    required this.number,
    required this.input,
    required this.rawText,
    required this.changes,
    required this.usage,
  });

  final int number;
  final String input;
  final String rawText;
  final List<OnboardingQuizReviewChange> changes;
  final Map<String, dynamic>? usage;
}

class OnboardingQuizReviewResult {
  const OnboardingQuizReviewResult({
    required this.patches,
    required this.calls,
    required this.usage,
  });

  final List<OnboardingQuizReviewPatch> patches;
  final List<OnboardingQuizReviewCall> calls;
  final Map<String, dynamic>? usage;
}

List<OnboardingQuizReviewChange> parseOnboardingQuizReviewItemOutput(String text) {
  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } catch (error) {
    throw FormatException('JSON de revisión inválido: $error');
  }

  if (decoded is! Map<String, dynamic> ||
      decoded['correcciones'] is! List) {
    throw const FormatException(
      'La revisión no conserva la estructura correcciones.',
    );
  }

  final changes = <OnboardingQuizReviewChange>[];
  final seenFields = <String>{};

  for (final rawChange in decoded['correcciones'] as List) {
    if (rawChange is! Map<String, dynamic> ||
        rawChange['campo'] is! String ||
        rawChange['valor'] is! String) {
      throw const FormatException('Corrección estructuralmente inválida.');
    }

    final field = rawChange['campo'] as String;
    if (!const {'Q', 'R', 'd1', 'd2', 'd3'}.contains(field) ||
        !seenFields.add(field)) {
      throw const FormatException(
        'Cada campo revisable puede corregirse una sola vez.',
      );
    }

    changes.add(
      OnboardingQuizReviewChange(
        field: field,
        value: rawChange['valor'] as String,
      ),
    );
  }

  return List.unmodifiable(changes);
}

final class AiOnboardingQuizReviewer {
  AiOnboardingQuizReviewer({
    required this.client,
    required this.model,
  });

  final AiAppsClient client;
  final String model;

  Future<OnboardingQuizReviewResult> review(List<OnboardingQuizLunaRow> rows) async {
    if (rows.length != 10) {
      throw ArgumentError('La revisión requiere diez filas de G.');
    }

    final calls = await Future.wait([
      for (var i = 0; i < rows.length; i++)
        _reviewOne(i + 1, rows[i]),
    ]);

    final patches = [
      for (final call in calls)
        if (call.changes.isNotEmpty)
          OnboardingQuizReviewPatch(
            number: call.number,
            changes: call.changes,
          ),
    ];

    return OnboardingQuizReviewResult(
      patches: List.unmodifiable(patches),
      calls: List.unmodifiable(calls),
      usage: _aggregateUsage(calls),
    );
  }

  Future<OnboardingQuizReviewCall> _reviewOne(
    int number,
    OnboardingQuizLunaRow row,
  ) async {
    final input = onboardingQuizReviewInput(row);
    final response = await client
        .generate(
          application: 'onboardingQuiz-review',
          model: model,
          input: input,
          schemaName: 'onboardingQuiz_review_item',
          schema: onboardingQuizReviewSchema(),
        )
        .timeout(const Duration(seconds: 120));

    return OnboardingQuizReviewCall(
      number: number,
      input: input,
      rawText: response.text,
      changes: parseOnboardingQuizReviewItemOutput(response.text),
      usage: response.usage,
    );
  }

  Map<String, dynamic>? _aggregateUsage(List<OnboardingQuizReviewCall> calls) {
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
