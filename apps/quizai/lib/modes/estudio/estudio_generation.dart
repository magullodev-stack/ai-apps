import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import '../../coverage/coverage_route.dart';

final class EstudioQuestion {
  EstudioQuestion._({
    required this.rowNumber,
    required this.fact,
    required this.text,
    required this.correct,
    required List<String> distractors,
  }) : distractors = List.unmodifiable(distractors);

  final int rowNumber;
  final String fact;
  final String text;
  final String correct;
  final List<String> distractors;
}

abstract interface class EstudioQuestionGenerator {
  Future<List<EstudioQuestion>> generateQuestions(CoverageRoute route);
}

final class AiEstudioQuestionGenerator implements EstudioQuestionGenerator {
  AiEstudioQuestionGenerator({required this.client, required this.model});

  final AiAppsClient client;
  final String model;

  @override
  Future<List<EstudioQuestion>> generateQuestions(CoverageRoute route) async {
    if (model.trim().isEmpty || client.authorization.trim().isEmpty) {
      throw StateError('Falta la configuración de generación factual.');
    }
    final response = await client
        .generate(
          application: 'quizai',
          model: model,
          input: estudioPrompt(route),
          schemaName: 'estudio_questions',
          schema: estudioSchema(),
        )
        .timeout(const Duration(seconds: 90));
    return validateEstudioQuestions(response.text);
  }
}

String estudioPrompt(CoverageRoute route) =>
    '''# PROMPT — Generador Factual Semántico

Recibe un CONTEXTO y una RUTA DE COBERTURA de diez filas completamente definidas.

Genera exactamente una pregunta de opción múltiple por fila.

Para cada fila:

1. Materializa primero un hecho F concreto que satisfaga simultáneamente el contexto, el pivote, el atractor y la relación establecida por la dimensión factual asignada. El hecho debe ser verdadero, preciso y documentalmente sustentable. No inventes hechos para forzar combinaciones incompatibles.

2. A partir de F, formula una pregunta de 5 a 20 palabras que interrogue exactamente la relación definida por la dimensión y la posición funcional indicada por el rol interrogativo. La pregunta no debe contener la respuesta, una parte distintiva de ella ni una reformulación que permita identificarla sin resolver F.

3. Determina una respuesta correcta de 1 a 8 palabras, precisa e inequívoca.

4. Genera tres alternativas incorrectas pertenecientes al mismo espacio de respuesta que la correcta, respetando la competitividad asignada individualmente a los distractores 1, 2 y 3:

- −: plausible pero claramente distinguible.
- +: próxima pero incorrecta por una diferencia relevante.
- ++: comparte categoría, contexto y relación principal; solo una diferencia específica y decisiva la hace incorrecta.

Las cuatro alternativas deben ser distintas. Ningún distractor puede constituir una respuesta válida a la pregunta.

Mantén la correspondencia entre cada fila de entrada y su pregunta de salida.

Devuelve exclusivamente el JSON requerido.
El array preguntas debe estar ordenado por fila, de 1 a 10.

CONTEXTO:
${route.context}

RUTA DE COBERTURA:
${route.rows.map((row) => '''Fila: ${row.number}
Pivote: ${row.pivot.code} — ${row.pivot.name}
Atractor: ${row.attractor.code} — ${row.attractor.name}
Dimensión factual: ${row.dimension.code} — ${row.dimension.name}
${row.dimension.definition}
Rol interrogativo: ${row.role.code} — ${row.role.name}
${row.role.definition}
Distractor 1: ${row.distractors[0].symbol}
Distractor 2: ${row.distractors[1].symbol}
Distractor 3: ${row.distractors[2].symbol}''').join('\n\n')}''';

const _textFields = [
  'hecho',
  'pregunta',
  'correcta',
  'distractor1',
  'distractor2',
  'distractor3',
];

/// Strict mode is supplied by the existing AI service; counts are checked below.
Map<String, Object?> estudioSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['preguntas'],
  'properties': {
    'preguntas': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['fila', ..._textFields],
        'properties': {
          'fila': {
            'type': 'integer',
            'enum': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          },
          for (final field in _textFields) field: {'type': 'string'},
        },
      },
    },
  },
};

/// Checks completeness, row correspondence and textual alternative uniqueness.
/// Does not claim to verify facts, semantic compatibility or competitiveness.
List<EstudioQuestion> validateEstudioQuestions(String text) {
  const invalid = FormatException('Las preguntas de Estudio no son válidas.');
  final Object? decoded = jsonDecode(text);
  if (decoded is! Map<String, dynamic> ||
      decoded.length != 1 ||
      decoded['preguntas'] is! List) {
    throw invalid;
  }
  final rows = decoded['preguntas'] as List;
  if (rows.length != 10) throw invalid;
  final questions = <EstudioQuestion>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row is! Map<String, dynamic> ||
        row.length != 7 ||
        row['fila'] is! int ||
        row['fila'] != i + 1) {
      throw invalid;
    }
    final values = <String, String>{};
    for (final field in _textFields) {
      final value = row[field];
      if (value is! String || value.trim().isEmpty) throw invalid;
      values[field] = value.trim();
    }
    final alternatives = [
      values['correcta']!,
      values['distractor1']!,
      values['distractor2']!,
      values['distractor3']!,
    ];
    if (alternatives
            .map((value) => value.toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
            .toSet()
            .length !=
        4) {
      throw invalid;
    }
    questions.add(
      EstudioQuestion._(
        rowNumber: i + 1,
        fact: values['hecho']!,
        text: values['pregunta']!,
        correct: alternatives.first,
        distractors: alternatives.sublist(1),
      ),
    );
  }
  return List.unmodifiable(questions);
}
