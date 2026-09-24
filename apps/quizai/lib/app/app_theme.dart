import 'package:flutter/material.dart';

/// Identidad visual particular de QuizAI.
///
/// No pertenece a las capacidades compartidas de AI-APPS.
abstract final class QuizPalette {
  static const background = Color(0xFF38149B);
  static const backgroundLight = Color(0xFF7838F2);
  static const backgroundDark = Color(0xFF29116F);

  static const primary = Color(0xFF6931DD);
  static const primaryLight = Color(0xFFAB73FF);

  static const foreground = Colors.white;
  static const foregroundMuted = Color(0xFFD8CBFF);

  static const ink = Color(0xFF21163B);

  // Identidad visual de la navegación inferior de QuizAI.
  static const navSurfaceStart = Color(0xFF7049CF);
  static const navSurfaceEnd = Color(0xFF4B2C9C);
  static const navBorder = Color(0xFF9974E9);

  static const navActiveText = Color(0xFF5126BB);
  static const navInactiveText = Color(0xFFE9DEFF);

  static const navBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navSurfaceStart, navSurfaceEnd],
  );

  static const navActiveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBEFFF), Color(0xFFE9CEFF)],
  );

  static const salaStart = Color(0xFFFFEBA0);
  static const salaEnd = Color(0xFFFFBA4C);

  static const versusStart = Color(0xFF91F1FC);
  static const versusEnd = Color(0xFF22C5E9);

  static const estudioStart = Color(0xFFB9F89D);
  static const estudioEnd = Color(0xFF57DE74);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundLight, background, backgroundDark],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9A62FF), Color(0xFF6935E9), Color(0xFF8845F5)],
  );
}

/// Jerarquía tipográfica propia de QuizAI.
///
/// La familia se registra localmente en pubspec.yaml.
/// Los estilos se comparten entre la aplicación y sus modalidades.
abstract final class QuizTypography {
  static const family = 'Nunito';
}

final ThemeData quizAITheme = ThemeData(
  useMaterial3: true,
  fontFamily: QuizTypography.family,
  colorScheme: ColorScheme.fromSeed(seedColor: QuizPalette.primary),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
  ),
);
