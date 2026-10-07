import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';

class AuthEntryPage extends StatefulWidget {
  const AuthEntryPage({super.key});

  @override
  State<AuthEntryPage> createState() => _AuthEntryPageState();
}

class _AuthEntryPageState extends State<AuthEntryPage> {
  static const _layers = <String>[
    'assets/auth/QuizAI_Auth_background_1080x1920.png',
    'assets/auth/QuizAI_Auth_LOGO_1080x1920.png',
    'assets/auth/QuizAI_Auth_AI-APPS_1080x1920.png',
    'assets/auth/QuizAI_Auth_Google_1080x1920.png',
    'assets/auth/QuizAI_Auth_Apple_1080x1920.png',
    'assets/auth/QuizAI_Auth_Email_1080x1920.png',
  ];

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

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

  @override
  Widget build(BuildContext context) {
    const legalBase = TextStyle(
      color: Color(0xFF969696),
      fontSize: 11,
      height: 1.35,
      fontWeight: FontWeight.w500,
    );
    const legalLink = TextStyle(
      color: Color(0xFFD6D6D6),
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFFD6D6D6),
      fontSize: 11,
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
                        const TextSpan(text: ' y la '),
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
