import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../../app/onboarding/intro_sequence.dart';
import '../production/onboarding_quiz_pipeline.dart';
import 'onboarding_loading_scene.dart';
import 'onboarding_quiz_scene.dart';
import 'onboarding_quiz_header.dart';

class OnboardingQuizPage extends StatefulWidget {
  const OnboardingQuizPage({
    super.key,
    this.loadQuestions,
    this.previewQuestions,
    this.loadHint,
    this.countdownEnabled = true,
    required this.onCompleted,
  });

  final Future<List<OnboardingQuizFinalQuestion>> Function()? loadQuestions;

  /// Datos listos: no realiza llamadas a IA al montar esta pantalla.
  final List<OnboardingQuizFinalQuestion>? previewQuestions;
  /// Servicio real en producción; la previsualización nunca llama a IA.
  final Future<String> Function(OnboardingQuizFinalQuestion question)? loadHint;
  /// Solo el explorador de experiencias desactiva la cuenta atrás.
  /// El recorrido real mantiene los 60 segundos compartidos.
  final bool countdownEnabled;
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
  int _pauseRemaining = 1;
  int _hearts = 2;
  bool _pauseActive = false;
  Timer? _pauseTimer;
  bool _hintLoading = false;
  bool _hintDialogOpen = false;
  bool _timedOut = false;
  final List<QuizOutcome> _progress =
      List<QuizOutcome>.filled(10, QuizOutcome.pending);
  Set<int> _hiddenOptions = <int>{};
  Set<int> _wrongOptions = <int>{};

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
    _pauseTimer?.cancel();
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
      _pauseRemaining = 1;
      _pauseActive = false;
      _hearts = 2;
      _progress.fillRange(0, _progress.length, QuizOutcome.pending);
      _hiddenOptions = <int>{};
      _wrongOptions = <int>{};
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
    _pauseTimer?.cancel();
    _pauseActive = false;
    _clock.stop();
    _clock.reset();
    _remainingMillis = _testDurationMillis;
    if (!widget.countdownEnabled) return;
    _clock.start();
    _clockTicker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _syncClock(),
    );
  }

  void _syncClock() {
    if (!widget.countdownEnabled || !mounted || _finished ||
        _questions == null || !_clock.isRunning) return;
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
    _pauseTimer?.cancel();
    _pauseActive = false;
    _clock.stop();
    // El tiempo termina aunque haya una pista visible: cerrar únicamente
    // el diálogo de esta pantalla, sin dejar el resultado bloqueado detrás.
    if (_hintDialogOpen) {
      _hintDialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
    setState(() {
      _finished = true;
      _timedOut = timeExpired;
      _selected = null;
    });
  }

  // La pausa dura exactamente diez segundos de tiempo real y NO impide
  // responder. El Stopwatch acumula solamente el tiempo sin pausa.
  void _usePause() {
    if (_questions == null || _finished || _pauseRemaining == 0 ||
        _pauseActive) return;
    _syncClock();
    if (_finished) return;
    _clock.stop();
    setState(() {
      _pauseRemaining = 0;
      _pauseActive = true;
    });
    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || _finished) return;
      if (widget.countdownEnabled) _clock.start();
      setState(() => _pauseActive = false);
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
        if (question.options[i] != question.correct &&
            !_wrongOptions.contains(i)) i,
    ];
    if (incorrect.length < 2) return;
    incorrect.shuffle(Random());
    setState(() {
      _fiftyRemaining = 0;
      // Dos distractores distintos, nunca la correcta; no desmonta las filas.
      _hiddenOptions = incorrect.take(2).toSet();
    });
  }

  Future<void> _useHint() async {
    final questions = _questions;
    if (questions == null || _finished || _selected != null ||
        _hintLoading || _hintRemaining == 0) return;
    _syncClock();
    if (_finished) return;
    // La pista no congela el tiempo: para eso existe Pausa.
    setState(() => _hintLoading = true);
    try {
      final question = questions[_index];
      final result = widget.loadHint == null
          ? 'Pista de demostración: fíjate en lo que pide el enunciado.'
          : await widget.loadHint!(question);
      if (!mounted || _finished) return;
      if (result.trim().isEmpty) throw const FormatException('Pista vacía');
      setState(() => _hintRemaining = 0);
      _hintDialogOpen = true;
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
      _hintDialogOpen = false;
      if (mounted && !_finished) {
        setState(() => _hintLoading = false);
      }
    }
  }

  void _answer(int index) {
    final questions = _questions;
    _syncClock();
    if (questions == null || _selected != null || _hintLoading ||
        _finished || index < 0 ||
        index >= questions[_index].options.length ||
        _hiddenOptions.contains(index) || _wrongOptions.contains(index)) {
      return;
    }

    final correct =
        questions[_index].options[index] == questions[_index].correct;
    // Cada corazón concede otro intento de la MISMA pregunta.
    // Sin corazones, el fallo se vuelve definitivo.
    final retry = !correct && _hearts > 0;
    setState(() {
      _selected = index;
      if (correct) {
        _score++;
        _progress[_index] = QuizOutcome.correct;
      } else if (retry) {
        _hearts--;
        _wrongOptions.add(index);
      } else {
        _progress[_index] = QuizOutcome.incorrect;
      }
    });
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || _finished) return;
      if (retry) {
        setState(() => _selected = null);
      } else {
        _next();
      }
    });
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
        _wrongOptions = <int>{};
      }
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _clockTicker?.cancel();
    _pauseTimer?.cancel();
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
        progress: List<QuizOutcome>.unmodifiable(_progress),
        hearts: _hearts,
        pauseRemaining: _pauseRemaining,
        pauseActive: _pauseActive,
        onUsePause: _pauseRemaining > 0 && !_pauseActive ? _usePause : null,
        fiftyRemaining: _fiftyRemaining,
        hintRemaining: _hintRemaining,
        hintLoading: _hintLoading,
        hiddenOptions: {..._hiddenOptions, ..._wrongOptions},
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

    if (_finished) {
      return _QuizResults(
        correct: _score,
        incorrect: _progress
            .where((result) => result == QuizOutcome.incorrect).length,
        unanswered: _progress
            .where((result) => result == QuizOutcome.pending).length,
        timeExpired: _timedOut,
        onCompleted: widget.onCompleted,
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
                  if (_finished) ...[
                    Text('Aciertos: $_score'),
                    Text('Fallos definitivos: ${_progress.where((result) => result == QuizOutcome.incorrect).length}'),
                    Text('Sin responder: ${_progress.where((result) => result == QuizOutcome.pending).length}'),
                    Text('Resultado: $_score / 10'),
                  ],
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

class _QuizResults extends StatelessWidget {
  const _QuizResults({
    required this.correct,
    required this.incorrect,
    required this.unanswered,
    required this.timeExpired,
    required this.onCompleted,
  });

  final int correct;
  final int incorrect;
  final int unanswered;
  final bool timeExpired;
  final Future<void> Function() onCompleted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF130A47),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF31107E),
              Color(0xFF140A46),
              Color(0xFF09052C),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Color(0xFFFFD44F), size: 54),
                    const SizedBox(height: 18),
                    Text(
                      timeExpired ? 'Tiempo agotado' : 'Partida terminada',
                      textAlign: TextAlign.center,
                      style: MuondiaTypography.screenTitle.copyWith(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFBFF),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xBB832CF4),
                            blurRadius: 30,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Resultado: $correct / 10',
                            style: MuondiaTypography.screenTitle.copyWith(
                              fontSize: 29,
                              color: const Color(0xFF161040),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _ResultLine(label: 'Aciertos', value: correct,
                              icon: Icons.check_circle_rounded,
                              color: const Color(0xFF00BE86)),
                          const SizedBox(height: 14),
                          _ResultLine(label: 'Fallos definitivos',
                              value: incorrect, icon: Icons.cancel_rounded,
                              color: const Color(0xFFE83566)),
                          const SizedBox(height: 14),
                          _ResultLine(label: 'Sin responder', value: unanswered,
                              icon: Icons.radio_button_unchecked_rounded,
                              color: const Color(0xFF8D4ADF)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    FilledButton(
                      onPressed: onCompleted,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9140E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 34, vertical: 18),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Entrar en Muondia'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 27),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          '$label: $value',
          style: MuondiaTypography.sectionTitle.copyWith(
            fontSize: 20, color: const Color(0xFF191343),
          ),
        ),
      ),
    ],
  );
}
