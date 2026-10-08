import 'package:ai_apps_identity/ai_apps_identity.dart';
import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'app_theme.dart';
import 'auth/auth_entry_page.dart';

class QuizAIApp extends StatefulWidget {
  const QuizAIApp({
    super.key,
    this.identityService,
  });

  final IdentityService? identityService;

  @override
  State<QuizAIApp> createState() => _QuizAIAppState();
}

class _QuizAIAppState extends State<QuizAIApp> {
  late final IdentityService _identity =
      widget.identityService ?? FirebaseIdentityService();
  late final Future<void> _identityInitialization = _identity.initialize();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QuizAI',
    debugShowCheckedModeBanner: false,
    theme: quizAITheme,
    home: _IdentityGate(
      identity: _identity,
      initialization: _identityInitialization,
    ),
  );
}

class _IdentityGate extends StatelessWidget {
  const _IdentityGate({
    required this.identity,
    required this.initialization,
  });

  final IdentityService identity;
  final Future<void> initialization;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AuthEntryPage(
            identity: identity,
            identityReady: false,
          );
        }

        if (snapshot.hasError) {
          return AuthEntryPage(
            identity: identity,
            identityReady: false,
            initializationError: snapshot.error,
          );
        }

        return StreamBuilder<IdentityUser?>(
          stream: identity.authStateChanges(),
          initialData: identity.currentUser,
          builder: (context, authSnapshot) {
            if (authSnapshot.data != null) {
              return const AppShell();
            }

            return AuthEntryPage(
              identity: identity,
              identityReady: true,
            );
          },
        );
      },
    );
  }
}
