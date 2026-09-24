import 'dart:async';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz10/main.dart';
import 'package:quiz10/quiz.dart';
import 'package:quiz10/quiz_generation.dart';

import 'fixtures.dart';

class FakeGenerator implements QuizGenerator {
  int calls = 0;
  Object? failure;
  Completer<List<QuizQuestion>>? pending;
  List<QuizSlot>? lastPlan;

  @override
  Future<List<QuizQuestion>> generate(List<QuizSlot> plan) async {
    calls++;
    lastPlan = plan;
    if (failure case final error?) throw error;
    if (pending case final completer?) return completer.future;
    return fixtureQuestions(plan);
  }
}

void main() {
  testWidgets('carga única, diez respuestas, resultado y otra partida', (
    tester,
  ) async {
    final generator = FakeGenerator()
      ..pending = Completer<List<QuizQuestion>>();
    await tester.pumpWidget(Quiz10App(generator: generator));
    expect(generator.calls, 0);
    await tester.tap(find.text('🎲 Jugar'));
    await tester.pump();
    expect(find.text('Generando tus diez preguntas…'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(generator.calls, 1);
    generator.pending!.complete(fixtureQuestions(generator.lastPlan!));
    await tester.pumpAndSettle();
    for (var i = 1; i <= 10; i++) {
      expect(find.text('Pregunta $i de 10'), findsOneWidget);
      expect(find.text('Siguiente'), findsNothing);
      final answer = find.text(i.isEven ? 'Alternativa A $i' : 'Correcta $i');
      await tester.ensureVisible(answer);
      await tester.tap(answer);
      await tester.pumpAndSettle();
      expect(find.text('Aciertos: ${(i + 1) ~/ 2}'), findsOneWidget);
      expect(
        find.text(i.isEven ? 'Respuesta correcta: Correcta $i' : '¡Correcto!'),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<OutlinedButton>(find.byType(OutlinedButton))
            .every((button) => button.onPressed == null),
        true,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        i / 10,
      );
      final next = find.text(i == 10 ? 'Ver resultado' : 'Siguiente');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('Partida completada'), findsOneWidget);
    expect(find.text('Resultado: 5 / 10 aciertos'), findsOneWidget);
    generator.pending = null;
    await tester.tap(find.text('🎲 Otra partida'));
    await tester.pumpAndSettle();
    expect(generator.calls, 2);
    expect(find.text('Pregunta 1 de 10'), findsOneWidget);
    expect(find.text('Aciertos: 0'), findsOneWidget);
  });

  for (final failure in [
    const FormatException('invalid'),
    const AiAppsException(502),
    TimeoutException('timeout'),
    StateError('config'),
  ]) {
    testWidgets(
      'error recuperable ($failure) no inicia partida y permite reintentar',
      (tester) async {
        final generator = FakeGenerator()..failure = failure;
        await tester.pumpWidget(Quiz10App(generator: generator));
        await tester.tap(find.text('🎲 Jugar'));
        await tester.pumpAndSettle();
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.text('Pregunta 1 de 10'), findsNothing);
        expect(
          find.textContaining(
            failure is FormatException
                ? 'no son válidas'
                : failure is TimeoutException
                ? 'demasiado'
                : failure is StateError
                ? 'No se ha configurado'
                : 'No se han podido',
          ),
          findsOneWidget,
        );
        generator.failure = null;
        await tester.tap(find.text('🎲 Jugar'));
        await tester.pumpAndSettle();
        expect(find.text('Pregunta 1 de 10'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'cerrar la pantalla durante la generación no actualiza un widget desmontado',
    (tester) async {
      final generator = FakeGenerator()
        ..pending = Completer<List<QuizQuestion>>();
      await tester.pumpWidget(Quiz10App(generator: generator));
      await tester.tap(find.text('🎲 Jugar'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      generator.pending!.complete(fixtureQuestions(selectQuizAreas(Random(1))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
