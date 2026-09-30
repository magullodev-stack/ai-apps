import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'app_theme.dart';

class QuizAIApp extends StatelessWidget {
  const QuizAIApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QuizAI',
    debugShowCheckedModeBanner: false,
    theme: quizAITheme,
    home: const AppShell(),
  );
}
