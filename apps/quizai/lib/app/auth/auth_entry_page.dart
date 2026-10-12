import 'dart:math' as math;

import 'package:ai_apps_identity/ai_apps_identity.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import 'auth_provider_button.dart';
import 'email_auth_page.dart';

class AuthEntryPage extends StatefulWidget {
  const AuthEntryPage({
    super.key,
    required this.identity,
    required this.identityReady,
    this.initializationError,
  });

  final IdentityService identity;
  final bool identityReady;
  final Object? initializationError;

  @override
  State<AuthEntryPage> createState() => _AuthEntryPageState();
}

class _AuthEntryPageState extends State<AuthEntryPage> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  bool _providerBusy = false;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _showUnavailable(
        'Los términos de uso todavía no están disponibles.',
      );
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _showUnavailable(
        'El contenido de privacidad todavía no está disponible.',
      );
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _showUnavailable(String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );

  Future<void> _openEmail() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EmailAuthPage(identity: widget.identity),
      ),
    );
  }

  Future<void> _signInWithProvider(IdentityProvider provider) async {
    if (_providerBusy) return;

    if (!widget.identityReady) {
      _showMessage(
        widget.initializationError == null
            ? 'Preparando el servicio de acceso…'
            : 'El servicio de acceso todavía no está configurado.',
      );
      return;
    }

    setState(() => _providerBusy = true);

    try {
      switch (provider) {
        case IdentityProvider.google:
          await widget.identity.signInWithGoogle();
          break;
        case IdentityProvider.apple:
          await widget.identity.signInWithApple();
          break;
        case IdentityProvider.email:
          return;
      }
    } on IdentityFailure catch (failure) {
      if (!mounted) return;

      if (failure.code == IdentityFailureCode.providerNotReady) {
        final name = provider == IdentityProvider.google ? 'Google' : 'Apple';
        _showMessage(
          'El acceso con $name está preparado, pero todavía falta conectar su proveedor.',
        );
      } else {
        _showMessage('No se ha podido completar el acceso.');
      }
    } finally {
      if (mounted) setState(() => _providerBusy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const legalBase = TextStyle(
      color: Color(0xFF969696),
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w500,
    );
    const legalLink = TextStyle(
      color: Color(0xFFD6D6D6),
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFFD6D6D6),
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w700,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        key: const Key('quizai-auth-entry'),
        backgroundColor: Colors.black,
        body: SafeArea(
          top: true,
          bottom: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
            const _AuthParallaxArt(),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final buttonWidth = width * 0.86;
                final buttonHeight = buttonWidth / 5.82;
                final left = (width - buttonWidth) / 2;

                Widget providerButton({
                  required Key key,
                  required AuthProvider provider,
                  required double topFactor,
                  required VoidCallback onPressed,
                }) {
                  return Positioned(
                    key: key,
                    left: left,
                    top: height * topFactor,
                    width: buttonWidth,
                    height: buttonHeight,
                    child: AuthProviderButton(
                      provider: provider,
                      onPressed: onPressed,
                    ),
                  );
                }

                return Stack(
                  children: [
                    providerButton(
                      key: const Key('quizai-auth-button-google'),
                      provider: AuthProvider.google,
                      topFactor: 0.5768,
                      onPressed: () =>
                          _signInWithProvider(IdentityProvider.google),
                    ),
                    providerButton(
                      key: const Key('quizai-auth-button-apple'),
                      provider: AuthProvider.apple,
                      topFactor: 0.6595,
                      onPressed: () =>
                          _signInWithProvider(IdentityProvider.apple),
                    ),
                    providerButton(
                      key: const Key('quizai-auth-button-email'),
                      provider: AuthProvider.email,
                      topFactor: 0.7415,
                      onPressed: _openEmail,
                    ),
                  ],
                );
              },
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        style: legalBase.copyWith(
                          fontFamily: QuizTypography.family,
                        ),
                        children: [
                          const TextSpan(text: 'Al continuar, aceptas los '),
                          TextSpan(
                            text: 'Términos de uso',
                            style: legalLink.copyWith(
                              fontFamily: QuizTypography.family,
                            ),
                            recognizer: _termsRecognizer,
                          ),
                          const TextSpan(text: '\ny la '),
                          TextSpan(
                            text: 'Política de privacidad',
                            style: legalLink.copyWith(
                              fontFamily: QuizTypography.family,
                            ),
                            recognizer: _privacyRecognizer,
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      key: const Key('quizai-auth-legal'),
                      maxLines: 2,
                      softWrap: false,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Las cuatro imágenes comparten el lienzo 1080x1920 original.
/// El fondo no se mueve: las estrellas, esferas y robot tienen distintas
/// amplitudes y fases para dar profundidad sin alterar la composición.
class _AuthParallaxArt extends StatefulWidget {
  const _AuthParallaxArt();

  @override
  State<_AuthParallaxArt> createState() => _AuthParallaxArtState();
}

class _AuthParallaxArtState extends State<_AuthParallaxArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Widget _movingLayer({
    required String name,
    required String asset,
    required double x,
    required double y,
    double scale = 1,
  }) {
    return Transform.translate(
      key: Key('quizai-auth-parallax-$name'),
      offset: Offset(x, y),
      child: Transform.scale(
        scale: scale,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final angle = _motion.value * 2 * math.pi;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              // El PNG original tiene márgenes oscuros integrados.
              // Ampliar solo el fondo elimina las franjas sin alterar
              // las coordenadas de robot, estrellas, esferas y botones.
              Transform.scale(
                key: const Key('quizai-auth-background-fill'),
                scale: 1.30,
                child: Image.asset(
                  'assets/auth/Background.png',
                  key: const Key('quizai-auth-background'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
              ),
              _movingLayer(
                name: 'stars',
                asset: 'assets/auth/Estrellas.png',
                x: math.sin(angle) * 3,
                y: math.cos(angle) * 4,
                scale: 1.005,
              ),
              _movingLayer(
                name: 'spheres',
                asset: 'assets/auth/Esferas.png',
                x: math.sin(angle + 0.7) * 7,
                y: math.cos(angle + 0.7) * 6,
                scale: 1.012,
              ),
              _movingLayer(
                name: 'robot',
                asset: 'assets/auth/Robot.png',
                x: 0,
                y: -12 + math.cos(angle + 1.4) * 11,
                scale: 1.005 + math.sin(angle + 1.4) * 0.004,
              ),
            ],
          );
        },
      ),
    );
  }
}

