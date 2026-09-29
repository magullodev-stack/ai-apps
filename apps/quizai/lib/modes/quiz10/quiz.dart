import 'dart:convert';
import 'dart:math';

import 'quiz10_pivots.dart';

const quizAreas = quiz10Pivots;

const quizDifficulties = [
  'Fácil',
  'Fácil',
  'Fácil',
  'Fácil',
  'Moderado',
  'Moderado',
  'Moderado',
  'Difícil',
  'Difícil',
  'Muy difícil',
];

const quizFields = [
  'Dificultad',
  'Área',
  'Pregunta',
  'Correcta',
  'Distractor 1',
  'Distractor 2',
  'Distractor 3',
];

class QuizSlot {
  const QuizSlot(this.area, this.difficulty);
  final String area;
  final String difficulty;
}

List<QuizSlot> selectQuizAreas(Random random) {
  final areas = [...quizAreas]..shuffle(random);
  return List.unmodifiable([
    for (var i = 0; i < quizDifficulties.length; i++)
      QuizSlot(areas[i], quizDifficulties[i]),
  ]);
}

class QuizQuestion {
  QuizQuestion._({
    required this.slot,
    required this.text,
    required this.correct,
    required List<String> options,
  }) : options = List.unmodifiable(options);

  final QuizSlot slot;
  final String text;
  final String correct;
  final List<String> options;
}

/// Checks every row before exposing any questions to the game.
List<QuizQuestion> validateQuestions(
  String text,
  List<QuizSlot> plan,
  Random random,
) {
  const invalid = FormatException(
    'La generación no cumple el formato de Quiz10.',
  );
  final Object? decoded = jsonDecode(text);
  if (plan.length != 10 ||
      decoded is! Map<String, dynamic> ||
      decoded.length != 1 ||
      decoded['preguntas'] is! List) {
    throw invalid;
  }
  final rows = decoded['preguntas'] as List;
  if (rows.length != plan.length) throw invalid;
  final questions = <QuizQuestion>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row is! Map<String, dynamic> || row.length != quizFields.length) {
      throw invalid;
    }
    final values = <String, String>{};
    for (final field in quizFields) {
      final value = row[field];
      if (value is! String || value.trim().isEmpty) throw invalid;
      values[field] = value.trim();
    }
    if (values['Área'] != plan[i].area ||
        values['Dificultad'] != plan[i].difficulty) {
      throw invalid;
    }
    final options = [
      values['Correcta']!,
      values['Distractor 1']!,
      values['Distractor 2']!,
      values['Distractor 3']!,
    ];
    // Ignore case and repeated whitespace when detecting duplicate answers.
    if (options
            .map((value) => value.toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
            .toSet()
            .length !=
        4) {
      throw invalid;
    }
    options.shuffle(random);
    questions.add(
      QuizQuestion._(
        slot: plan[i],
        text: values['Pregunta']!,
        correct: values['Correcta']!,
        options: options,
      ),
    );
  }
  return List.unmodifiable(questions);
}

class QuizGame {
  QuizGame(List<QuizQuestion> questions)
    : questions = List.unmodifiable(questions) {
    if (questions.length != 10) {
      throw ArgumentError('Una partida requiere diez preguntas.');
    }
  }

  final List<QuizQuestion> questions;
  int _index = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _finished = false;

  QuizQuestion get current => questions[_index];
  int get questionNumber => _index + 1;
  int get score => _score;
  int? get selectedIndex => _selectedIndex;
  bool get answered => _selectedIndex != null;
  bool get finished => _finished;
  int get answeredCount => _index + (answered ? 1 : 0);
  double get progress => answeredCount / questions.length;
  bool get isCorrect =>
      answered && current.options[_selectedIndex!] == current.correct;

  void answer(int index) {
    if (finished || answered) return;
    RangeError.checkValidIndex(index, current.options);
    _selectedIndex = index;
    if (isCorrect) _score++;
  }

  void next() {
    if (finished || !answered) return;
    if (_index == questions.length - 1) {
      _finished = true;
    } else {
      _index++;
      _selectedIndex = null;
    }
  }
}
