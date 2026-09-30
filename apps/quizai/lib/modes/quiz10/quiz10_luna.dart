import 'dart:convert';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import '../../coverage/factual_question_dimensions.dart';
import 'quiz.dart';
import 'quiz10_pivots.dart';

/// Dart fija P, D y dificultad; Luna genera Q y R.
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

/// Selecciona diez pivotes y diez dimensiones distintas.
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

/// PROMPT CANÓNICO DE LUNA.
/// Su contenido no incluye datos de entrada ni formato de salida.
const String quiz10LunaPrompt = '''Para cada fila i, primero selecciona una Rᵢ factual, concreta y verificable.
Después formula Qᵢ conforme a Pᵢ y Dᵢ, de modo que Rᵢ sea una respuesta correcta.

dif(Rᵢ): dificultad estimada de conocer Rᵢ.

max(dif(R₁),...,dif(R₄)) < min(dif(R₅),...,dif(R₇))
max(dif(R₅),...,dif(R₇)) < min(dif(R₈),dif(R₉))
max(dif(R₈),dif(R₉)) < dif(R₁₀)

4 ≤ palabras(Qᵢ) ≤ 24
1 ≤ palabras(Rᵢ) ≤ 8

C = {(Rᵢ,Rⱼ): 1 ≤ j < i ≤ 10}
    ∪ ⋃ᵢ₌₁¹⁰ (
        PalabrasYExpresiones(Qᵢ)
        × ({Rᵢ} ∪ AliasYFragmentos(Rᵢ))
      )

∀(x,y) ∈ C: x ≠literal y ∧ x ≢semántica y''';

/// Prepara los datos de las diez filas sin alterar el prompt.
String quiz10LunaInput(List<Quiz10LunaSlot> plan) {
  final rows = [
    for (final slot in plan)
      {
        'id': slot.number,
        'P': slot.pivot,
        'D': {
          'codigo': slot.dimension.code,
          'instruccion': slot.dimension.instruction,
        },
        'dificultad': slot.difficulty,
      },
  ];

  return '$quiz10LunaPrompt\n${jsonEncode(rows)}';
}

/// El formato de salida se establece mediante el esquema JSON.
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
        'required': [
          'id',
          'pregunta',
          'respuesta_correcta',
        ],
        'properties': {
          'id': {'type': 'integer'},
          'pregunta': {'type': 'string'},
          'respuesta_correcta': {'type': 'string'},
        },
      },
    },
  },
};

/// Comprueba la estructura de la respuesta de Luna.
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
        row['respuesta_correcta'] is! String) {
      throw invalid;
    }

    final question = (row['pregunta'] as String).trim();
    final correct = (row['respuesta_correcta'] as String).trim();

    if (question.isEmpty || correct.isEmpty) {
      throw invalid;
    }

    parsed.add(
      Quiz10LunaRow(
        slot: plan[i],
        question: question,
        correct: correct,
      ),
    );
  }

  return List.unmodifiable(parsed);
}

abstract interface class Quiz10LunaGenerator {
  Future<List<Quiz10LunaRow>> generate(
    List<Quiz10LunaSlot> plan,
  );
}

final class AiQuiz10LunaGenerator
    implements Quiz10LunaGenerator {
  const AiQuiz10LunaGenerator({
    required this.client,
    required this.model,
  });

  final AiAppsClient client;
  final String model;

  @override
  Future<List<Quiz10LunaRow>> generate(
    List<Quiz10LunaSlot> plan,
  ) async {
    if (model.trim().isEmpty ||
        client.authorization.trim().isEmpty) {
      throw StateError(
        'Falta la configuración de desarrollo de IA.',
      );
    }

    final result = await client.generate(
      application: 'quiz10',
      model: model,
      input: quiz10LunaInput(plan),
      schemaName: 'quiz10_luna_questions',
      schema: quiz10LunaSchema(),
    ).timeout(const Duration(seconds: 120));

    return parseQuiz10LunaOutput(result.text, plan);
  }
}