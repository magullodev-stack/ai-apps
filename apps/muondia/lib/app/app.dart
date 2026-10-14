import 'package:ai_apps_identity/ai_apps_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_shell.dart';
import 'app_theme.dart';
import 'auth/auth_entry_page.dart';
import 'generation_dependencies.dart';
import 'onboarding/completion_store.dart';
import 'onboarding/interaction/onboarding_quiz_page.dart';

class MuondiaApp extends StatefulWidget {
  const MuondiaApp({
    super.key,
    this.identityService,
    this.onboardingStore,
  });

  final IdentityService? identityService;
  final OnboardingCompletionStore? onboardingStore;

  @override
  State<MuondiaApp> createState() => _MuondiaAppState();
}

class _MuondiaAppState extends State<MuondiaApp> {
  late final IdentityService _identity =
      widget.identityService ?? FirebaseIdentityService();
  late final Future<void> _identityInitialization = _identity.initialize();
  late final OnboardingCompletionStore _onboardingStore =
      widget.onboardingStore ?? LocalOnboardingCompletionStore();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _previewAuth = false;

  KeyEventResult _developmentKey(FocusNode node, KeyEvent event) {
    if (!kDebugMode ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.f7) {
      return KeyEventResult.ignored;
    }
    // F7 solo cambia la vista; Firebase y el progreso permanecen intactos.
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (!_previewAuth) setState(() => _previewAuth = true);
    return KeyEventResult.handled;
  }

  void _resumeSession() {
    if (_previewAuth) setState(() => _previewAuth = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    builder: (context, child) => kDebugMode
        ? Focus(
            autofocus: true,
            onKeyEvent: _developmentKey,
            child: child ?? const SizedBox.shrink(),
          )
        : child ?? const SizedBox.shrink(),
    title: 'Muondia',
    debugShowCheckedModeBanner: false,
    theme: muondiaTheme,
    home: _IdentityGate(
      identity: _identity,
      initialization: _identityInitialization,
      onboardingStore: _onboardingStore,
      previewAuth: kDebugMode && _previewAuth,
      onResumeDevelopmentSession: _resumeSession,
    ),
  );
}

class _IdentityGate extends StatelessWidget {
  const _IdentityGate({
    required this.identity,
    required this.initialization,
    required this.onboardingStore,
    required this.previewAuth,
    required this.onResumeDevelopmentSession,
  });

  final IdentityService identity;
  final Future<void> initialization;
  final OnboardingCompletionStore onboardingStore;
  final bool previewAuth;
  final VoidCallback onResumeDevelopmentSession;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError) {
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
            final user = authSnapshot.data;
            if (user == null || previewAuth) {
              return AuthEntryPage(
                identity: identity,
                identityReady: true,
                onResumeDevelopmentSession: user != null && previewAuth
                    ? onResumeDevelopmentSession
                    : null,
              );
            }
            return _OnboardingGate(
              key: ValueKey('muondia-onboarding-' + user.id),
              userId: user.id,
              store: onboardingStore,
            );
          },
        );
      },
    );
  }
}

/// Se muestra solamente hasta completar el recorrido inicial del usuario.
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate({
    super.key,
    required this.userId,
    required this.store,
  });

  final String userId;
  final OnboardingCompletionStore store;

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  late Future<bool> _completed = widget.store.hasCompleted(widget.userId);

  Future<void> _finish() async {
    try {
      await widget.store.markCompleted(widget.userId);
      if (mounted) setState(() => _completed = Future<bool>.value(true));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el progreso. Inténtalo de nuevo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _completed,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => setState(
                  () => _completed = widget.store.hasCompleted(widget.userId),
                ),
                child: const Text('Reintentar acceso'),
              ),
            ),
          );
        }
        if (snapshot.data == true) return const AppShell();
        return _FirstExperience(onCompleted: _finish);
      },
    );
  }
}

class _FirstExperience extends StatefulWidget {
  const _FirstExperience({required this.onCompleted});
  final Future<void> Function() onCompleted;

  @override
  State<_FirstExperience> createState() => _FirstExperienceState();
}

class _FirstExperienceState extends State<_FirstExperience> {
  final MuondiaGenerationDependencies _dependencies =
      MuondiaGenerationDependencies();

  @override
  void dispose() {
    _dependencies.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingQuizPage(
      loadQuestions: _dependencies.onboardingQuizPipeline.generate,
      onCompleted: widget.onCompleted,
    );
  }
}
