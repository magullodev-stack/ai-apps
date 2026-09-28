import 'dart:async';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:flutter/material.dart';

import '../../coverage/coverage_route.dart';
import '../../semantic_catalog/ai_semantic_catalog_generator.dart';
import '../../semantic_catalog/semantic_catalog.dart';

class EstudioPage extends StatefulWidget {
  const EstudioPage({super.key, this.generator, this.random});

  final SemanticCatalogGenerator? generator;
  final Random? random;

  @override
  State<EstudioPage> createState() => _EstudioPageState();
}

class _EstudioPageState extends State<EstudioPage> {
  final _contextController = TextEditingController();
  late final SemanticCatalogGenerator _generator;
  late final Random _random;
  AiAppsClient? _client;
  CoverageRoute? _route;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _random = widget.random ?? Random();
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
      _generator = AiSemanticCatalogGenerator(
        client: _client!,
        model: const String.fromEnvironment(
          'AI_APPS_CATALOG_MODEL',
          defaultValue: 'gpt-4.1-mini',
        ),
      );
    }
  }

  @override
  void dispose() {
    _contextController.dispose();
    _client?.close();
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
      _route = null;
    });
    try {
      final catalog = await _generator.generateCatalog(topic);
      if (!mounted) return;
      final route = compileCoverageRoute(catalog, _random);
      setState(() => _route = route);
    } on FormatException {
      _showError('El catálogo recibido no es válido. Vuelve a generar.');
    } on TimeoutException {
      _showError('La generación ha tardado demasiado. Vuelve a intentarlo.');
    } on StateError {
      _showError(
        'No se ha configurado la generación. Abre QuizAI con su lanzador.',
      );
    } catch (_) {
      _showError('No se ha podido generar la ruta. Vuelve a intentarlo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                            _route = null;
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
                    const Text('Generando tu Ruta de Cobertura…'),
                  ],
                  if (_error case final message?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  if (_route case final route?) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Ruta de Cobertura',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(route.context),
                    const SizedBox(height: 8),
                    for (final row in route.rows)
                      Card(
                        key: ValueKey('coverage-row-${row.number}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fila ${row.number}',
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                'Pivote ${row.pivot.code}: ${row.pivot.name}',
                              ),
                              Text(
                                'Atractor ${row.attractor.code}: ${row.attractor.name}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Dimensión ${row.dimension.code}: ${row.dimension.name}',
                              ),
                              Text(row.dimension.definition),
                              const SizedBox(height: 8),
                              Text('Rol ${row.role.code}: ${row.role.name}'),
                              Text(row.role.definition),
                              const SizedBox(height: 8),
                              Text(
                                'Competitividad de distractores: ${row.distractors.map((d) => d.symbol).join(' / ')}',
                              ),
                            ],
                          ),
                        ),
                      ),
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
