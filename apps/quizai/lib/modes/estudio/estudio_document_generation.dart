import 'dart:convert';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import '../../coverage/coverage_route.dart';
import '../../semantic_catalog/pivot_catalog.dart';
import 'estudio_generation.dart';

abstract interface class EstudioDocumentQuizGenerator {
  Future<List<EstudioQuestion>> generateQuestions({
    required String sourceLabel,
    required String sourceText,
    required Random random,
  });
}

final class AiEstudioDocumentQuizGenerator
    implements EstudioDocumentQuizGenerator {
  AiEstudioDocumentQuizGenerator({
    required this.client,
    required this.catalogModel,
    required this.factualModel,
  });

  final AiAppsClient client;
  final String catalogModel;
  final String factualModel;

  @override
  Future<List<EstudioQuestion>> generateQuestions({
    required String sourceLabel,
    required String sourceText,
    required Random random,
  }) async {
    final source = sourceText.trim();
    if (source.isEmpty) {
      throw const FormatException('La fuente seleccionada está vacía.');
    }
    if (catalogModel.trim().isEmpty ||
        factualModel.trim().isEmpty ||
        client.authorization.trim().isEmpty) {
      throw StateError('Falta la configuración de generación de Estudio.');
    }

    final pivotsResponse = await client
        .generate(
          application: 'quizai',
          model: catalogModel,
          input: _documentPivotPrompt(sourceLabel, source),
          schemaName: 'estudio_document_pivots',
          schema: _documentPivotSchema(),
        )
        .timeout(const Duration(seconds: 90));

    final decoded = jsonDecode(pivotsResponse.text);
    if (decoded is! Map<String, dynamic> || decoded['pivots'] is! List) {
      throw const FormatException('Los pivotes del documento no son válidos.');
    }

    final catalog = PivotCatalog.fromJson({
      'context': source,
      'pivots': decoded['pivots'],
    });
    final route = compileCoverageRoute(catalog, random);

    final questionsResponse = await client
        .generate(
          application: 'quizai',
          model: factualModel,
          input: _documentQuestionPrompt(sourceLabel, source, route),
          schemaName: 'estudio_document_questions',
          schema: estudioSchema(),
        )
        .timeout(const Duration(seconds: 90));

    return validateEstudioQuestions(questionsResponse.text);
  }
}

String _documentPivotPrompt(String label, String source) => '''# ESTUDIO — Pivotes desde fuente cerrada

Vas a crear la cobertura de un quiz a partir de una única FUENTE.

Reglas obligatorias:
- La FUENTE es el único conocimiento permitido.
- No uses conocimientos externos, aunque sean verdaderos.
- Selecciona exactamente 10 conceptos, entidades, hechos o relaciones que aparezcan de forma explícita en la FUENTE y que permitan formular preguntas respondibles exclusivamente con ella.
- Cubre zonas distintas del contenido; evita diez variantes del mismo dato.
- Cada pivote debe tener entre 1 y 3 palabras.
- Devuelve únicamente el JSON solicitado.

SELECCIÓN DEL USUARIO:
$label

FUENTE:
$source''';

Map<String, Object?> _documentPivotSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['pivots'],
  'properties': {
    'pivots': {
      'type': 'array',
      'items': {'type': 'string'},
    },
  },
};

String _documentQuestionPrompt(
  String label,
  String source,
  CoverageRoute route,
) => '''# ESTUDIO — Quiz desde fuente cerrada

Genera exactamente una pregunta de opción múltiple por cada fila de la RUTA DE COBERTURA.

La FUENTE es cerrada y constituye toda la verdad disponible para esta tarea.

Reglas obligatorias:
1. El hecho, la pregunta y la respuesta correcta deben estar explícitamente sustentados por la FUENTE. No completes, corrijas ni amplíes la fuente con conocimiento externo.
2. Si una relación de la ruta no puede formularse de forma fiel con la FUENTE, formula la relación factual más próxima que sí esté sustentada, manteniendo el pivote.
3. La pregunta debe poder resolverse leyendo la FUENTE y no debe contener la respuesta.
4. La respuesta correcta debe tener entre 1 y 8 palabras siempre que el contenido lo permita.
5. Los tres distractores deben ser inequívocamente incorrectos según la propia FUENTE. No uses como distractor una alternativa cuya falsedad dependa de conocimiento externo.
6. Las cuatro alternativas deben ser distintas.
7. Mantén exactamente las filas 1 a 10 y devuelve exclusivamente el JSON requerido.

SELECCIÓN DEL USUARIO:
$label

FUENTE:
$source

RUTA DE COBERTURA:
${route.rows.map((row) => '''Fila: ${row.number}
Pivote: ${row.pivot.code} — ${row.pivot.name}
Dimensión factual: ${row.dimension.code} — ${row.dimension.name}
${row.dimension.definition}
Rol interrogativo: ${row.role.code} — ${row.role.name}
${row.role.definition}
Distractor 1: ${row.distractors[0].symbol}
Distractor 2: ${row.distractors[1].symbol}
Distractor 3: ${row.distractors[2].symbol}''').join('\n\n')}''';
