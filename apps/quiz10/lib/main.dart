import 'dart:async';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:flutter/material.dart';

import 'quiz.dart';
import 'quiz_generation.dart';

void main() => runApp(const Quiz10App());

class Quiz10App extends StatelessWidget {
  const Quiz10App({super.key, this.generator});
  final QuizGenerator? generator;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Quiz10',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    ),
    home: QuizPage(generator: generator),
  );
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, this.generator});
  final QuizGenerator? generator;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _random = Random();
  AiAppsClient? _client;
  late final QuizGenerator _generator;
  QuizGame? _game;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.generator case final generator?) {
      _generator = generator;
    } else {
      _client = AiAppsClient(
        endpoint: Uri.parse(
          const String.fromEnvironment(
            'AI_APPS_AI_URL',
            defaultValue: 'http://127.0.0.1:8787',
          ),
        ),
        authorization: const String.fromEnvironment('AI_APPS_GAME_TOKEN'),
      );
      _generator = AiQuizGenerator(
        client: _client!,
        model: const String.fromEnvironment('AI_APPS_AI_MODEL'),
      );
    }
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _game = null;
    });
    try {
      final questions = await _generator.generate(selectQuizAreas(_random));
      if (!mounted) return;
      setState(() => _game = QuizGame(questions));
    } on FormatException {
      _showError(
        'Las preguntas recibidas no son válidas. Pulsa 🎲 para generar otras.',
      );
    } on StateError {
      _showError(
        'No se ha configurado la generación de preguntas. Consulta las instrucciones de ejecución de Quiz10.',
      );
    } on TimeoutException {
      _showError(
        'La generación ha tardado demasiado. Pulsa 🎲 para volver a intentarlo.',
      );
    } catch (_) {
      _showError(
        'No se han podido generar las preguntas. Pulsa 🎲 para volver a intentarlo.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz10')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 24),
                    const Text(
                      'Generando tus diez preguntas…',
                      textAlign: TextAlign.center,
                    ),
                  ] else if (game == null || game.finished) ...[
                    Text(
                      game == null
                          ? 'Diez áreas. Diez preguntas.'
                          : 'Partida completada',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      game == null
                          ? 'Pon a prueba tu cultura general, de fácil a muy difícil.'
                          : 'Resultado: ${game.score} / 10 aciertos',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _start,
                      child: Text(
                        game == null ? '🎲 Jugar' : '🎲 Otra partida',
                      ),
                    ),
                  ] else ...[
                    Text('Pregunta ${game.questionNumber} de 10'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: game.progress,
                      semanticsLabel:
                          'Preguntas respondidas: ${game.answeredCount} de 10',
                    ),
                    const SizedBox(height: 8),
                    Text('Aciertos: ${game.score}'),
                    const SizedBox(height: 24),
                    Text(
                      '${game.current.slot.area} · ${game.current.slot.difficulty}',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      game.current.text,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < game.current.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          key: ValueKey('option-$i'),
                          onPressed: game.answered
                              ? null
                              : () => setState(() => game.answer(i)),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${game.selectedIndex == i ? '● ' : ''}${game.current.options[i]}',
                            ),
                          ),
                        ),
                      ),
                    if (game.answered) ...[
                      Text(
                        game.isCorrect
                            ? '¡Correcto!'
                            : 'Respuesta correcta: ${game.current.correct}',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(game.next),
                        child: Text(
                          game.questionNumber == 10
                              ? 'Ver resultado'
                              : 'Siguiente',
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
