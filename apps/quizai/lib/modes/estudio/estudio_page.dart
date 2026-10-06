import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../coverage/coverage_route.dart';

import '../../semantic_catalog/pivot_catalog.dart';
import 'estudio_file_picker.dart';
import 'estudio_generation.dart';

class EstudioPage extends StatefulWidget {
  const EstudioPage({
    super.key,
    required this.generator,
    required this.questionGenerator,
    this.random,
    this.filePicker,
  });

  final PivotCatalogGenerator generator;
  final EstudioQuestionGenerator questionGenerator;
  final Random? random;
  final EstudioFilePicker? filePicker;

  @override
  State<EstudioPage> createState() => _EstudioPageState();
}

class _EstudioPageState extends State<EstudioPage> {
  final _contextController = TextEditingController();
  late final PivotCatalogGenerator _generator;
  late final EstudioQuestionGenerator _questionGenerator;
  late final Random _random;
  late final EstudioFilePicker _filePicker;

  EstudioPickedFile? _selectedFile;
  bool _selectingFile = false;
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
    _filePicker = widget.filePicker ?? pickEstudioFile;
  }

  @override
  void dispose() {
    _contextController.dispose();

    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_selectingFile) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectingFile = true;
      _error = null;
    });
    try {
      final file = await _filePicker();
      if (!mounted || file == null) return;
      setState(() => _selectedFile = file);
    } on FormatException {
      _showError('El archivo no tiene un formato compatible.');
    } catch (_) {
      _showError('No se ha podido abrir el archivo. Vuelve a intentarlo.');
    } finally {
      if (mounted) setState(() => _selectingFile = false);
    }
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
                  if (!_loading && questions == null) ...[
                    _FileUploadCard(
                      file: _selectedFile,
                      selecting: _selectingFile,
                      onTap: _pickFile,
                    ),
                    const SizedBox(height: 20),
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
                        ],
                      ),
                    ),
                  ],
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


class _FileUploadCard extends StatelessWidget {
  const _FileUploadCard({
    required this.file,
    required this.selecting,
    required this.onTap,
  });

  final EstudioPickedFile? file;
  final bool selecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('estudio-upload-card'),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: 'Subir archivo de estudio',
        child: InkWell(
          key: const Key('estudio-upload-file'),
          onTap: selecting ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.upload_file_rounded,
                      size: 34,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subir archivo',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text('PDF, DOCX, PPTX, JPEG o PNG'),
                        ],
                      ),
                    ),
                    if (selecting)
                      const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                if (file case final selected?) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    key: const Key('estudio-selected-file'),
                    children: [
                      const Icon(Icons.description_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selected.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(_formatFileSize(selected.sizeBytes)),
                    ],
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

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  return '${megabytes.toStringAsFixed(1)} MB';
}
