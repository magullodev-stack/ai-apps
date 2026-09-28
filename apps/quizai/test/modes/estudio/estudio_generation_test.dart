import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/coverage/coverage_route.dart';
import 'package:quizai/modes/estudio/estudio_generation.dart';
import 'package:quizai/semantic_catalog/pivot_catalog.dart';

import 'fixtures.dart';

void main() {
  test(
    'envía la ruta literal y modelo independiente mediante AiAppsClient',
    () async {
      final route = compileCoverageRoute(
        PivotCatalog.fromJson({
          'context': 'Contexto de prueba',
          'pivots': [for (var i = 1; i <= 10; i++) 'Pivote $i'],
        }),
        Random(4),
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final client = AiAppsClient(
        endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
        authorization: 'test-token',
      );
      addTearDown(client.close);
      final served = server.first.then((request) async {
        expect(request.uri.path, '/v1/generate');
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['model'], 'factual-test-model');
        expect(body['application'], 'quizai');
        expect(body['schemaName'], 'estudio_questions');
        expect(body['schema'], estudioSchema());
        final prompt = body['input'] as String;
        expect(prompt, estudioPrompt(route));
        expect(prompt, contains('CONTEXTO:\n${route.context}'));
        for (final row in route.rows) {
          expect(
            prompt,
            contains('''Fila: ${row.number}
Pivote: ${row.pivot.code} — ${row.pivot.name}
Dimensión factual: ${row.dimension.code} — ${row.dimension.name}
${row.dimension.definition}
Rol interrogativo: ${row.role.code} — ${row.role.name}
${row.role.definition}
Distractor 1: ${row.distractors[0].symbol}
Distractor 2: ${row.distractors[1].symbol}
Distractor 3: ${row.distractors[2].symbol}'''),
          );
          expect(prompt, isNot(contains('Atractor:')));
        }
        final schema = body['schema'] as Map;
        expect(schema['additionalProperties'], false);
        expect(schema['required'], ['preguntas']);
        final items = schema['properties']['preguntas']['items'];
        expect(items['additionalProperties'], false);
        expect(items['required'], [
          'fila',
          'hecho',
          'pregunta',
          'correcta',
          'distractor1',
          'distractor2',
          'distractor3',
        ]);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'text': jsonEncode(estudioJson())}));
        await request.response.close();
      });
      final questions = await AiEstudioQuestionGenerator(
        client: client,
        model: 'factual-test-model',
      ).generateQuestions(route);
      await served;
      expect(questions, hasLength(10));
      expect(questions.first.fact, 'Hecho interno 1');
      expect(questions.last.rowNumber, 10);
      expect(questions.first.distractors, [
        'Alternativa A 1',
        'Alternativa B 1',
        'Alternativa C 1',
      ]);
      expect(() => questions.clear(), throwsUnsupportedError);
      expect(() => questions.first.distractors.clear(), throwsUnsupportedError);
    },
  );

  final changes = <String, void Function(Map<String, dynamic>)>{
    'nueve preguntas': (data) => data['preguntas'].removeLast(),
    'once preguntas': (data) => data['preguntas'].add(data['preguntas'][0]),
    'fila fuera de orden': (data) => data['preguntas'][0]['fila'] = 2,
    'fila duplicada': (data) => data['preguntas'][9]['fila'] = 9,
    'fila no entera': (data) => data['preguntas'][0]['fila'] = '1',
    'sin hecho': (data) => data['preguntas'][0].remove('hecho'),
    'pregunta vacía': (data) => data['preguntas'][0]['pregunta'] = ' ',
    'distractor incompleto': (data) =>
        data['preguntas'][9]['distractor3'] = null,
    'alternativas duplicadas': (data) =>
        data['preguntas'][0]['distractor2'] = ' CORRECTA\t 1 ',
    'distractores duplicados': (data) =>
        data['preguntas'][0]['distractor3'] = 'alternativa A 1',
    'objeto incompleto': (data) => data['preguntas'][0] = {},
  };
  for (final entry in changes.entries) {
    test('rechaza ${entry.key}', () {
      final data = estudioJson();
      entry.value(data);
      expect(
        () => validateEstudioQuestions(jsonEncode(data)),
        throwsFormatException,
      );
    });
  }
  test('rechaza JSON malformado sin heurísticas semánticas', () {
    for (final text in ['{', 'null', '[]', '```json\n{}\n```']) {
      expect(() => validateEstudioQuestions(text), throwsFormatException);
    }
    final data = estudioJson();
    data['preguntas'][0]['pregunta'] = '¿Qué?';
    // Word count and factual truth remain prompt constraints, not local checks.
    expect(validateEstudioQuestions(jsonEncode(data)).first.text, '¿Qué?');
  });
}
