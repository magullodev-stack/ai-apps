import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz10/quiz.dart';

import 'fixtures.dart';

void main() {
  final plan = selectQuizAreas(Random(7));

  test(
    'selecciona diez áreas distintas de las dieciocho y respeta la progresión',
    () {
      final selections = <String>{};
      final seen = <String>{};
      expect(quizAreas.toSet(), hasLength(18));
      for (var seed = 0; seed < 100; seed++) {
        final slots = selectQuizAreas(Random(seed));
        final areas = slots.map((slot) => slot.area).toList();
        expect(areas, hasLength(10));
        expect(areas.toSet(), hasLength(10));
        expect(quizAreas, containsAll(areas));
        expect(slots.map((slot) => slot.difficulty), [
          'Fácil',
          'Fácil',
          'Fácil',
          'Fácil',
          'Moderado',
          'Moderado',
          'Moderado',
          'Difícil',
          'Difícil',
          'Muy difícil',
        ]);
        selections.add(areas.join('|'));
        seen.addAll(areas);
      }
      expect(selections.length, greaterThan(1));
      expect(seen, quizAreas.toSet());
    },
  );

  test('valida las diez filas, conserva el orden y baraja las opciones', () {
    final positions = <int>{};
    for (var seed = 0; seed < 20; seed++) {
      final questions = validateQuestions(
        fixtureJson(plan),
        plan,
        Random(seed),
      );
      expect(questions, hasLength(10));
      for (var i = 0; i < 10; i++) {
        final question = questions[i];
        expect(question.slot, plan[i]);
        expect(question.text, 'Pregunta de prueba ${i + 1}');
        expect(question.options.toSet(), {
          'Correcta ${i + 1}',
          'Alternativa A ${i + 1}',
          'Alternativa B ${i + 1}',
          'Alternativa C ${i + 1}',
        });
        positions.add(question.options.indexOf(question.correct));
      }
    }
    expect(positions, {0, 1, 2, 3});
  });

  for (final value in ['no json', 'null', '[]', '{}', '{"preguntas":{}}']) {
    test('rechaza estructura inválida: $value', () {
      expect(
        () => validateQuestions(value, plan, Random(1)),
        throwsFormatException,
      );
    });
  }

  for (final count in [0, 9, 11]) {
    test('rechaza $count filas', () {
      final rows = fixtureRows(plan);
      final payload = jsonEncode({
        'preguntas': [for (var i = 0; i < count; i++) rows[i % 10]],
      });
      expect(
        () => validateQuestions(payload, plan, Random(1)),
        throwsFormatException,
      );
    });
  }

  for (final field in quizFields) {
    for (final value in [null, '', '  \n ', 123]) {
      test('rechaza campo $field incompleto o de tipo incorrecto ($value)', () {
        final rows = fixtureRows(plan);
        rows.last[field] = value;
        expect(
          () => validateQuestions(
            jsonEncode({'preguntas': rows}),
            plan,
            Random(1),
          ),
          throwsFormatException,
        );
      });
    }
    test('rechaza campo ausente: $field', () {
      final rows = fixtureRows(plan);
      rows.first.remove(field);
      expect(
        () =>
            validateQuestions(jsonEncode({'preguntas': rows}), plan, Random(1)),
        throwsFormatException,
      );
    });
  }

  test('rechaza filas que cambian área, dificultad u orden', () {
    for (final field in ['Área', 'Dificultad']) {
      final rows = fixtureRows(plan);
      rows.first[field] = field == 'Área' ? plan[1].area : 'Muy difícil';
      expect(
        () =>
            validateQuestions(jsonEncode({'preguntas': rows}), plan, Random(1)),
        throwsFormatException,
      );
    }
    expect(
      () => validateQuestions(
        jsonEncode({'preguntas': fixtureRows(plan).reversed.toList()}),
        plan,
        Random(1),
      ),
      throwsFormatException,
    );
  });

  test('rechaza filas no objeto y campos adicionales', () {
    for (final row in [
      null,
      [],
      'fila',
      {...fixtureRows(plan).first, 'extra': 'valor'},
    ]) {
      final rows = <Object?>[...fixtureRows(plan)];
      rows[0] = row;
      expect(
        () =>
            validateQuestions(jsonEncode({'preguntas': rows}), plan, Random(1)),
        throwsFormatException,
      );
    }
  });

  test('rechaza cualquier par de opciones duplicadas ignorando espacios y mayúsculas', () {
    final fields = quizFields.skip(3).toList();
    for (var i = 0; i < fields.length; i++) {
      for (var j = i + 1; j < fields.length; j++) {
        final rows = fixtureRows(plan);
        rows.first[fields[i]] = 'Una respuesta';
        rows.first[fields[j]] = '  UNA   RESPUESTA  ';
        expect(
          () => validateQuestions(
            jsonEncode({'preguntas': rows}),
            plan,
            Random(1),
          ),
          throwsFormatException,
        );
      }
    }
  });

  test(
    'respuestas, puntuación y progreso hasta terminar sin dobles aciertos',
    () {
      final game = QuizGame(fixtureQuestions(plan));
      expect(game.progress, 0);
      game.next();
      expect(game.questionNumber, 1);
      expect(() => game.answer(4), throwsRangeError);
      expect(game.answered, false);
      for (var i = 0; i < 10; i++) {
        expect(game.questionNumber, i + 1);
        expect(game.current.slot, plan[i]);
        final correctIndex = game.current.options.indexOf(game.current.correct);
        final hit = i.isEven;
        game.answer(hit ? correctIndex : (correctIndex + 1) % 4);
        expect(game.isCorrect, hit);
        expect(game.score, (i + 2) ~/ 2);
        expect(game.answeredCount, i + 1);
        expect(game.progress, (i + 1) / 10);
        final selected = game.selectedIndex;
        game.answer(correctIndex);
        expect(game.selectedIndex, selected);
        expect(game.score, (i + 2) ~/ 2);
        game.next();
      }
      expect(game.finished, true);
      expect(game.progress, 1);
      expect(game.score, 5);
      game.next();
      game.answer(0);
      expect(game.questionNumber, 10);
      expect(game.score, 5);
      final freshGame = QuizGame(fixtureQuestions(plan));
      expect(freshGame.score, 0);
      expect(freshGame.progress, 0);
      expect(freshGame.finished, false);
    },
  );

  test('puntuaciones extremas y partida incompleta', () {
    expect(() => QuizGame([]), throwsArgumentError);
    for (final hit in [true, false]) {
      final game = QuizGame(fixtureQuestions(plan));
      for (var i = 0; i < 10; i++) {
        final correctIndex = game.current.options.indexOf(game.current.correct);
        game.answer(hit ? correctIndex : (correctIndex + 1) % 4);
        game.next();
      }
      expect(game.score, hit ? 10 : 0);
    }
  });
}
