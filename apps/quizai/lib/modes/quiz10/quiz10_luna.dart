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

/// Banco cerrado para la comparación experimental con las 86 D originales.
const quiz10CandidateDimensionCodes = <String>[
  'D01',
  'D02',
  'D05',
  'D06',
  'D10',
  'D13',
  'D15',
  'D24',
  'D34',
  'D35',
  'D45',
  'D49',
  'D50',
  'D69',
  'D78',
];

/// Selector experimental equilibrado por posición; el banco es la única
/// variable entre los dos brazos. P y niveles coinciden llamada a llamada.
List<Quiz10LunaSlot> selectQuiz10LunaPlanBancoD(
  Random random, {
  required int bancoD,
  required int callIndex,
  required int seed,
}) {
  if (bancoD != 15 && bancoD != 86) {
    throw ArgumentError.value(bancoD, 'bancoD');
  }
  if (callIndex < 0) throw RangeError.value(callIndex, 'callIndex');
  final original = selectQuiz10LunaPlan(random);
  final bank = bancoD == 15
      ? [
          for (final code in quiz10CandidateDimensionCodes)
            factualQuestionDimensions.firstWhere(
              (dimension) => dimension.code == code,
            ),
        ]
      : factualQuestionDimensions;
  final cycle = callIndex ~/ bank.length;
  final phase = callIndex % bank.length;
  final order = [...bank]..shuffle(Random(seed + cycle));

  // Diez D distintas por llamada. Cada posición recorre las D del banco
  // una vez por ciclo: 13-14 apariciones (D15), 2-3 (D86) en 200 llamadas.
  return List.unmodifiable([
    for (var i = 0; i < original.length; i++)
      Quiz10LunaSlot(
        number: original[i].number,
        pivot: original[i].pivot,
        dimension: order[(phase + 4 * i) % bank.length],
        difficulty: original[i].difficulty,
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

String quiz10LunaPrompt(List<Quiz10LunaSlot> plan) => '''Para cada fila i, primero selecciona una Rᵢ factual, concreta y verificable.
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

∀(x,y) ∈ C: x ≠literal y ∧ x ≢semántica y

Devuelve exclusivamente un objeto JSON con la propiedad "preguntas": un array de diez objetos {id, pregunta, respuesta_correcta}, en el orden de las filas.

| id | Pᵢ | Dᵢ | Instrucción Dᵢ | Dificultad |
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
        'required': ['id', 'pregunta', 'respuesta_correcta'],
        'properties': {
          'id': {'type': 'integer'},
          'pregunta': {'type': 'string'},
          'respuesta_correcta': {'type': 'string'},
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
        row['respuesta_correcta'] is! String) {
      throw invalid;
    }
    final question = (row['pregunta'] as String).trim();
    final correct = (row['respuesta_correcta'] as String).trim();
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
