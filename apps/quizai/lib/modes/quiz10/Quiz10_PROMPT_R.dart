import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'Quiz10_PROMPT_G.dart';

const String quiz10ReviewPrompt = r'''t := {{ITEM}}

Δ := correcciones

t' := aplicar(Δ,t)

min |Δ|

sujeto a:

R' es la única respuesta correcta a Q'.

Q' realiza la relación semántica definida por I_D.

Todo referente necesario para interpretar Q' aparece explícitamente en Q'.

Q' no contiene R' ni una pista léxica evidente de R' por forma, raíz, abreviación, símbolo, derivación o semejanza.

∀(campo,valor) ∈ Δ, valor ≠ t[campo].
''';

String quiz10ReviewItemLiteral(Quiz10LunaRow row) => [
  'P: ${row.returnedPivot}',
  'I_D: ${row.slot.dimension.instruction}',
  'Q: ${row.question}',
  'R: ${row.correct}',
  'd1: ${row.distractors[0]}',
  'd2: ${row.distractors[1]}',
  'd3: ${row.distractors[2]}',
].join('\n');

String quiz10ReviewInput(Quiz10LunaRow row) =>
    quiz10ReviewPrompt.replaceAll('{{ITEM}}', quiz10ReviewItemLiteral(row));

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
    required this.number,
    required this.input,
    required this.rawText,
    required this.changes,
    required this.usage,
  });

  final int number;
  final String input;
  final String rawText;
  final List<Quiz10ReviewChange> changes;
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

List<Quiz10ReviewChange> parseQuiz10ReviewItemOutput(String text) {
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

  final changes = <Quiz10ReviewChange>[];
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
        'Cada campo de la pregunta puede corregirse una sola vez.',
      );
    }

    changes.add(
      Quiz10ReviewChange(
        field: field,
        value: rawChange['valor'] as String,
      ),
    );
  }

  return List.unmodifiable(changes);
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

    final calls = await Future.wait([
      for (var i = 0; i < rows.length; i++)
        _reviewOne(i + 1, rows[i]),
    ]);

    final patches = [
      for (final call in calls)
        if (call.changes.isNotEmpty)
          Quiz10ReviewPatch(
            number: call.number,
            changes: call.changes,
          ),
    ];

    return Quiz10ReviewResult(
      patches: List.unmodifiable(patches),
      calls: List.unmodifiable(calls),
      usage: _aggregateUsage(calls),
    );
  }

  Future<Quiz10ReviewCall> _reviewOne(
    int number,
    Quiz10LunaRow row,
  ) async {
    final input = quiz10ReviewInput(row);
    final response = await client
        .generate(
          application: 'quiz10-review',
          model: model,
          input: input,
          schemaName: 'quiz10_review_item',
          schema: quiz10ReviewSchema(),
        )
        .timeout(const Duration(seconds: 120));

    return Quiz10ReviewCall(
      number: number,
      input: input,
      rawText: response.text,
      changes: parseQuiz10ReviewItemOutput(response.text),
      usage: response.usage,
    );
  }

  Map<String, dynamic>? _aggregateUsage(List<Quiz10ReviewCall> calls) {
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
