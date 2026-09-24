import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'quiz.dart';

String quizPrompt(List<QuizSlot> plan) =>
    '''Genera 10 preguntas a partir de las áreas y dificultades de la tabla.

Selecciona conocimientos variados, de distintos grupos y referentes. Evita repeticiones, solapamientos y la concentración en los referentes más habituales.

Selecciona conocimientos verificables cuya dificultad corresponda a la fijada en cada fila. Evalúa la dificultad por la probabilidad de que una persona con cultura general conozca la respuesta, no por su complejidad técnica, especialización académica ni dificultad de redacción. Cada respuesta debe ser precisa e inequívoca.

| Dificultad | Área | Pregunta | Correcta | Distractor 1 | Distractor 2 | Distractor 3 |
| ----------- | ---- | -------- | -------- | ------------ | ------------ | ------------ |
${plan.map((slot) => '| ${slot.difficulty} | ${slot.area} | | | | | |').join('\n')}''';

Map<String, Object?> quizSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['preguntas'],
  'properties': {
    'preguntas': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': quizFields,
        'properties': {
          for (final field in quizFields)
            field: {
              'type': 'string',
              if (field == 'Dificultad')
                'enum': quizDifficulties.toSet().toList(),
              if (field == 'Área') 'enum': quizAreas,
            },
        },
      },
    },
  },
};

abstract interface class QuizGenerator {
  Future<List<QuizQuestion>> generate(List<QuizSlot> plan);
}

class AiQuizGenerator implements QuizGenerator {
  AiQuizGenerator({required this.client, required this.model, Random? random})
    : _random = random ?? Random();

  final AiAppsClient client;
  final String model;
  final Random _random;

  @override
  Future<List<QuizQuestion>> generate(List<QuizSlot> plan) async {
    if (model.trim().isEmpty || client.authorization.trim().isEmpty) {
      throw StateError('Falta la configuración de desarrollo de IA.');
    }
    final result = await client
        .generate(
          application: 'quiz10',
          model: model,
          input: quizPrompt(plan),
          schemaName: 'quiz10_questions',
          schema: quizSchema(),
        )
        .timeout(const Duration(seconds: 90));
    return validateQuestions(result.text, plan, _random);
  }
}
