import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:ai_apps_service/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz10/quiz.dart';
import 'package:quiz10/quiz_generation.dart';

import 'fixtures.dart';

void main() {
  for (final valid in [true, false]) {
    test(
      'Quiz10 -> servicio Dart -> Responses simulado (válido: $valid)',
      () async {
        final plan = selectQuizAreas(Random(12));
        final provider = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => provider.close(force: true));
        final service = AiService(
          apiKey: 'test-provider-key',
          token: 'test-local-token',
          provider: Uri.parse('http://127.0.0.1:${provider.port}/v1/responses'),
          log: (_) {},
        );
        final server = await service.start();
        addTearDown(service.close);
        final client = AiAppsClient(
          endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
          authorization: 'test-local-token',
        );
        addTearDown(client.close);
        final served = provider.first.then((request) async {
          final sent = jsonDecode(await utf8.decoder.bind(request).join());
          expect(sent['model'], 'gpt-4.1-mini');
          expect(sent['text']['format']['schema'], quizSchema());
          expect(sent['input'], quizPrompt(plan));
          final rows = fixtureRows(plan);
          if (!valid) rows.removeLast();
          request.response.write(
            jsonEncode({
              'status': 'completed',
              'output': [
                {
                  'content': [
                    {
                      'type': 'output_text',
                      'text': jsonEncode({'preguntas': rows}),
                    },
                  ],
                },
              ],
            }),
          );
          await request.response.close();
        });
        final generator = AiQuizGenerator(
          client: client,
          model: 'gpt-4.1-mini',
        );
        if (valid) {
          final game = QuizGame(await generator.generate(plan));
          expect(game.questions, hasLength(10));
          expect(game.questionNumber, 1);
        } else {
          await expectLater(generator.generate(plan), throwsFormatException);
        }
        await served;
      },
    );
  }

  test(
    'envía prompt y esquema por el cliente compartido y valida la respuesta',
    () async {
      final plan = selectQuizAreas(Random(3));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final client = AiAppsClient(
        endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
        authorization: 'test-only-token',
      );
      addTearDown(client.close);
      final generator = AiQuizGenerator(
        client: client,
        model: 'test-model',
        random: Random(4),
      );
      final requestHandled = server.first.then((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/v1/generate');
        expect(
          request.headers.value('authorization'),
          'Bearer test-only-token',
        );
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['application'], 'quiz10');
        expect(body['model'], 'test-model');
        expect(body['schemaName'], 'quiz10_questions');
        final prompt = body['input'] as String;
        expect(
          prompt,
          startsWith(
            'Genera 10 preguntas a partir de las áreas y dificultades de la tabla.',
          ),
        );
        expect(prompt, contains('Evita repeticiones, solapamientos'));
        expect(
          prompt,
          contains(
            'probabilidad de que una persona con cultura general conozca la respuesta',
          ),
        );
        final tableRows = prompt
            .split('\n')
            .where((line) => line.startsWith('|'))
            .skip(2)
            .toList();
        expect(tableRows, [
          for (final slot in plan)
            '| ${slot.difficulty} | ${slot.area} | | | | | |',
        ]);
        final schema = body['schema'] as Map;
        expect(schema['additionalProperties'], false);
        expect(schema['required'], ['preguntas']);
        final rows = schema['properties']['preguntas'] as Map;
        expect(rows, isNot(contains('minItems')));
        expect(rows, isNot(contains('maxItems')));
        expect(rows['items']['required'], quizFields);
        expect(rows['items']['additionalProperties'], false);
        expect((rows['items']['properties'] as Map).keys, quizFields);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'text': fixtureJson(plan)}));
        await request.response.close();
      });
      final questions = await generator.generate(plan);
      await requestHandled;
      expect(questions, hasLength(10));
      expect(questions.first.slot.area, plan.first.area);
    },
  );

  test('falta de modelo o token impide solicitar una generación', () async {
    for (final missingModel in [true, false]) {
      final client = AiAppsClient(
        endpoint: Uri.parse('http://127.0.0.1:1'),
        authorization: missingModel ? 'test-token' : '',
      );
      addTearDown(client.close);
      final generator = AiQuizGenerator(
        client: client,
        model: missingModel ? '' : 'test-model',
      );
      await expectLater(
        generator.generate(selectQuizAreas(Random(1))),
        throwsStateError,
      );
    }
  });
}
