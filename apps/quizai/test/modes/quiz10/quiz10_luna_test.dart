import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/coverage/factual_question_dimensions.dart';
import 'package:quizai/modes/quiz10/quiz.dart';
import 'package:quizai/modes/quiz10/quiz10_luna.dart';
import 'package:quizai/modes/quiz10/quiz10_pivots.dart';

List<Map<String, Object?>> _rows(List<Quiz10LunaSlot> plan) => [
  for (final slot in plan)
    {
      'id': slot.number,
      'pregunta': '¿Pregunta comprobable de ${slot.pivot}?',
      'correcta': 'Respuesta ${slot.number}',
    },
];

void main() {
  test('bancos canónicos: 21 P, 86 D y 18 familias', () {
    expect(quiz10Pivots, hasLength(21));
    expect(quiz10Pivots.toSet(), hasLength(21));
    expect(quizAreas, quiz10Pivots);
    expect(factualQuestionDimensions, hasLength(86));
    expect(
      [for (final d in factualQuestionDimensions) d.code],
      [for (var n = 1; n <= 86; n++) 'D${n.toString().padLeft(2, '0')}'],
    );
    expect(
      factualQuestionDimensions.every((d) => d.instruction.startsWith('Pregunta por ')),
      isTrue,
    );
    expect(
      factualQuestionDimensions.where((d) => d.group.name == 'intra'),
      hasLength(43),
    );
    expect(
      factualQuestionDimensions.where((d) => d.group.name == 'meta'),
      hasLength(25),
    );
    expect(
      factualQuestionDimensions.where((d) => d.group.name == 'extra'),
      hasLength(18),
    );
    expect(
      factualQuestionDimensions.map((d) => d.familyCode).toSet(),
      hasLength(18),
    );
    expect(
      factualQuestionDimensions[44].instruction,
      'Pregunta por la persona o entidad a la que se atribuye la procedencia de una entidad o contenido.',
    );
  });

  test('diez P y diez D distintas, dificultad progresiva y semillas reproducibles', () {
    final seenP = <String>{};
    final seenD = <String>{};
    for (var seed = 0; seed < 300; seed++) {
      final plan = selectQuiz10LunaPlan(Random(seed));
      expect(plan, hasLength(10));
      expect(plan.map((row) => row.number).toList(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(plan.map((row) => row.pivot).toSet(), hasLength(10));
      expect(plan.map((row) => row.dimension.code).toSet(), hasLength(10));
      expect(plan.map((row) => row.difficulty).toList(), quizDifficulties);
      seenP.addAll(plan.map((row) => row.pivot));
      seenD.addAll(plan.map((row) => row.dimension.code));
      expect(() => plan.add(plan.first), throwsUnsupportedError);
    }
    expect(seenP, quiz10Pivots.toSet());
    expect(seenD, factualQuestionDimensions.map((d) => d.code).toSet());
  });

  test('prompt transmite cada P y la instrucción D literal, sin pedir distractores', () {
    final plan = selectQuiz10LunaPlan(Random(42));
    final prompt = quiz10LunaPrompt(plan);
    for (final slot in plan) {
      expect(prompt, contains(slot.pivot));
      expect(prompt, contains(slot.dimension.code));
      expect(prompt, contains(slot.dimension.instruction));
      expect(prompt, contains(slot.difficulty));
    }
    expect(prompt, contains('d(R₁) < d(R₂) < ... < d(R₁₀)'));
    expect(prompt, contains('id(Rᵢ) ∉ {id(Rⱼ) : j < i}'));
    final itemSchema = (quiz10LunaSchema()['properties'] as Map)['preguntas']['items'] as Map;
    expect(itemSchema['required'], ['id', 'pregunta', 'correcta']);
    expect((itemSchema['properties'] as Map).keys, ['id', 'pregunta', 'correcta']);
  });

  test('acepta diez Q/R y rechaza filas incompletas, fuera de orden o extrañas', () {
    final plan = selectQuiz10LunaPlan(Random(5));
    final items = _rows(plan);
    final parsed = parseQuiz10LunaOutput(jsonEncode({'preguntas': items}), plan);
    expect(parsed, hasLength(10));
    expect(parsed.first.slot, same(plan.first));
    expect(parsed.first.correct, 'Respuesta 1');
    final invalid = [
      jsonEncode({'preguntas': items.take(9).toList()}),
      jsonEncode({'preguntas': items.reversed.toList()}),
      jsonEncode({'preguntas': [{...items.first, 'extra': 1}, ...items.skip(1)]}),
      jsonEncode({'preguntas': [{...items.first, 'correcta': ' '}, ...items.skip(1)]}),
      jsonEncode({'preguntas': [{...items.first, 'id': 99}, ...items.skip(1)]}),
    ];
    for (final value in invalid) {
      expect(() => parseQuiz10LunaOutput(value, plan), throwsFormatException);
    }
  });

  test('Luna usa servicio compartido y schema, sin solicitar distractores', () async {
    final plan = selectQuiz10LunaPlan(Random(13));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final client = AiAppsClient(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
      authorization: 'token-simulado',
    );
    addTearDown(client.close);
    final served = server.first.then((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['model'], 'gpt-5.6-luna');
      expect(body['application'], 'quiz10');
      expect(body['schemaName'], 'quiz10_luna_questions');
      expect(body['input'], quiz10LunaPrompt(plan));
      expect(body['schema'], quiz10LunaSchema());
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'text': jsonEncode({'preguntas': _rows(plan)}),
      }));
      await request.response.close();
    });
    final generator = AiQuiz10LunaGenerator(
      client: client,
      model: 'gpt-5.6-luna',
    );
    final rows = await generator.generate(plan);
    await served;
    expect(rows, hasLength(10));
    expect(rows[9].slot, same(plan[9]));
  });
}
