import 'package:flutter/material.dart';

import '../../app/generation/quiz_preparation_screen.dart';
import 'quiz10_pipeline.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, this.loadQuestions});

  final Future<List<Quiz10FinalQuestion>> Function()? loadQuestions;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<Quiz10FinalQuestion>? _questions;

  int _index = 0;
  int _score = 0;
  int? _selected;

  bool _loading = false;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    if (widget.loadQuestions != null) {
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
      _index = 0;
      _score = 0;
      _selected = null;
      _finished = false;
    });

    try {
      final questions = await load();

      if (questions.length != 10) {
        throw const FormatException('Quiz10 requiere diez preguntas.');
      }

      if (!mounted) return;
      setState(() => _questions = questions);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron preparar las preguntas.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      return QuizPreparationScreen(
        title: 'Quiz10',
        headline: 'Preparando tu Quiz10…',
        steps: const [
          'Seleccionando temas y niveles',
          'Generando preguntas',
          'Revisando respuestas',
          'Organizando tu partida',
        ],
        footerMessage: 'Un buen Quiz10 mezcla sorpresa, variedad y preguntas que merecen la pena.',
        illustration: const Icon(
          Icons.science_rounded,
          color: Colors.white,
          size: 104,
        ),
        onBack: () => Navigator.of(context).maybePop(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz10')),
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
                    _finished ? 'Partida completada' : 'Quiz10',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (_finished) Text('Resultado: $_score / 10'),
                  if (_error != null) Text(_error!),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _start,
                    child: Text(_finished ? 'Otra partida' : 'Jugar'),
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

                  Text(
                    questions[_index].question,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),

                  for (var i = 0; i < questions[_index].options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: _selected == null ? () => _answer(i) : null,
                        child: Text(questions[_index].options[i]),
                      ),
                    ),

                  if (_selected != null) ...[
                    const SizedBox(height: 12),
                    Text(
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
