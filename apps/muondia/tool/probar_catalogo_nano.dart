import 'dart:convert';
import 'dart:io';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:ai_apps_service/ai_service.dart';
import 'package:muondia/semantic_catalog/semantic_catalog.dart';
import 'package:muondia/semantic_catalog/semantic_catalog_prompt.dart';

Future<void> main() async {
  stdout.write('Contexto: ');
  final contexto = stdin.readLineSync(encoding: utf8) ?? '';

  if (contexto.trim().isEmpty) {
    stderr.writeln('Escribe un contexto.');
    exitCode = 1;
    return;
  }

  final clave = Platform.environment['AI_APPS_AI_API_KEY'] ?? '';

  final servicio = AiService(apiKey: clave, token: 'prueba-local-catalogo');

  AiAppsClient? cliente;

  try {
    final servidor = await servicio.start();

    cliente = AiAppsClient(
      endpoint: Uri.parse('http://127.0.0.1:${servidor.port}'),
      authorization: 'prueba-local-catalogo',
    );

    print('\nGenerando catálogo con GPT-5 Nano...\n');

    final respuesta = await cliente.generate(
      application: 'muondia',
      model: 'gpt-5-nano',
      input: semanticCatalogPrompt(contexto),
      schemaName: 'muondia_semantic_catalog',
      schema: semanticCatalogSchema(),
    );

    final original = File('../../.ai-apps/catalogo_nano_raw.json');
    await original.parent.create(recursive: true);
    await original.writeAsString(respuesta.text, flush: true);

    print('Respuesta original guardada en: ${original.absolute.path}');

    final catalogo = SemanticCatalog.fromJson(jsonDecode(respuesta.text));

    if (catalogo.context != contexto) {
      print('AVISO: Nano cambió el contexto a: ${catalogo.context}');
    }

    final contenido = {
      'context': catalogo.context,
      'pivots': [
        for (final pivote in catalogo.pivots)
          {
            'name': pivote.name,
            'attractors': [
              for (final atractor in pivote.attractors) atractor.name,
            ],
          },
      ],
    };

    final salida = File('../../.ai-apps/catalogo_nano.json');
    await salida.parent.create(recursive: true);
    await salida.writeAsString(
      const JsonEncoder.withIndent('  ').convert(contenido),
    );

    for (final pivote in catalogo.pivots) {
      print('${pivote.code} — ${pivote.name}');
      for (final atractor in pivote.attractors) {
        print('  ${atractor.code} — ${atractor.name}');
      }
      print('');
    }

    print('CATÁLOGO GENERADO: 10 pivotes, 200 atractores.');
    print('Guardado en: ${salida.absolute.path}');
  } catch (error) {
    stderr.writeln('FALLO REAL: $error');
    exitCode = 1;
  } finally {
    cliente?.close();
    await servicio.close();
  }
}
