import 'dart:convert';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import '../../coverage/factual_question_dimensions.dart';
import 'quiz.dart';
import 'quiz10_pivots.dart';

/// Dart fija P, D y dificultad; Luna elige R y redacta Q.
final class Quiz10LunaSlot {
  const Quiz10LunaSlot({
    required this.number,
    required this.pivot,
    required this.dimension,
    required this.difficulty,
  });

  final int number;
  final String pivot;
  final FactualQuestionDimension dimension;
  final String difficulty;
}

/// Sortea diez pivotes diferentes y diez dimensiones diferentes, sin U.
List<Quiz10LunaSlot> selectQuiz10LunaPlan(Random random) {
  final pivots = [...quiz10Pivots]..shuffle(random);
  final dimensions = [...factualQuestionDimensions]..shuffle(random);
  return List.unmodifiable([
    for (var i = 0; i < quizDifficulties.length; i++)
      Quiz10LunaSlot(
        number: i + 1,
        pivot: pivots[i],
        dimension: dimensions[i],
        difficulty: quizDifficulties[i],
      ),
  ]);
}

final class Quiz10LunaRow {
  const Quiz10LunaRow({
    required this.slot,
    required this.question,
    required this.correct,
  });

  final Quiz10LunaSlot slot;
  final String question;
  final String correct;
}

String quiz10LunaPrompt(List<Quiz10LunaSlot> plan) => '''# Quiz10 — generación de preguntas y respuestas correctas

Recibes diez filas fijadas por Dart. Cada fila determina:
- Pivote P: campo de conocimiento de la pregunta.
- Dimensión D: instrucción literal que determina qué debe identificar la respuesta.
- Dificultad: grado de familiaridad del conocimiento para una persona con cultura general.

Para CADA fila:
1. Encuentra un hecho real, verificable y perteneciente al pivote indicado.
2. Elige libremente la respuesta correcta R del hecho; R no está preseleccionada.
3. Formula una pregunta Q natural de concurso de cultura general cuya respuesta
   inequívoca sea exactamente R y que cumpla la instrucción de esa D.
4. Ajusta la dificultad a la familiaridad del HECHO, no a la longitud del
   enunciado, a un lenguaje enrevesado ni a un ejercicio artificial.

Respeta las diez parejas P–D, el orden de las filas y sus dificultades.
No sustituyas una D difícil por otra más cómoda. Busca un hecho adecuado
para cada combinación antes de responder. Las D abstractas deben concretarse
en hechos específicos, no en preguntas sobre el vocabulario de la dimensión.
No inventes supuestos, reglas ni deducciones improvisadas para forzar una D.
Evita hechos repetidos, respuestas repetidas y preguntas equivalentes.
Cada pregunta ha de admitir una respuesta precisa y distinguible de opciones
incorrectas. Si hacen falta condiciones para eliminar una ambigüedad,
exprésalas claramente en la propia pregunta.

Tu única salida es el JSON solicitado, con diez entradas en el mismo orden.
Cada entrada contiene exclusivamente: id, pregunta y correcta.
No repitas pivotes, dimensiones ni dificultades en la salida.
NO generes distractores, explicaciones, niveles de confianza ni opciones.

| id | Pivote P | Dimensión D | Instrucción D | Dificultad |
|---:|---|---|---|---|
${plan.map((slot) => '| ${slot.number} | ${slot.pivot} | ${slot.dimension.code} | ${slot.dimension.instruction} | ${slot.difficulty} |').join('\n')}''';

/// Luna devuelve solamente sus dos campos nuevos más el identificador.
Map<String, Object?> quiz10LunaSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['preguntas'],
  'properties': {
    'preguntas': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['id', 'pregunta', 'correcta'],
        'properties': {
          'id': {'type': 'integer'},
          'pregunta': {'type': 'string'},
          'correcta': {'type': 'string'},
        },
      },
    },
  },
};

/// Validación estructural: la validación factual corresponderá a Terra.
List<Quiz10LunaRow> parseQuiz10LunaOutput(
  String text,
  List<Quiz10LunaSlot> plan,
) {
  const invalid = FormatException(
    'La salida de Luna no cumple el contrato de Quiz10.',
  );
  if (plan.length != 10) throw invalid;
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, dynamic> ||
      decoded.length != 1 ||
      decoded['preguntas'] is! List) {
    throw invalid;
  }
  final rows = decoded['preguntas'] as List;
  if (rows.length != plan.length) throw invalid;
  final parsed = <Quiz10LunaRow>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row is! Map<String, dynamic> ||
        row.length != 3 ||
        row['id'] != plan[i].number ||
        row['pregunta'] is! String ||
        row['correcta'] is! String) {
      throw invalid;
    }
    final question = (row['pregunta'] as String).trim();
    final correct = (row['correcta'] as String).trim();
    if (question.isEmpty || correct.isEmpty) throw invalid;
    parsed.add(Quiz10LunaRow(
      slot: plan[i],
      question: question,
      correct: correct,
    ));
  }
  return List.unmodifiable(parsed);
}

abstract interface class Quiz10LunaGenerator {
  Future<List<Quiz10LunaRow>> generate(List<Quiz10LunaSlot> plan);
}

final class AiQuiz10LunaGenerator implements Quiz10LunaGenerator {
  const AiQuiz10LunaGenerator({required this.client, required this.model});

  final AiAppsClient client;
  final String model;

  @override
  Future<List<Quiz10LunaRow>> generate(List<Quiz10LunaSlot> plan) async {
    if (model.trim().isEmpty || client.authorization.trim().isEmpty) {
      throw StateError('Falta la configuración de desarrollo de IA.');
    }
    final result = await client.generate(
      application: 'quiz10',
      model: model,
      input: quiz10LunaPrompt(plan),
      schemaName: 'quiz10_luna_questions',
      schema: quiz10LunaSchema(),
    ).timeout(const Duration(seconds: 120));
    return parseQuiz10LunaOutput(result.text, plan);
  }
}
