import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../coverage/coverage_route.dart';

import '../../semantic_catalog/pivot_catalog.dart';
import 'estudio_document_extractor.dart';
import 'estudio_document_generation.dart';
import 'estudio_document_store.dart';
import 'estudio_file_picker.dart';
import 'estudio_generation.dart';
import 'study_document.dart';

class EstudioPage extends StatefulWidget {
  const EstudioPage({
    super.key,
    required this.generator,
    required this.questionGenerator,
    this.random,
    this.filePicker,
    this.documentExtractor,
    this.documentStore,
    this.documentQuizGenerator,
  });

  final PivotCatalogGenerator generator;
  final EstudioQuestionGenerator questionGenerator;
  final Random? random;
  final EstudioFilePicker? filePicker;
  final EstudioDocumentExtractor? documentExtractor;
  final EstudioDocumentStore? documentStore;
  final EstudioDocumentQuizGenerator? documentQuizGenerator;

  @override
  State<EstudioPage> createState() => _EstudioPageState();
}

class _EstudioPageState extends State<EstudioPage> {
  final _contextController = TextEditingController();
  late final PivotCatalogGenerator _generator;
  late final EstudioQuestionGenerator _questionGenerator;
  late final Random _random;
  late final EstudioFilePicker _filePicker;
  late final EstudioDocumentExtractor _documentExtractor;
  late final EstudioDocumentStore _documentStore;
  EstudioDocumentQuizGenerator? _documentQuizGenerator;

  EstudioPickedFile? _selectedFile;
  StudyDocument? _studyDocument;
  StudyQuizUnit? _selectedStudyUnit;
  bool _selectingFile = false;
  bool _processingDocument = false;
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
    _documentExtractor =
        widget.documentExtractor ?? const LocalEstudioDocumentExtractor();
    _documentStore = widget.documentStore ?? LocalEstudioDocumentStore();
    _documentQuizGenerator = widget.documentQuizGenerator;
    unawaited(_restoreStudyDocument());
  }

  @override
  void dispose() {
    _contextController.dispose();

    super.dispose();
  }

  Future<void> _restoreStudyDocument() async {
    try {
      final document = await _documentStore.load();
      if (!mounted || document == null) return;
      final units = document.quizUnits;
      setState(() {
        _studyDocument = document;
        _selectedStudyUnit = units.isEmpty ? null : units.first;
      });
    } catch (_) {
      // Un material previo no debe impedir abrir Estudio.
    }
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
      validateEstudioPickedFile(file);
      setState(() => _selectedFile = file);
      await _processSelectedFile(file);
    } on EstudioFileTooLargeException catch (error) {
      _showError(
        'El archivo supera el límite de ${error.maxSizeMegabytes} MB para este formato.',
      );
    } on FormatException {
      _showError('El archivo no tiene un formato compatible.');
    } catch (_) {
      _showError('No se ha podido abrir el archivo. Vuelve a intentarlo.');
    } finally {
      if (mounted) setState(() => _selectingFile = false);
    }
  }

  Future<void> _processSelectedFile(EstudioPickedFile file) async {
    setState(() {
      _processingDocument = true;
      _error = null;
      _studyDocument = null;
      _selectedStudyUnit = null;
    });
    try {
      final document = await _documentExtractor.extract(file);
      await _documentStore.save(document);
      if (!mounted) return;
      final units = document.quizUnits;
      setState(() {
        _studyDocument = document;
        _selectedStudyUnit = units.isEmpty ? null : units.first;
      });
    } on EstudioDocumentLimitException catch (error) {
      _showError(error.message);
    } on EstudioDocumentExtractionException catch (error) {
      _showError(error.message);
    } on FormatException {
      _showError('El contenido del archivo no tiene un formato válido.');
    } catch (_) {
      _showError('No se ha podido leer el archivo. Vuelve a intentarlo.');
    } finally {
      if (mounted) setState(() => _processingDocument = false);
    }
  }

  Future<void> _generateFromDocument() async {
    if (_loading) return;
    final unit = _selectedStudyUnit;
    final generator = _documentQuizGenerator;
    if (unit == null) {
      _showError('Selecciona una parte del documento.');
      return;
    }
    if (generator == null) {
      _showError(
        'No se ha configurado la generación desde documentos. '
        'Abre Muondia con su lanzador.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _questions = null;
    });
    try {
      final questions = await generator.generateQuestions(
        sourceLabel: unit.label,
        sourceText: unit.sourceText,
        random: _random,
      );
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
      _showError('El quiz generado no es válido. Vuelve a intentarlo.');
    } on TimeoutException {
      _showError('La generación ha tardado demasiado. Vuelve a intentarlo.');
    } on StateError {
      _showError(
        'No se ha configurado la generación. Abre Muondia con su lanzador.',
      );
    } catch (_) {
      _showError('No se ha podido generar el quiz. Vuelve a intentarlo.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
        'No se ha configurado la generación. Abre Muondia con su lanzador.',
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
                      selecting: _selectingFile || _processingDocument,
                      onTap: _pickFile,
                    ),
                    if (_processingDocument) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Leyendo y estructurando el archivo…'),
                    ],
                    if (_studyDocument case final document?) ...[
                      const SizedBox(height: 16),
                      _StudyDocumentCard(
                        document: document,
                        selectedUnit: _selectedStudyUnit,
                        onUnitChanged: (unit) =>
                            setState(() => _selectedStudyUnit = unit),
                        onGenerate: _generateFromDocument,
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
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
                      child: const Text('Nuevo quiz'),
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


class _StudyDocumentCard extends StatelessWidget {
  const _StudyDocumentCard({
    required this.document,
    required this.selectedUnit,
    required this.onUnitChanged,
    required this.onGenerate,
  });

  final StudyDocument document;
  final StudyQuizUnit? selectedUnit;
  final ValueChanged<StudyQuizUnit?> onUnitChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = document.quizUnits;
    return Card(
      key: const Key('estudio-study-document'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              document.sourceName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              document.sections.length == 1
                  ? '1 sección detectada'
                  : '${document.sections.length} secciones detectadas',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('estudio-study-unit'),
              initialValue: selectedUnit?.id,
              decoration: const InputDecoration(
                labelText: 'Contenido del quiz',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final unit in units)
                  DropdownMenuItem(value: unit.id, child: Text(unit.label)),
              ],
              onChanged: (id) {
                if (id == null) {
                  onUnitChanged(null);
                  return;
                }
                onUnitChanged(units.firstWhere((unit) => unit.id == id));
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('estudio-generate-from-document'),
              onPressed: selectedUnit == null ? null : onGenerate,
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Crear quiz'),
            ),
          ],
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
                          const Text(
                            'PDF 25 MB · PPTX 20 MB · DOCX/imagen 10 MB',
                          ),
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
