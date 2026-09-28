import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../coverage/coverage_route.dart';

import '../../semantic_catalog/semantic_catalog.dart';
import 'estudio_generation.dart';

class EstudioPage extends StatefulWidget {
  const EstudioPage({
    super.key,
    required this.generator,
    required this.questionGenerator,
    this.random,
  });

  final SemanticCatalogGenerator generator;
  final EstudioQuestionGenerator questionGenerator;
  final Random? random;

  @override
  State<EstudioPage> createState() => _EstudioPageState();
}

class _EstudioPageState extends State<EstudioPage> {
  final _contextController = TextEditingController();
  late final SemanticCatalogGenerator _generator;
  late final EstudioQuestionGenerator _questionGenerator;
  late final Random _random;

  List<EstudioQuestion>? _questions;
  List<List<String>> _options = [];
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _finished = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _random = widget.random ?? Random();
    _generator = widget.generator;
    _questionGenerator = widget.questionGenerator;
  }

  @override
  void dispose() {
    _contextController.dispose();

    super.dispose();
  }

  Future<void> _generate() async {
    if (_loading) return;
    final topic = _contextController.text;
    if (topic.trim().isEmpty) {
      setState(() => _error = 'Escribe un tema antes de generar.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _questions = null;
    });
    try {
      final catalog = await _generator.generateCatalog(topic);
      if (!mounted) return;
      final route = compileCoverageRoute(catalog, _random);
      final questions = await _questionGenerator.generateQuestions(route);
      if (!mounted) return;
      if (questions.length != 10 ||
          List.generate(
            10,
            (i) => questions[i].rowNumber != i + 1,
          ).contains(true)) {
        throw const FormatException('Partida incompleta.');
      }
      final options = [
        for (final question in questions)
          [question.correct, ...question.distractors]..shuffle(_random),
      ];
      setState(() {
        _questions = List.unmodifiable(questions);
        _options = options;
        _index = 0;
        _score = 0;
        _selected = null;
        _finished = false;
      });
    } on FormatException {
      _showError('La generación recibida no es válida. Vuelve a generar.');
    } on TimeoutException {
      _showError('La generación ha tardado demasiado. Vuelve a intentarlo.');
    } on StateError {
      _showError(
        'No se ha configurado la generación. Abre QuizAI con su lanzador.',
      );
    } catch (_) {
      _showError(
        'No se han podido generar las preguntas. Vuelve a intentarlo.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  void _answer(int option) {
    if (_selected != null || _finished) return;
    setState(() {
      _selected = option;
      if (_options[_index][option] == _questions![_index].correct) _score++;
    });
  }

  void _next() {
    if (_selected == null || _finished) return;
    setState(() {
      if (_index == 9) {
        _finished = true;
      } else {
        _index++;
        _selected = null;
      }
    });
  }

  void _newTopic() => setState(() {
    _questions = null;
    _options = [];
    _contextController.clear();
    _error = null;
    _index = 0;
    _score = 0;
    _selected = null;
    _finished = false;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = _questions;
    return Scaffold(
      appBar: AppBar(title: const Text('Estudio')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_loading && questions == null)
                    RadioGroup<String>(
                      groupValue: 'topic',
                      onChanged: (_) {},
                      child: Column(
                        children: [
                          const RadioListTile<String>(
                            value: 'topic',
                            title: Text('Escribe un tema'),
                          ),
                          TextField(
                            controller: _contextController,
                            readOnly: _loading,
                            minLines: 2,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Tema o contexto',
                              hintText: '¿Qué quieres explorar?',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {
                              _error = null;
                            }),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading ? null : _generate,
                              child: const Text('Generar'),
                            ),
                          ),
                          const RadioListTile<String>(
                            value: 'file',
                            enabled: false,
                            title: Text('Sube un archivo'),
                            subtitle: Text('Todavía no disponible'),
                          ),
                        ],
                      ),
                    ),
                  if (_loading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('Generando tus diez preguntas…'),
                  ],
                  if (_error case final message?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  if (questions != null && _finished) ...[
                    Text(
                      'Partida completada',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text('Resultado: $_score / 10 aciertos'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _newTopic,
                      child: const Text('Escribir otro tema'),
                    ),
                  ] else if (questions != null) ...[
                    Text('Pregunta ${_index + 1} de 10'),
                    Text('Aciertos: $_score'),
                    const SizedBox(height: 16),
                    Text(
                      questions[_index].text,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          onPressed: _selected == null
                              ? () => _answer(i)
                              : null,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${_selected == i ? '● ' : ''}${_options[_index][i]}',
                            ),
                          ),
                        ),
                      ),
                    if (_selected != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _options[_index][_selected!] ==
                                  questions[_index].correct
                              ? '¡Correcto!'
                              : 'Respuesta correcta: ${questions[_index].correct}',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _next,
                        child: const Text('Siguiente'),
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
