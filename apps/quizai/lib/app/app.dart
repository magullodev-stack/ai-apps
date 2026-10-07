import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'auth/auth_entry_page.dart';

class QuizAIApp extends StatelessWidget {
  const QuizAIApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QuizAI',
    debugShowCheckedModeBanner: false,
    theme: quizAITheme,
    home: const AuthEntryPage(),
  );
}
