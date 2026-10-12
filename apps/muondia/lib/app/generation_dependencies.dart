import 'package:ai_apps_ai/ai_apps_ai.dart';

import '../modes/estudio/estudio_document_generation.dart';
import '../modes/estudio/estudio_generation.dart';
import '../app/onboarding/production/onboarding_quiz_pipeline.dart';
import '../semantic_catalog/pivot_catalog.dart';

final class MuondiaGenerationDependencies {
  MuondiaGenerationDependencies()
    : _client = AiAppsClient(
        endpoint: Uri.parse(
          const String.fromEnvironment(
            'AI_APPS_AI_URL',
            defaultValue: 'http://127.0.0.1:8787',
          ),
        ),
        authorization: const String.fromEnvironment('AI_APPS_GAME_TOKEN'),
      );

  final AiAppsClient _client;

  late final AiOnboardingQuizPipeline onboardingQuizPipeline = AiOnboardingQuizPipeline(
    client: _client,
    lunaModel: const String.fromEnvironment(
      'AI_APPS_CATALOG_MODEL',
      defaultValue: 'gpt-5.6-luna',
    ),
    reviewerModel: const String.fromEnvironment(
      'AI_APPS_ONBOARDING_QUIZ_REVIEW_MODEL',
      defaultValue: 'gpt-5.6-luna',
    ),
    sorterModel: const String.fromEnvironment(
      'AI_APPS_ONBOARDING_QUIZ_SORT_MODEL',
      defaultValue: 'gpt-5.6-luna',
    ),
  );

  PivotCatalogGenerator get catalogGenerator => AiPivotCatalogGenerator(
    client: _client,
    model: const String.fromEnvironment(
      'AI_APPS_CATALOG_MODEL',
      defaultValue: 'gpt-5.6-luna',
    ),
  );

  EstudioQuestionGenerator get questionGenerator => AiEstudioQuestionGenerator(
    client: _client,
    model: const String.fromEnvironment(
      'AI_APPS_FACTUAL_MODEL',
      defaultValue: 'gpt-5.6-terra',
    ),
  );

  EstudioDocumentQuizGenerator get documentQuizGenerator =>
      AiEstudioDocumentQuizGenerator(
        client: _client,
        catalogModel: const String.fromEnvironment(
          'AI_APPS_CATALOG_MODEL',
          defaultValue: 'gpt-5.6-luna',
        ),
        factualModel: const String.fromEnvironment(
          'AI_APPS_FACTUAL_MODEL',
          defaultValue: 'gpt-5.6-terra',
        ),
      );

  void close() => _client.close();
}
