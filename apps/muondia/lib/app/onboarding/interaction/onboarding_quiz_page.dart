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
    this.loadHint,
    required this.onCompleted,
  });

  final Future<List<OnboardingQuizFinalQuestion>> Function()? loadQuestions;

  /// Datos listos: no realiza llamadas a IA al montar esta pantalla.
  final List<OnboardingQuizFinalQuestion>? previewQuestions;
  /// Servicio real en producción; la previsualización nunca llama a IA.
  final Future<String> Function(OnboardingQuizFinalQuestion question)? loadHint;
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
  Timer? _clockTicker;
  final Stopwatch _clock = Stopwatch();
  static const int _testDurationMillis = 60000;
  int _remainingMillis = _testDurationMillis;
  int _fiftyRemaining = 1;
  int _hintRemaining = 1;
  bool _hintLoading = false;
  bool _timedOut = false;
  Set<int> _hiddenOptions = <int>{};

  bool _loading = false;
  bool _testReady = false;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    if (widget.previewQuestions != null) {
      _questions = widget.previewQuestions;
      _startClock();
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
    _clockTicker?.cancel();
    _clock.stop();
    _clock.reset();

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
      _timedOut = false;
      _hintLoading = false;
      _fiftyRemaining = 1;
      _hintRemaining = 1;
      _hiddenOptions = <int>{};
      _remainingMillis = _testDurationMillis;
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
    _startClock();
  }

  void _startClock() {
    _clockTicker?.cancel();
    _clock.stop();
    _clock.reset();
    _remainingMillis = _testDurationMillis;
    _clock.start();
    _clockTicker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _syncClock(),
    );
  }

  void _syncClock() {
    if (!mounted || _finished || _questions == null || !_clock.isRunning) return;
    final remaining = (_testDurationMillis - _clock.elapsedMilliseconds)
        .clamp(0, _testDurationMillis).toInt();
    if (remaining == 0) {
      _remainingMillis = 0;
      _finishQuiz(timeExpired: true);
    } else if (remaining != _remainingMillis) {
      setState(() => _remainingMillis = remaining);
    }
  }

  void _finishQuiz({bool timeExpired = false}) {
    _advanceTimer?.cancel();
    _clockTicker?.cancel();
    _clock.stop();
    setState(() {
      _finished = true;
      _timedOut = timeExpired;
      _selected = null;
    });
  }

  void _useFifty() {
    final questions = _questions;
    if (questions == null || _finished || _selected != null ||
        _hintLoading || _fiftyRemaining == 0) return;
    _syncClock();
    if (_finished) return;
    final question = questions[_index];
    final incorrect = <int>[
      for (var i = 0; i < question.options.length; i++)
        if (question.options[i] != question.correct) i,
    ];
    if (incorrect.length < 2) return;
    setState(() {
      _fiftyRemaining = 0;
      _hiddenOptions = incorrect.take(2).toSet();
    });
  }

  Future<void> _useHint() async {
    final questions = _questions;
    if (questions == null || _finished || _selected != null ||
        _hintLoading || _hintRemaining == 0) return;
    _syncClock();
    if (_finished) return;
    _clock.stop();
    setState(() => _hintLoading = true);
    try {
      final question = questions[_index];
      final result = widget.loadHint == null
          ? 'Pista de demostración: fíjate en lo que pide el enunciado.'
          : await widget.loadHint!(question);
      if (!mounted || _finished) return;
      if (result.trim().isEmpty) throw const FormatException('Pista vacía');
      setState(() => _hintRemaining = 0);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pista IA'),
          content: Text(result.trim()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted && !_finished) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la pista. Puedes reintentarlo.')),
        );
      }
    } finally {
      if (mounted && !_finished) {
        _clock.start();
        setState(() => _hintLoading = false);
      }
    }
  }

  void _answer(int index) {
    final questions = _questions;
    _syncClock();
    if (questions == null ||
        _selected != null ||
        _hintLoading ||
        _finished ||
        index < 0 ||
        index >= questions[_index].options.length ||
        _hiddenOptions.contains(index)) {
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
    if (_selected != option) return Colors.transparent;
    return question.options[option] == question.correct
        ? MuondiaPalette.success.withAlpha(48)
        : MuondiaPalette.error.withAlpha(48);
  }

  void _next() {
    final questions = _questions;
    if (!mounted || questions == null || _selected == null || _finished) return;
    setState(() {
      if (_index == questions.length - 1) {
        _finished = true;
        _clockTicker?.cancel();
        _clock.stop();
      } else {
        _index++;
        _selected = null;
        _hiddenOptions = <int>{};
      }
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _clockTicker?.cancel();
    _clock.stop();
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
        secondsRemaining: (_remainingMillis / 1000).ceil(),
        timeFraction: _remainingMillis / _testDurationMillis,
        fiftyRemaining: _fiftyRemaining,
        hintRemaining: _hintRemaining,
        hintLoading: _hintLoading,
        hiddenOptions: _hiddenOptions,
        onUseFifty: _selected == null && !_hintLoading && _fiftyRemaining > 0
            ? _useFifty
            : null,
        onUseHint: _selected == null && !_hintLoading && _hintRemaining > 0
            ? _useHint
            : null,
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
                  if (_timedOut) const Text('Tiempo agotado'),
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
