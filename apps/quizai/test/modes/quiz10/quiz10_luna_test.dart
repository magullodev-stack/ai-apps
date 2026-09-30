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
      'respuesta_correcta': 'Respuesta ${slot.number}',
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
    expect(itemSchema['required'], ['id', 'pregunta', 'respuesta_correcta']);
    expect((itemSchema['properties'] as Map).keys, ['id', 'pregunta', 'respuesta_correcta']);
  });

  test('control sin D mantiene P, dificultades y fórmula, sin transmitir D', () {
    final plan = selectQuiz10LunaPlan(Random(20260929));
    final original = quiz10LunaPrompt(plan);
    final control = quiz10LunaPromptSinD(plan);
    expect(control, contains('d(R₁) < d(R₂) < ... < d(R₁₀)'));
    expect(control, contains('id(Rᵢ) ∉ {id(Rⱼ) : j < i}'));
    expect(control, contains('{id, pregunta, respuesta_correcta}'));
    expect(control, isNot(contains('Dᵢ')));
    for (final slot in plan) {
      expect(original, contains(slot.dimension.instruction));
      expect(
        control,
        contains('| ${slot.number} | ${slot.pivot} | ${slot.difficulty} |'),
      );
      expect(control, isNot(contains(slot.dimension.code)));
      expect(control, isNot(contains(slot.dimension.instruction)));
    }
  });

  test('U se añade al control sin D sin alterar P ni dificultad', () {
    final plan = selectQuiz10LunaPlan(Random(20260929));
    final control = quiz10LunaPromptSinD(plan);
    final initial = quiz10LunaPromptSinD(plan, historialU: []);
    final subsequent = quiz10LunaPromptSinD(
      plan,
      historialU: ['Miguel de Cervantes', 'Marte'],
    );

    expect(control, isNot(contains('U:')));
    expect(control, contains('id(Rᵢ) ∉ {id(Rⱼ) : j < i}'));
    expect(initial, contains('id(Rᵢ) ∉ U ∪ {id(Rⱼ) : j < i}'));
    expect(initial, contains('U:\n∅'));
    expect(subsequent, contains('U:\n- Miguel de Cervantes\n- Marte'));
    expect(subsequent, contains('id(Rᵢ) ∉ U ∪ {id(Rⱼ) : j < i}'));
    expect(subsequent, contains('d(R₁) < d(R₂) < ... < d(R₁₀)'));
    expect(subsequent, contains('| id | Pᵢ | Dificultad | Rᵢ |'));
    expect(subsequent, isNot(contains('Dᵢ')));
    for (final slot in plan) {
      expect(
        subsequent,
        contains('| ${slot.number} | ${slot.pivot} | ${slot.difficulty} | |'),
      );
      expect(subsequent, isNot(contains(slot.dimension.code)));
      expect(subsequent, isNot(contains(slot.dimension.instruction)));
    }
    expect(subsequent, isNot(contains('U:\n∅')));
  });

  test('restricciones de longitud y de filtración en ambos prompts', () {
    final plan = selectQuiz10LunaPlan(Random(20260929));
    final prompts = [
      quiz10LunaPrompt(plan),
      quiz10LunaPromptSinD(plan),
      quiz10LunaPromptSinD(plan, historialU: ['Miguel de Cervantes']),
    ];
    for (final prompt in prompts) {
      expect(prompt, contains('4 ≤ palabras(Qᵢ) ≤ 16'));
      expect(prompt, contains('1 ≤ palabras(Rᵢ) ≤ 6'));
      expect(prompt, contains('Qᵢ no contiene Rᵢ ni palabras distintivas de Rᵢ,'));
      expect(prompt, contains('incluidos nombres propios, epónimos y siglas.'));
    }
  });

  test('bancos D15/D86 equilibrados por posición y sin repetir D', () {
    const seed = 20260929;
    expect(quiz10CandidateDimensionCodes, hasLength(15));
    expect(quiz10CandidateDimensionCodes.toSet(), hasLength(15));
    for (final size in [15, 86]) {
      final byPosition = [
        for (var i = 0; i < 10; i++) <String, int>{},
      ];
      for (var call = 0; call < 200; call++) {
        final original = selectQuiz10LunaPlan(Random(seed + call));
        final selected = selectQuiz10LunaPlanBancoD(
          Random(seed + call),
          bancoD: size,
          callIndex: call,
          seed: seed,
        );
        expect(selected, hasLength(10));
        expect(selected.map((slot) => slot.dimension.code).toSet(), hasLength(10));
        for (var row = 0; row < 10; row++) {
          expect(selected[row].number, original[row].number);
          expect(selected[row].pivot, original[row].pivot);
          expect(selected[row].difficulty, original[row].difficulty);
          if (size == 15) {
            expect(
              quiz10CandidateDimensionCodes,
              contains(selected[row].dimension.code),
            );
          }
          byPosition[row].update(
            selected[row].dimension.code,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
      for (final counts in byPosition) {
        expect(counts.keys, hasLength(size));
        expect(
          counts.values.every(
            (count) => count == 200 ~/ size || count == (200 ~/ size) + 1,
          ),
          isTrue,
        );
        expect(counts.values.reduce((a, b) => a + b), 200);
      }
    }
  });

  test('comparación D15/D86 solo cambia las D de la tabla', () {
    const seed = 20260929;
    final original = selectQuiz10LunaPlanBancoD(
      Random(seed), bancoD: 86, callIndex: 0, seed: seed,
    );
    final candidate = selectQuiz10LunaPlanBancoD(
      Random(seed), bancoD: 15, callIndex: 0, seed: seed,
    );
    final prompt86 = quiz10LunaPromptComparacionBancosD(original);
    final prompt15 = quiz10LunaPromptComparacionBancosD(candidate);
    expect(prompt86.split('| id | Pᵢ |').first, prompt15.split('| id | Pᵢ |').first);
    for (final prompt in [prompt86, prompt15]) {
      expect(prompt, contains('max(d(R₁),...,d(R₄)) < min(d(R₅),...,d(R₇))'));
      expect(prompt, contains('max(d(R₅),...,d(R₇)) < min(d(R₈),d(R₉))'));
      expect(prompt, contains('max(d(R₈),d(R₉)) < d(R₁₀)'));
      expect(prompt, contains('4 ≤ palabras(Qᵢ) ≤ 24'));
      expect(prompt, contains('1 ≤ palabras(Rᵢ) ≤ 8'));
      expect(prompt, contains('Rᵢ no repite ni equivale semánticamente'));
      expect(prompt, contains('Qᵢ no contiene Rᵢ ni palabras distintivas de Rᵢ'));
    }
    expect(quiz10LunaPrompt(original), contains('d(R₁) < d(R₂) < ... < d(R₁₀)'));
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
      jsonEncode({'preguntas': [{...items.first, 'respuesta_correcta': ' '}, ...items.skip(1)]}),
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
