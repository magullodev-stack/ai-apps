import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'quiz10_pipeline.dart';

const String quiz10SortPrompt = r'''T := {{TEST}}

Pr(acierto(n₁)) ≥ ... ≥ Pr(acierto(n₁₀))

para un concursante generalista de cultura general.
''';

String quiz10SortTestLiteral(List<Quiz10ReviewedItem> items) {
  if (items.length != 10) {
    throw ArgumentError('La ordenación requiere diez preguntas revisadas.');
  }

  return [
    for (var i = 0; i < items.length; i++)
      [
        '${i + 1}.',
        'Q: ${items[i].question}',
        'R: ${items[i].correct}',
        'd1: ${items[i].distractors[0]}',
        'd2: ${items[i].distractors[1]}',
        'd3: ${items[i].distractors[2]}',
      ].join('\n'),
  ].join('\n\n');
}

String quiz10SortInput(List<Quiz10ReviewedItem> items) =>
    quiz10SortPrompt.replaceAll('{{TEST}}', quiz10SortTestLiteral(items));

Map<String, Object?> quiz10SortSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['Orden'],
  'properties': {
    'Orden': {
      'type': 'array',
      'items': {
        'type': 'integer',
        'enum': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      },
    },
  },
};

class Quiz10SortResult {
  const Quiz10SortResult({
    required this.order,
    required this.rawText,
    required this.usage,
  });

  final List<int> order;
  final String rawText;
  final Map<String, dynamic>? usage;
}

Quiz10SortResult parseQuiz10SortOutput(
  String text, {
  Map<String, dynamic>? usage,
}) {
  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } catch (error) {
    throw FormatException('JSON de ordenación inválido: $error');
  }

  if (decoded is! Map<String, dynamic> || decoded['Orden'] is! List) {
    throw const FormatException(
      'La ordenación no conserva la estructura Orden.',
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

  return Quiz10SortResult(
    order: List.unmodifiable(order),
    rawText: text,
    usage: usage,
  );
}

final class AiQuiz10Sorter {
  AiQuiz10Sorter({
    required this.client,
    required this.model,
  });

  final AiAppsClient client;
  final String model;

  Future<Quiz10SortResult> sort(List<Quiz10ReviewedItem> items) async {
    final response = await client
        .generate(
          application: 'quiz10-sort',
          model: model,
          input: quiz10SortInput(items),
          schemaName: 'quiz10_sort',
          schema: quiz10SortSchema(),
        )
        .timeout(const Duration(seconds: 120));

    return parseQuiz10SortOutput(
      response.text,
      usage: response.usage,
    );
  }
}
