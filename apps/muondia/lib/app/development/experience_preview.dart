import 'package:ai_apps_identity/ai_apps_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../auth/auth_entry_page.dart';
import '../interaction/ai_stage.dart';
import '../onboarding/interaction/onboarding_loading_scene.dart';
import '../onboarding/interaction/onboarding_quiz_page.dart';
import '../onboarding/intro_sequence.dart';
import '../onboarding/production/onboarding_quiz_pipeline.dart';

/// Utiliza vistas reales con datos controlados, sin acceder a IA ni Firebase.
class MuondiaExperiencePreview extends StatelessWidget {
  const MuondiaExperiencePreview({
    super.key,
    required this.experience,
    required this.state,
    required this.identity,
    required this.open,
  }) : assert(kDebugMode);

  final String experience;
  final String state;
  final IdentityService identity;
  final void Function(String experience, String state) open;

  @override
  Widget build(BuildContext context) {
    switch (experience) {
      case 'auth':
        return AuthEntryPage(
          identity: identity,
          identityReady: true,
          onDevelopmentContinue: () => open('loading', 'inicio'),
        );
      case 'loading':
        final index = switch (state) {
          'inicio' => 0,
          'progreso' => 1,
          'final' => 3,
          _ => 0,
        };
        final progress = switch (state) {
          'inicio' => 0.05,
          'progreso' => 0.58,
          'final' => 1.0,
          _ => 0.05,
        };
        return MuondiaStage(
          scene: const OnboardingQuizLoadingScene(),
          message: muondiaIntroQuizMessages[index],
          messageKey: 'preview-' + state,
          progress: progress,
        );
      case 'test':
        return OnboardingQuizPage(
          previewQuestions: previewQuestions,
          onCompleted: () async => open('home', 'inicio'),
        );
      case 'home':
        return const AppShell();
      default:
        return const Scaffold(body: Center(child: Text('Experiencia desconocida')));
    }
  }
}

final List<OnboardingQuizFinalQuestion> previewQuestions =
    List<OnboardingQuizFinalQuestion>.unmodifiable([
  for (var i = 1; i <= 10; i++)
    (
      pivot: 'Vista previa',
      question: 'Pregunta de prueba $i: ¿qué opción quieres seleccionar?',
      correct: 'Opción A',
      options: <String>['Opción A', 'Opción B', 'Opción C', 'Opción D'],
    ),
]);

