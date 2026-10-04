import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'Quiz10_PROMPT_G.dart';

const String quiz10ReviewPrompt = r'''T := {{TEST}}

∀i ∈ {1,...,10}:

Oᵢ := {Rᵢ,d1ᵢ,d2ᵢ,d3ᵢ}

Cᵢ := {o ∈ Oᵢ : o responde correctamente a Qᵢ}

Aᵢ := {a ∈ Qᵢ : a requiere un referente contextual y referente(a,Qᵢ,Oᵢ) = ∅}

Cᵢ = {Rᵢ} ⇒ Δᵢ = ∅

Cᵢ ≠ {Rᵢ} ⇒ Δᵢ contiene únicamente correcciones de Rᵢ,d1ᵢ,d2ᵢ,d3ᵢ necesarias para que Cᵢ = {Rᵢ}.

Aᵢ = ∅ ⇒ Qᵢ' = Qᵢ

Aᵢ ≠ ∅ ⇒ Qᵢ' difiere de Qᵢ únicamente en sustituir cada a ∈ Aᵢ por un referente explícito inferido de Qᵢ,Oᵢ,Rᵢ.

Cualquier otra modificación de Qᵢ está prohibida.
''';

String quiz10ReviewItemLiteral(int number, Quiz10LunaRow row) => [
  '[$number]',
  'Q: ${row.question}',
  'R: ${row.correct}',
  'd1: ${row.distractors[0]}',
  'd2: ${row.distractors[1]}',
  'd3: ${row.distractors[2]}',
].join('\n');

String quiz10ReviewInput(List<Quiz10LunaRow> rows) =>
    quiz10ReviewPrompt.replaceAll(
      '{{TEST}}',
      [
        for (var i = 0; i < rows.length; i++)
          quiz10ReviewItemLiteral(i + 1, rows[i]),
      ].join('\n\n'),
    );

Map<String, Object?> quiz10ReviewSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['correcciones'],
  'properties': {
    'correcciones': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['n', 'campo', 'valor'],
        'properties': {
          'n': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 10,
          },
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

class Quiz10ReviewChange {
  const Quiz10ReviewChange({
    required this.field,
    required this.value,
  });

  final String field;
  final String value;
}

class Quiz10ReviewPatch {
  const Quiz10ReviewPatch({
    required this.number,
    required this.changes,
  });

  final int number;
  final List<Quiz10ReviewChange> changes;
}

class Quiz10ReviewCall {
  const Quiz10ReviewCall({
    required this.input,
    required this.rawText,
    required this.patches,
    required this.usage,
  });

  final String input;
  final String rawText;
  final List<Quiz10ReviewPatch> patches;
  final Map<String, dynamic>? usage;
}

class Quiz10ReviewResult {
  const Quiz10ReviewResult({
    required this.patches,
    required this.calls,
    required this.usage,
  });

  final List<Quiz10ReviewPatch> patches;
  final List<Quiz10ReviewCall> calls;
  final Map<String, dynamic>? usage;
}

List<Quiz10ReviewPatch> parseQuiz10ReviewOutput(String text) {
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

  final byNumber = <int, List<Quiz10ReviewChange>>{};
  final seen = <String>{};

  for (final rawChange in decoded['correcciones'] as List) {
    if (rawChange is! Map<String, dynamic> ||
        rawChange['n'] is! int ||
        rawChange['campo'] is! String ||
        rawChange['valor'] is! String) {
      throw const FormatException('Corrección estructuralmente inválida.');
    }

    final number = rawChange['n'] as int;
    final field = rawChange['campo'] as String;
    final key = '$number:$field';

    if (number < 1 ||
        number > 10 ||
        !const {'Q', 'R', 'd1', 'd2', 'd3'}.contains(field) ||
        !seen.add(key)) {
      throw const FormatException(
        'Cada campo revisable de cada ítem puede corregirse una sola vez.',
      );
    }

    byNumber
        .putIfAbsent(number, () => <Quiz10ReviewChange>[])
        .add(
          Quiz10ReviewChange(
            field: field,
            value: rawChange['valor'] as String,
          ),
        );
  }

  final numbers = byNumber.keys.toList()..sort();
  return List.unmodifiable([
    for (final number in numbers)
      Quiz10ReviewPatch(
        number: number,
        changes: List.unmodifiable(byNumber[number]!),
      ),
  ]);
}

final class AiQuiz10Reviewer {
  AiQuiz10Reviewer({
    required this.client,
    required this.model,
  });

  final AiAppsClient client;
  final String model;

  Future<Quiz10ReviewResult> review(List<Quiz10LunaRow> rows) async {
    if (rows.length != 10) {
      throw ArgumentError('La revisión requiere diez filas de G.');
    }

    final input = quiz10ReviewInput(rows);
    final response = await client
        .generate(
          application: 'quiz10-review',
          model: model,
          input: input,
          schemaName: 'quiz10_review_batch',
          schema: quiz10ReviewSchema(),
        )
        .timeout(const Duration(seconds: 120));

    final patches = parseQuiz10ReviewOutput(response.text);
    final call = Quiz10ReviewCall(
      input: input,
      rawText: response.text,
      patches: patches,
      usage: response.usage,
    );

    return Quiz10ReviewResult(
      patches: patches,
      calls: List.unmodifiable([call]),
      usage: response.usage,
    );
  }
}
