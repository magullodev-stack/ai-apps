import 'dart:async';

import 'package:ai_apps_identity/ai_apps_identity.dart';
import 'package:ai_apps_ui/ai_apps_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_shell.dart';
import 'app_theme.dart';
import 'auth/auth_entry_page.dart';
import 'development/experience_preview.dart';
import 'generation_dependencies.dart';
import 'onboarding/completion_store.dart';
import 'onboarding/interaction/onboarding_quiz_page.dart';

class MuondiaApp extends StatefulWidget {
  const MuondiaApp({
    super.key,
    this.identityService,
    this.onboardingStore,
    this.developmentPreviewOnStartup,
  });

  final IdentityService? identityService;
  final OnboardingCompletionStore? onboardingStore;
  /// Las pruebas pueden activar/desactivar el arranque seguro explícitamente.
  /// La app real arranca en preview siempre que sea una compilación debug.
  final bool? developmentPreviewOnStartup;

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
  final AiAppsVisualAssetController _assetInspector =
      AiAppsVisualAssetController();
  static const MethodChannel _devChannel = MethodChannel('muondia/development');
  static const MethodChannel _locationChannel =
      MethodChannel('muondia/development_location');
  String? _lastReportedLocation;
  final ValueNotifier<({String experience, String state, int revision})?>
      _selectedPreview = ValueNotifier(null);
  bool _previewAuth = false;
  // Una elección explícita de recorrido real persiste tras Hot Reload.
  bool _realDevelopmentFlowSelected = false;
  int _developmentRevision = 0;

  bool get _safeDevelopmentStartup =>
      kDebugMode &&
      (widget.developmentPreviewOnStartup ??
          widget.identityService == null);

  @override
  void initState() {
    super.initState();
    // No construir _IdentityGate ni _FirstExperience durante el arranque
    // de desarrollo: hacerlo dispararía el generador real de diez preguntas.
    if (_safeDevelopmentStartup) {
      _selectedPreview.value = (
        experience: 'auth',
        state: 'inicio',
        revision: ++_developmentRevision,
      );
    }
    if (kDebugMode) {
      _selectedPreview.addListener(_reportSelectedPreview);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reportSelectedPreview();
      });
      _assetInspector.connectDebugChannel();
      _devChannel.setMethodCallHandler((call) async {
        if (!mounted) return;
        if (call.method == 'showAuth') {
          _showDevelopmentAuth();
        } else if (call.method == 'openRealFlow') {
          _openRealDevelopmentFlow();
        } else if (call.method == 'openExperience') {
          final args = call.arguments;
          if (args is Map &&
              args['experience'] is String &&
              args['state'] is String) {
            _openDevelopmentExperience(
              args['experience'] as String,
              args['state'] as String,
            );
          }
        }
      });
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // También rescata una sesión de desarrollo ya abierta cuando el código
    // llega por Hot Reload y estaba en el onboarding real.
    if (_safeDevelopmentStartup && !_realDevelopmentFlowSelected &&
        _selectedPreview.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_realDevelopmentFlowSelected &&
            _selectedPreview.value == null) {
          _openDevelopmentExperience('auth', 'inicio');
        }
      });
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      _devChannel.setMethodCallHandler(null);
      _selectedPreview.removeListener(_reportSelectedPreview);
    }
    _selectedPreview.dispose();
    _assetInspector.dispose();
    super.dispose();
  }

  /// Una observación del dispositivo, no una conjetura del explorador.
  /// Solo IDs de pantalla/estado; no registrar usuario, email ni credenciales.
  void _reportSelectedPreview() {
    final selection = _selectedPreview.value;
    if (selection != null) {
      _reportLocation('preview', selection.experience, selection.state);
    } else {
      _reportLocation('real', '', '');
    }
  }

  void _reportLocation(String mode, String experience, String state) {
    if (!kDebugMode || !mounted) return;
    final location = '$mode:$experience:$state';
    if (_lastReportedLocation == location) return;
    _lastReportedLocation = location;
    unawaited(_locationChannel.invokeMethod<void>('setActiveLocation', {
      'mode': mode,
      'experience': experience,
      'state': state,
    }).catchError((Object _) {
      // El reporte de depuración no puede bloquear la navegación de Muondia.
    }));
  }

  void _showDevelopmentAuth() {
    // F7 abre siempre una vista simulada. No volver a la ruta del onboarding
    // real: pulsar Google allí podría lanzar de nuevo el gasto de tokens.
    _openDevelopmentExperience('auth', 'inicio');
  }

  void _openRealDevelopmentFlow() {
    if (!kDebugMode || !mounted) return;
    // No se cierra la sesión ni se modifica el progreso. La entrada normal
    // decide Auth, onboarding auténtico o Home según Firebase y el UID.
    _realDevelopmentFlowSelected = true;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (_previewAuth) setState(() => _previewAuth = false);
    _selectedPreview.value = null;
  }

  void _openDevelopmentExperience(String experience, String state) {
    const allowed = <String, Set<String>>{
      'auth': {'inicio'},
      'loading': {'inicio', 'progreso', 'final'},
      'test': {'inicio'},
      'home': {'inicio'},
    };
    if (!kDebugMode || !mounted || allowed[experience]?.contains(state) != true) {
      return;
    }
    _realDevelopmentFlowSelected = false;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (_previewAuth) setState(() => _previewAuth = false);
    _selectedPreview.value = (
      experience: experience,
      state: state,
      revision: ++_developmentRevision,
    );
  }

  KeyEventResult _developmentKey(FocusNode node, KeyEvent event) {
    if (!kDebugMode ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.f7) {
      return KeyEventResult.ignored;
    }
    // Mismo comportamiento para teclados que transmitan F7 directamente.
    _showDevelopmentAuth();
    return KeyEventResult.handled;
  }

  void _resumeSession() {
    if (_previewAuth) setState(() => _previewAuth = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    builder: (context, child) {
      final content = child ?? const SizedBox.shrink();
      if (!kDebugMode) return content;
      return AiAppsVisualAssetScope(
        controller: _assetInspector,
        child: Focus(
          autofocus: true,
          onKeyEvent: _developmentKey,
          child: content,
        ),
      );
    },
    title: 'Muondia',
    debugShowCheckedModeBanner: false,
    theme: muondiaTheme,
    home: ValueListenableBuilder<({String experience, String state, int revision})?>(
      valueListenable: _selectedPreview,
      builder: (context, selection, _) {
        if (kDebugMode && selection != null) {
          return MuondiaExperiencePreview(
            key: ValueKey(selection.revision),
            experience: selection.experience,
            state: selection.state,
            identity: _identity,
            open: _openDevelopmentExperience,
          );
        }
        return _IdentityGate(
          identity: _identity,
          initialization: _identityInitialization,
          onboardingStore: _onboardingStore,
          previewAuth: kDebugMode && _previewAuth,
          onResumeDevelopmentSession: _resumeSession,
        );
      },
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
