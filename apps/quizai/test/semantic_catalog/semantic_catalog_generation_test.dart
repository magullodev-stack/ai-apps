import 'dart:convert';
import 'dart:io';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:ai_apps_service/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/semantic_catalog/ai_semantic_catalog_generator.dart';
import 'package:quizai/semantic_catalog/semantic_catalog_prompt.dart';

import 'fixtures.dart';

void main() {
  test(
    'el prompt incluye las instrucciones acordadas y el contexto literal',
    () {
      const context = '  Océanos\ny clima "local"  ';
      final prompt = semanticCatalogPrompt(context);
      expect(
        prompt,
        startsWith('# PROMPT — Generador de Pivotes y Atractores'),
      );
      expect(prompt, contains('genera 10 PIVOTES locales de exploración'));
      expect(
        prompt,
        contains('20 ATRACTORES ordenados por proximidad semántica relativa'),
      );
      expect(prompt, contains('A01,...,A20.'));
      expect(prompt, contains('un eje distinto de exploración del PIVOTE'));
      expect(prompt, contains('no puede contener nombres propios'));
      expect(
        prompt,
        contains(
          'Sus entidades, miembros, ejemplos, tipos y componentes quedan contenidos en ese eje y no ocupan posiciones Axx adicionales.',
        ),
      );
      expect(
        prompt,
        contains(
          'Los campos de atractores de los 10 pivotes deben ser distintos entre sí.',
        ),
      );
      expect(prompt, endsWith('CONTEXTO [C]: $context'));
    },
  );

  test('contrato HTTP del cliente, esquema y modelo independiente', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final client = _client(server.port);
    addTearDown(client.close);
    const context = '  Contexto original\n  ';
    final served = server.first.then((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/v1/generate');
      expect(request.headers.value('authorization'), 'Bearer test-token');
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['application'], 'quizai');
      expect(body['model'], 'catalog-test-model');
      expect(body['schemaName'], 'quizai_semantic_catalog');
      expect(body['input'], semanticCatalogPrompt(context));
      expect(body['schema'], semanticCatalogSchema());
      final schema = body['schema'] as Map;
      expect(schema['additionalProperties'], false);
      expect(schema['required'], ['context', 'pivots']);
      expect(schema['properties']['context'], {'type': 'string'});
      final pivots = schema['properties']['pivots'] as Map;
      expect(pivots['type'], 'array');
      expect(pivots['items']['additionalProperties'], false);
      expect(pivots['items']['required'], ['name', 'attractors']);
      expect(pivots['items']['properties'], {
        'name': {'type': 'string'},
        'attractors': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'text': jsonEncode(catalogJson(context))}),
      );
      await request.response.close();
    });
    final catalog = await AiSemanticCatalogGenerator(
      client: client,
      model: 'catalog-test-model',
    ).generateCatalog(context);
    await served;
    expect(catalog.context, context);
    expect(catalog.pivots.last.code, 'P10');
    expect(catalog.pivots.last.attractors.last.code, 'A20');
  });

  for (final valid in [true, false]) {
    test('servicio existente y Responses simulado, válido: $valid', () async {
      final provider = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => provider.close(force: true));
      final service = AiService(
        apiKey: 'test-provider-key',
        token: 'test-token',
        provider: Uri.parse('http://127.0.0.1:${provider.port}/v1/responses'),
        log: (_) {},
      );
      final server = await service.start();
      addTearDown(service.close);
      final client = _client(server.port);
      addTearDown(client.close);
      final served = provider.first.then((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['model'], 'gpt-4.1-mini');
        expect(body['store'], false);
        expect(body['input'], semanticCatalogPrompt('Contexto de prueba'));
        expect(body['text']['format'], {
          'type': 'json_schema',
          'name': 'quizai_semantic_catalog',
          'strict': true,
          'schema': semanticCatalogSchema(),
        });
        final data = catalogJson();
        if (!valid) data['pivots'].removeLast();
        request.response.write(
          jsonEncode({
            'status': 'completed',
            'output': [
              {
                'content': [
                  {'type': 'output_text', 'text': jsonEncode(data)},
                ],
              },
            ],
          }),
        );
        await request.response.close();
      });
      final result = AiSemanticCatalogGenerator(
        client: client,
        model: 'gpt-4.1-mini',
      ).generateCatalog('Contexto de prueba');
      if (valid) {
        expect((await result).pivots, hasLength(10));
      } else {
        await expectLater(result, throwsFormatException);
      }
      await served;
    });
  }

  test('rechaza contexto vacío antes de llamar al cliente', () async {
    final client = _StubClient('');
    final generator = AiSemanticCatalogGenerator(client: client, model: 'test');
    for (final context in ['', ' \n\t ']) {
      await expectLater(
        generator.generateCatalog(context),
        throwsArgumentError,
      );
    }
    expect(client.calls, 0);
  });

  test('rechaza falta de configuración antes de llamar al cliente', () async {
    for (final missingModel in [true, false]) {
      final client = _StubClient(
        '',
        authorization: missingModel ? 'token' : '',
      );
      final generator = AiSemanticCatalogGenerator(
        client: client,
        model: missingModel ? ' ' : 'test',
      );
      await expectLater(
        generator.generateCatalog('Contexto'),
        throwsStateError,
      );
      expect(client.calls, 0);
    }
  });

  test(
    'no expone respuestas malformadas, duplicadas o con otro contexto',
    () async {
      final duplicate = catalogJson();
      duplicate['pivots'][0]['attractors'][1] = 'Eje 1 20';
      for (final text in [
        '{',
        'null',
        '[]',
        '```json\n${jsonEncode(catalogJson())}\n```',
        jsonEncode(catalogJson('Otro contexto')),
        jsonEncode(duplicate),
      ]) {
        final client = _StubClient(text);
        await expectLater(
          AiSemanticCatalogGenerator(
            client: client,
            model: 'test',
          ).generateCatalog('Contexto de prueba'),
          throwsFormatException,
        );
        expect(client.calls, 1);
      }
    },
  );

  test('propaga errores del proveedor sin fabricar un catálogo', () async {
    final client = _StubClient('', failure: const AiAppsException(502));
    await expectLater(
      AiSemanticCatalogGenerator(
        client: client,
        model: 'test',
      ).generateCatalog('C'),
      throwsA(isA<AiAppsException>()),
    );
  });
}

AiAppsClient _client(int port) => AiAppsClient(
  endpoint: Uri.parse('http://127.0.0.1:$port'),
  authorization: 'test-token',
);

class _StubClient implements AiAppsClient {
  _StubClient(this.text, {this.authorization = 'test-token', this.failure});

  final String text;
  final Exception? failure;
  int calls = 0;
  @override
  final String authorization;
  @override
  Uri get endpoint => Uri.parse('http://127.0.0.1:1');
  @override
  void close() {}
  @override
  Future<AiGeneration> generate({
    required String application,
    required String model,
    required String input,
    required String schemaName,
    required Map<String, Object?> schema,
  }) async {
    calls++;
    if (failure != null) throw failure!;
    return AiGeneration(text: text);
  }
}
