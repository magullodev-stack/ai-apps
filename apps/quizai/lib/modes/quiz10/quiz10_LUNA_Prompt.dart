import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'quiz10_DART_Pi+Di.dart';

// Dart cruza dos P y asigna una D por fila.
// Cada fila se envía a Luna en una llamada independiente.
// Las diez llamadas de una partida se lanzan simultáneamente.

const String quiz10LunaPrompt = '''Construye Q y R a partir de P[1] × P[2] y D.
Integra ambos pivotes en la misma pregunta y respuesta.
R debe ser factual, concreta, verificable y correcta para Q.''';

String quiz10LunaInput(Quiz10Pair slot) {
  final row = {
    'id': slot.number,
    'P': [
      {'codigo': slot.pivot.code, 'nombre': slot.pivot.name},
      {'codigo': slot.pivot2.code, 'nombre': slot.pivot2.name},
    ],
    'D': {
      'codigo': slot.dimension.code,
      'definicion': slot.dimension.instruction,
    },
  };

  return '$quiz10LunaPrompt\n${jsonEncode(row)}';
}

Map<String, Object?> quiz10LunaSchema() => {
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

Quiz10LunaRow parseQuiz10LunaRowOutput(
  String text,
  Quiz10Pair slot,
) {
  const invalid = FormatException(
    'La respuesta de Luna no cumple el formato de una fila de Quiz10.',
  );

  final decoded = jsonDecode(text);

  if (decoded is! Map<String, dynamic> ||
      decoded['id'] != slot.number ||
      decoded['pregunta'] is! String ||
      decoded['respuesta_correcta'] is! String) {
    throw invalid;
  }

  final question = (decoded['pregunta'] as String).trim();
  final correct = (decoded['respuesta_correcta'] as String).trim();

  if (question.isEmpty || correct.isEmpty) {
    throw invalid;
  }

  return Quiz10LunaRow(
    slot: slot,
    question: question,
    correct: correct,
  );
}

// El auditor y la interfaz pública siguen recibiendo el lote de diez filas.
// Este texto se construye localmente después de completar las diez llamadas.
List<Quiz10LunaRow> parseQuiz10LunaOutput(
  String text,
  List<Quiz10Pair> plan,
) {
  const invalid = FormatException(
    'La respuesta agregada de Luna no cumple el formato de Quiz10.',
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

    if (row is! Map<String, dynamic>) throw invalid;

    result.add(
      parseQuiz10LunaRowOutput(
        jsonEncode(row),
        plan[i],
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
  });

  final AiAppsClient client;
  final String model;

  @override
  Future<List<Quiz10LunaRow>> generate(List<Quiz10Pair> plan) async {
    final response = await generateResponse(plan);
    return parseQuiz10LunaOutput(response.text, plan);
  }

  // Conserva la interfaz de lote para el juego y la auditoría, pero el lote
  // ya no corresponde a una petición al modelo: son diez peticiones laterales.
  Future<AiGeneration> generateResponse(List<Quiz10Pair> plan) async {
    if (plan.length != 10) {
      throw ArgumentError('Luna requiere diez filas P×P-D.');
    }
    if (model.trim().isEmpty ||
        client.authorization.trim().isEmpty) {
      throw StateError('Falta configurar Luna.');
    }

    final calls = await Future.wait([
      for (final slot in plan) _generateRowResponse(slot),
    ]);

    final rows = <Quiz10LunaRow>[
      for (var i = 0; i < plan.length; i++)
        parseQuiz10LunaRowOutput(calls[i].text, plan[i]),
    ];

    return AiGeneration(
      text: jsonEncode({
        'preguntas': [
          for (final row in rows)
            {
              'id': row.slot.number,
              'pregunta': row.question,
              'respuesta_correcta': row.correct,
            },
        ],
      }),
      usage: _aggregateUsage(calls),
    );
  }

  Future<AiGeneration> _generateRowResponse(Quiz10Pair slot) {
    return client.generate(
      application: 'quiz10',
      model: model,
      input: quiz10LunaInput(slot),
      schemaName: 'quiz10_luna_question',
      schema: quiz10LunaSchema(),
    ).timeout(const Duration(seconds: 120));
  }

  Map<String, dynamic>? _aggregateUsage(List<AiGeneration> calls) {
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
