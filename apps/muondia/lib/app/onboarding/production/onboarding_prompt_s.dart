import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

const String onboardingQuizSortPrompt = r'''T := {{TEST}}

G := persona no especialista con conocimientos generales

p(n) := P(conocer Rₙ dado Qₙ | G)

Orden := (n₁,...,n₁₀)

p(n₁) ≥ ... ≥ p(n₁₀)
''';

class OnboardingQuizSortItem {
  const OnboardingQuizSortItem({
    required this.question,
    required this.correct,
  });

  final String question;
  final String correct;
}

String onboardingQuizSortTestLiteral(List<OnboardingQuizSortItem> items) {
  if (items.length != 10) {
    throw ArgumentError('La ordenación requiere diez preguntas revisadas.');
  }

  return [
    for (var i = 0; i < items.length; i++)
      [
        '${i + 1}.',
        'Q: ${items[i].question}',
        'R: ${items[i].correct}',
      ].join('\n'),
  ].join('\n\n');
}

String onboardingQuizSortInput(List<OnboardingQuizSortItem> items) =>
    onboardingQuizSortPrompt.replaceAll('{{TEST}}', onboardingQuizSortTestLiteral(items));

Map<String, Object?> onboardingQuizSortSchema() => {
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

class OnboardingQuizSortResult {
  const OnboardingQuizSortResult({
    required this.order,
    required this.rawText,
    required this.usage,
  });

  final List<int> order;
  final String rawText;
  final Map<String, dynamic>? usage;
}

OnboardingQuizSortResult parseOnboardingQuizSortOutput(
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

  return OnboardingQuizSortResult(
    order: List.unmodifiable(order),
    rawText: text,
    usage: usage,
  );
}

final class AiOnboardingQuizSorter {
  AiOnboardingQuizSorter({
    required this.client,
    required this.model,
  });

  final AiAppsClient client;
  final String model;

  Future<OnboardingQuizSortResult> sort(List<OnboardingQuizSortItem> items) async {
    final response = await client
        .generate(
          application: 'onboardingQuiz-sort',
          model: model,
          input: onboardingQuizSortInput(items),
          schemaName: 'onboardingQuiz_sort',
          schema: onboardingQuizSortSchema(),
        )
        .timeout(const Duration(seconds: 120));

    return parseOnboardingQuizSortOutput(
      response.text,
      usage: response.usage,
    );
  }
}
