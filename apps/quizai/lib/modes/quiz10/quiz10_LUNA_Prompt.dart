import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'quiz10_DART_Pi+Di.dart';

// El catálogo selecciona P y D.
// Luna recibe esas parejas y genera Q y R.

const String quiz10LunaPrompt = '''Para cada fila i, construye Qᵢ y Rᵢ a partir de Pᵢ y Dᵢ.

Rᵢ debe ser una respuesta factual, concreta, verificable y correcta para Qᵢ.

Las diez parejas Qᵢ–Rᵢ deben cumplir las siguientes restricciones:

### Dificultad

δᵢ = dif(Qᵢ,Rᵢ): dificultad estimada de conocer Rᵢ como respuesta correcta a Qᵢ.

max(δ₁,...,δ₄) < min(δ₅,...,δ₇)
max(δ₅,...,δ₇) < min(δ₈,δ₉)
max(δ₈,δ₉) < δ₁₀

### Longitud

4 ≤ palabras(Qᵢ) ≤ 24
1 ≤ palabras(Rᵢ) ≤ 8

### No revelación interna

L(X) = FormasLingüísticasSignificativas(X)

L comprende las expresiones lingüísticas significativas, sus variantes, alias y fragmentos significativos, normalizados por equivalencia lingüística.

∀i ∈ {1,...,10}:
    L(Qᵢ) ∩ L(Rᵢ) = ∅

### Diversidad global

Sᵢ = ContenidoDistintivo(Qᵢ,Rᵢ)

Sᵢ comprende los referentes, las respuestas y los hechos distintivos de la pareja, normalizados por identidad semántica, e incorpora la forma literal de cada respuesta como elemento distintivo.

∀ 1 ≤ i < j ≤ 10:
    Sᵢ ∩ Sⱼ = ∅

### Exclusividad operativa

∀i ∈ {1,...,10}:
    DimensionesAdmisibles(Qᵢ,Rᵢ) = {Dᵢ}''';

// Alternativa exclusiva para medir latencia y calidad frente al prompt completo.
const String quiz10LunaPromptLigero = '''Para cada fila i, construye Qᵢ y Rᵢ a partir de Pᵢ y Dᵢ.
Rᵢ debe ser factual, concreta, verificable y correcta para Qᵢ.
Las diez respuestas deben tener contenidos distintos entre sí: no repitas respuestas, alias ni equivalentes semánticos entre filas.''';

String quiz10LunaInput(List<Quiz10Pair> plan, {bool promptLigero = false}) {
  if (plan.length != 10) {
    throw ArgumentError('Luna requiere diez parejas P-D.');
  }

  final rows = [
    for (final slot in plan)
      {
        'id': slot.number,
        'P': {
          'codigo': slot.pivot.code,
          'nombre': slot.pivot.name,
        },
        'D': {
          'codigo': slot.dimension.code,
          'definicion': slot.dimension.instruction,
        },
      },
  ];

  final prompt = promptLigero ? quiz10LunaPromptLigero : quiz10LunaPrompt;
  return '$prompt\n${jsonEncode(rows)}';
}

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

class Quiz10LunaRow {
  const Quiz10LunaRow({
    required this.slot,
    required this.question,
    required this.correct,
  });

  final Quiz10Pair slot;
  final String question;
  final String correct;
}

List<Quiz10LunaRow> parseQuiz10LunaOutput(
  String text,
  List<Quiz10Pair> plan,
) {
  const invalid = FormatException(
    'La respuesta de Luna no cumple el formato de Quiz10.',
  );

  if (plan.length != 10) throw invalid;

  final decoded = jsonDecode(text);

  if (decoded is! Map<String, dynamic> ||
      decoded['preguntas'] is! List) {
    throw invalid;
  }

  final rows = decoded['preguntas'] as List;

  if (rows.length != 10) throw invalid;

  final result = <Quiz10LunaRow>[];

  for (var i = 0; i < 10; i++) {
    final row = rows[i];

    if (row is! Map<String, dynamic> ||
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

    result.add(
      Quiz10LunaRow(
        slot: plan[i],
        question: question,
        correct: correct,
      ),
    );
  }

  return List.unmodifiable(result);
}

abstract interface class Quiz10LunaGenerator {
  Future<List<Quiz10LunaRow>> generate(
    List<Quiz10Pair> plan,
  );
}

final class AiQuiz10LunaGenerator implements Quiz10LunaGenerator {
  const AiQuiz10LunaGenerator({
    required this.client,
    required this.model,
    this.promptLigero = false,
  });

  final AiAppsClient client;
  final String model;
  final bool promptLigero;

  @override
  Future<List<Quiz10LunaRow>> generate(List<Quiz10Pair> plan) async {
    final response = await generateResponse(plan);
    return parseQuiz10LunaOutput(response.text, plan);
  }

  /// La auditoría necesita el uso de tokens incluso si falla el parseo.
  /// El juego conserva generate(plan) sin cambios.
  Future<AiGeneration> generateResponse(List<Quiz10Pair> plan) async {
    if (model.trim().isEmpty ||
        client.authorization.trim().isEmpty) {
      throw StateError('Falta configurar Luna.');
    }

    return client.generate(
      application: 'quiz10',
      model: model,
      input: quiz10LunaInput(plan, promptLigero: promptLigero),
      schemaName: 'quiz10_luna_questions',
      schema: quiz10LunaSchema(),
    ).timeout(const Duration(seconds: 120));
  }
}