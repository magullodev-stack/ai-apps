import 'package:flutter/material.dart';

import '../modes/quiz10/quiz_generation.dart';
import 'app_shell.dart';
import 'app_theme.dart';

class QuizAIApp extends StatelessWidget {
  const QuizAIApp({super.key, this.generator});

  final QuizGenerator? generator;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QuizAI',
    debugShowCheckedModeBanner: false,
    theme: quizAITheme,
    home: AppShell(generator: generator),
  );
}
