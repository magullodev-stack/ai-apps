import 'dart:convert';
import 'dart:math';

import 'package:quizai/modes/quiz10/quiz.dart';

List<Map<String, Object?>> fixtureRows(List<QuizSlot> plan) => [
  for (var i = 0; i < plan.length; i++)
    {
      'Dificultad': plan[i].difficulty,
      'Área': plan[i].area,
      'Pregunta': 'Pregunta de prueba ${i + 1}',
      'Correcta': 'Correcta ${i + 1}',
      'Distractor 1': 'Alternativa A ${i + 1}',
      'Distractor 2': 'Alternativa B ${i + 1}',
      'Distractor 3': 'Alternativa C ${i + 1}',
    },
];

String fixtureJson(List<QuizSlot> plan) =>
    jsonEncode({'preguntas': fixtureRows(plan)});

List<QuizQuestion> fixtureQuestions(List<QuizSlot> plan) =>
    validateQuestions(fixtureJson(plan), plan, Random(42));
