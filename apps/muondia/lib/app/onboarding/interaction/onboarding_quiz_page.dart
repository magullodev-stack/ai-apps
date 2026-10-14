import 'package:ai_apps_ui/ai_apps_ui.dart';
import 'package:flutter/material.dart';

import '../../../app/onboarding/intro_sequence.dart';
import '../production/onboarding_quiz_pipeline.dart';
import 'onboarding_loading_scene.dart';

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
    if (questions == null || _selected != null || _finished) return;

    setState(() {
      _selected = index;

      if (questions[_index].options[index] == questions[_index].correct) {
        _score++;
      }
    });
  }

  void _next() {
    if (_selected == null) return;

    setState(() {
      if (_index == 9) {
        _finished = true;
      } else {
        _index++;
        _selected = null;
      }
    });
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
                if (widget.loadQuestions == null)
                  const Text('Generación no disponible.')
                else if (questions == null || _finished) ...[
                  Text(
                    _finished ? '¡Primera aventura completada!' : 'Tu primera aventura',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (_finished) Text('Resultado: $_score / 10'),
                  if (_error != null) Text(_error!),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _finished ? widget.onCompleted : _start,
                    child: Text(_finished ? 'Entrar en Muondia' : 'Reintentar'),
                  ),
                ] else ...[
                  Text('Pregunta ${_index + 1} de 10'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _index / 10),
                  const SizedBox(height: 16),

                  Text('Aciertos: $_score'),
                  const SizedBox(height: 16),

                  Text(questions[_index].pivot),
                  const SizedBox(height: 8),

                  AiAppsContentText(
                    questions[_index].question,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),

                  for (var i = 0; i < questions[_index].options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: _selected == null ? () => _answer(i) : null,
                        child: AiAppsContentText(
                          questions[_index].options[i],
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  if (_selected != null) ...[
                    const SizedBox(height: 12),
                    AiAppsContentText(
                      questions[_index].options[_selected!] ==
                              questions[_index].correct
                          ? '¡Correcto!'
                          : 'Respuesta correcta: '
                                '${questions[_index].correct}',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _next,
                      child: Text(_index == 9 ? 'Ver resultado' : 'Siguiente'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
