import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../../app/onboarding/intro_sequence.dart';
import '../production/onboarding_quiz_pipeline.dart';
import 'onboarding_loading_scene.dart';
import 'onboarding_quiz_scene.dart';

class OnboardingQuizPage extends StatefulWidget {
  const OnboardingQuizPage({
    super.key,
    this.loadQuestions,
    this.previewQuestions,
    required this.onCompleted,
  });

  final Future<List<OnboardingQuizFinalQuestion>> Function()? loadQuestions;

  /// Datos listos: no realiza llamadas a IA al montar esta pantalla.
  final List<OnboardingQuizFinalQuestion>? previewQuestions;
  final Future<void> Function() onCompleted;

  @override
  State<OnboardingQuizPage> createState() => _OnboardingQuizPageState();
}

class _OnboardingQuizPageState extends State<OnboardingQuizPage> {
  List<OnboardingQuizFinalQuestion>? _questions;
  List<OnboardingQuizFinalQuestion>? _preparedQuestions;

  int _index = 0;
  int _score = 0;
  int? _selected;
  Timer? _advanceTimer;

  bool _loading = false;
  bool _testReady = false;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    if (widget.previewQuestions != null) {
      _questions = widget.previewQuestions;
    } else if (widget.loadQuestions != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
  }

  Future<void> _start() async {
    final load = widget.loadQuestions;
    if (load == null || _loading) return;
    _advanceTimer?.cancel();

    setState(() {
      _loading = true;
      _error = null;
      _questions = null;
      _preparedQuestions = null;
      _testReady = false;
      _index = 0;
      _score = 0;
      _selected = null;
      _finished = false;
    });

    try {
      final questions = await load();

      if (questions.length != 10) {
        throw const FormatException('OnboardingQuiz requiere diez preguntas.');
      }

      if (!mounted) return;
      setState(() {
        _preparedQuestions = questions;
        _testReady = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudieron preparar las preguntas.';
        });
      }
    }
  }

  void _enterPreparedQuiz() {
    final prepared = _preparedQuestions;
    if (!mounted || prepared == null) return;

    setState(() {
      _questions = prepared;
      _preparedQuestions = null;
      _testReady = false;
      _loading = false;
    });
  }

  void _answer(int index) {
    final questions = _questions;
    if (questions == null ||
        _selected != null ||
        _finished ||
        index < 0 ||
        index >= questions[_index].options.length) {
      return;
    }

    setState(() {
      _selected = index;
      if (questions[_index].options[index] == questions[_index].correct) {
        _score++;
      }
    });
    // Una pulsación, medio segundo de información visual y avance automático.
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 500), _next);
  }

  Color _answerFeedbackColor(OnboardingQuizFinalQuestion question, int option) {
    if (_selected == null) return Colors.transparent;
    final answer = question.options[option];
    if (answer == question.correct) return MuondiaPalette.success.withAlpha(48);
    if (option == _selected) return MuondiaPalette.error.withAlpha(48);
    return Colors.transparent;
  }

  void _next() {
    final questions = _questions;
    if (!mounted || questions == null || _selected == null || _finished) return;
    setState(() {
      if (_index == questions.length - 1) {
        _finished = true;
      } else {
        _index++;
        _selected = null;
      }
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;

    final isPreparing =
        _loading ||
        (questions == null &&
            !_finished &&
            _error == null &&
            widget.loadQuestions != null);

    if (isPreparing) {
      return MuondiaIntroSequence(
        ready: _testReady,
        onCompleted: _enterPreparedQuiz,
        scene: const OnboardingQuizLoadingScene(),
      );
    }

    if (questions != null && !_finished) {
      return OnboardingQuizScene(
        question: questions[_index],
        questionNumber: _index + 1,
        questionCount: questions.length,
        selected: _selected,
        onAnswer: _answer,
        feedbackColor: (option) =>
            _answerFeedbackColor(questions[_index], option),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tu primera aventura')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.loadQuestions == null &&
                    widget.previewQuestions == null)
                  const Text('Generación no disponible.')
                else ...[
                  Text(
                    _finished
                        ? '¡Primera aventura completada!'
                        : 'Tu primera aventura',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (_finished) Text('Resultado: $_score / 10'),
                  if (_error != null) Text(_error!),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _finished ? widget.onCompleted : _start,
                    child: Text(_finished ? 'Entrar en Muondia' : 'Reintentar'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
