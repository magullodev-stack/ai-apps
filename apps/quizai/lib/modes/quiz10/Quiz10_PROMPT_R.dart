import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'Quiz10_PROMPT_G.dart';

const String quiz10ReviewPrompt = r'''## Entrada

T := {{TEST}}


## Tarea

Revisa Q, R y los tres distractores de cada pregunta y corrige lo necesario para que la pregunta y sus opciones sean correctas, coherentes y de calidad, conservando la relación definida por la Instrucción D.

Ordena las 10 preguntas de menor a mayor dificultad para un concursante generalista de cultura general, según la probabilidad de que responda correctamente la pregunta tal como queda formulada: a mayor probabilidad de acierto, menor dificultad.


## Salida

Orden: [n₁, n₂, n₃, n₄, n₅, n₆, n₇, n₈, n₉, n₁₀]

Después, únicamente las correcciones:

n.
Q: ...
R: ...
a1: ...
a2: ...
a3: ...''';

String quiz10ReviewTestLiteral(List<Quiz10LunaRow> rows) {
  if (rows.length != 10) {
    throw ArgumentError('La revisión requiere diez filas de Luna.');
  }

  return [
    for (var i = 0; i < rows.length; i++)
      [
        '${i + 1}.',
        'P: ${rows[i].returnedPivot}',
        'Instrucción D: ${rows[i].slot.dimension.instruction}',
        'F: ${rows[i].fact}',
        'Q: ${rows[i].question}',
        'R: ${rows[i].correct}',
        'd1: ${rows[i].distractors[0]}',
        'd2: ${rows[i].distractors[1]}',
        'd3: ${rows[i].distractors[2]}',
      ].join('\n'),
  ].join('\n\n');
}

String quiz10ReviewInput(List<Quiz10LunaRow> rows) =>
    quiz10ReviewPrompt.replaceAll('{{TEST}}', quiz10ReviewTestLiteral(rows));

Map<String, Object?> quiz10ReviewSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['Orden', 'correcciones'],
  'properties': {
    'Orden': {
      'type': 'array',
      'items': {
        'type': 'integer',
        'enum': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      },
    },
    'correcciones': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['n', 'cambios'],
        'properties': {
          'n': {
            'type': 'integer',
            'enum': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          },
          'cambios': {
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

class Quiz10ReviewResult {
  const Quiz10ReviewResult({
    required this.order,
    required this.patches,
    required this.rawText,
    required this.usage,
  });

  final List<int> order;
  final List<Quiz10ReviewPatch> patches;
  final String rawText;
  final Map<String, dynamic>? usage;
}

Quiz10ReviewResult parseQuiz10ReviewOutput(
  String text, {
  Map<String, dynamic>? usage,
}) {
  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } catch (error) {
    throw FormatException('JSON de revisión inválido: $error');
  }

  if (decoded is! Map<String, dynamic> ||
      decoded['Orden'] is! List ||
      decoded['correcciones'] is! List) {
    throw const FormatException(
      'La revisión no conserva la estructura Orden/correcciones.',
    );
  }

  final rawOrder = decoded['Orden'] as List;
  if (rawOrder.length != 10 || rawOrder.any((value) => value is! int)) {
    throw const FormatException('Orden debe contener diez números.');
  }
  final order = [for (final value in rawOrder) value as int];
  if (order.toSet().length != 10 ||
      order.any((value) => value < 1 || value > 10)) {
    throw const FormatException(
      'Orden debe ser una permutación de 1 a 10.',
    );
  }

  final patches = <Quiz10ReviewPatch>[];
  final seenNumbers = <int>{};
  for (final rawPatch in decoded['correcciones'] as List) {
    if (rawPatch is! Map<String, dynamic> ||
        rawPatch['n'] is! int ||
        rawPatch['cambios'] is! List) {
      throw const FormatException('Corrección estructuralmente inválida.');
    }

    final number = rawPatch['n'] as int;
    if (number < 1 || number > 10 || !seenNumbers.add(number)) {
      throw const FormatException(
        'Cada pregunta corregida debe aparecer una sola vez.',
      );
    }

    final changes = <Quiz10ReviewChange>[];
    final seenFields = <String>{};
    for (final rawChange in rawPatch['cambios'] as List) {
      if (rawChange is! Map<String, dynamic> ||
          rawChange['campo'] is! String ||
          rawChange['valor'] is! String) {
        throw const FormatException('Cambio estructuralmente inválido.');
      }

      final field = rawChange['campo'] as String;
      if (!const {'Q', 'R', 'd1', 'd2', 'd3'}.contains(field) ||
          !seenFields.add(field)) {
        throw const FormatException(
          'Cada campo corregido debe aparecer una sola vez.',
        );
      }

      changes.add(
        Quiz10ReviewChange(
          field: field,
          value: rawChange['valor'] as String,
        ),
      );
    }

    patches.add(
      Quiz10ReviewPatch(
        number: number,
        changes: List.unmodifiable(changes),
      ),
    );
  }

  return Quiz10ReviewResult(
    order: List.unmodifiable(order),
    patches: List.unmodifiable(patches),
    rawText: text,
    usage: usage,
  );
}

final class AiQuiz10Reviewer {
  AiQuiz10Reviewer({
    required this.client,
    required this.model,
  });

  final AiAppsClient client;
  final String model;

  Future<Quiz10ReviewResult> review(List<Quiz10LunaRow> rows) async {
    final response = await client
        .generate(
          application: 'quiz10-review',
          model: model,
          input: quiz10ReviewInput(rows),
          schemaName: 'quiz10_review',
          schema: quiz10ReviewSchema(),
        )
        .timeout(const Duration(seconds: 120));

    return parseQuiz10ReviewOutput(
      response.text,
      usage: response.usage,
    );
  }
}
