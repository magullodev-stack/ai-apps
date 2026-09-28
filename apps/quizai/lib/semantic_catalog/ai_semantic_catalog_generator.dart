import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'semantic_catalog.dart';
import 'semantic_catalog_prompt.dart';

/// The caller owns the client and chooses this operation's model independently
/// of other operations (development configuration: gpt-4.1-mini).
final class AiSemanticCatalogGenerator implements SemanticCatalogGenerator {
  AiSemanticCatalogGenerator({required this.client, required this.model});

  final AiAppsClient client;
  final String model;

  @override
  Future<SemanticCatalog> generateCatalog(String context) async {
    if (context.trim().isEmpty) {
      throw ArgumentError.value(context, 'context', 'El contexto está vacío.');
    }
    if (model.trim().isEmpty || client.authorization.trim().isEmpty) {
      throw StateError('Falta la configuración de desarrollo de IA.');
    }
    final result = await client
        .generate(
          application: 'quizai',
          model: model,
          input: semanticCatalogPrompt(context),
          schemaName: 'quizai_semantic_catalog',
          schema: semanticCatalogSchema(),
        )
        .timeout(const Duration(seconds: 90));
    final catalog = SemanticCatalog.fromJson(jsonDecode(result.text));
    if (catalog.context != context) {
      throw const FormatException('El catálogo ha alterado el contexto.');
    }
    return catalog;
  }
}
