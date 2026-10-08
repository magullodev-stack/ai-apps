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
  static const _layers = <String>[
    'assets/auth/QuizAI_Auth_background_1080x1920.png',
    'assets/auth/QuizAI_Auth_LOGO_1080x1920.png',
    'assets/auth/QuizAI_Auth_AI-APPS_1080x1920.png',
    'assets/auth/QuizAI_Auth_Lema_1080x1920.png',
  ];

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
        case IdentityProvider.apple:
          await widget.identity.signInWithApple();
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
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        key: const Key('quizai-auth-entry'),
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            for (final asset in _layers)
              IgnorePointer(
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
              ),
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
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
