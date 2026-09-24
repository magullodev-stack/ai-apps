import 'dart:async';
import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/app/app.dart';
import 'package:quizai/modes/quiz10/quiz.dart';
import 'package:quizai/modes/quiz10/quiz_generation.dart';

import '../modes/quiz10/fixtures.dart';

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
  testWidgets(
    'La navegacion inferior muestra una capsula activa de media barra',
    (tester) async {
      await tester.pumpWidget(const QuizAIApp());

      final bar = find.byKey(const Key('quizai-bottom-nav'));
      final active = find.byKey(const Key('quizai-nav-active'));

      expect(bar, findsOneWidget);
      expect(active, findsOneWidget);

      final barWidth = tester.getSize(bar).width;
      final activeSize = tester.getSize(active);

      expect(activeSize.width, greaterThan(barWidth * 0.4));
      expect(activeSize.height, greaterThan(60));

      expect(
        find.descendant(of: active, matching: find.text('Modalidades')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('quizai-nav-perfil')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: active, matching: find.text('Perfil')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('quizai-nav-modalidades')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: active, matching: find.text('Modalidades')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('QuizAI aplica su identidad tipográfica común', (tester) async {
    await tester.pumpWidget(const QuizAIApp());

    final context = tester.element(find.text('QuizAI'));
    final theme = Theme.of(context);

    expect(theme.textTheme.bodyMedium?.fontFamily, 'Nunito');
    expect(theme.textTheme.titleLarge?.fontFamily, 'Nunito');
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w800);
    expect(theme.textTheme.labelLarge?.fontWeight, FontWeight.w800);

    // El logotipo y la navegación continúan disponibles.
    expect(find.byType(Image), findsNWidgets(5));
    expect(find.byKey(const Key('quizai-bottom-nav')), findsOneWidget);
  });

  testWidgets(
    'QuizAI muestra cuatro modalidades ordenadas sin generar preguntas',
    (tester) async {
      final generator = FakeGenerator();
      await tester.pumpWidget(QuizAIApp(generator: generator));
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
        'QuizAI',
      );
      expect(find.text('QuizAI'), findsOneWidget);
      final titles = ['Quiz10', 'Sala', '1vs1', 'Estudio'];
      final positions = titles
          .map((title) => tester.getTopLeft(find.text(title)).dy)
          .toList();

      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]));
      }

      for (final title in titles) {
        final entry = find.text(title);
        expect(entry, findsOneWidget);
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        expect(entry.hitTestable(), findsOneWidget);
      }

      for (final id in ['sala', '1vs1', 'estudio']) {
        final card = find.byKey(Key('quizai-card-$id'));

        expect(card, findsOneWidget);

        final inkWell = find.descendant(
          of: card,
          matching: find.byType(InkWell),
        );

        expect(tester.widget<InkWell>(inkWell).onTap, isNull);
      }
      for (final title in titles.skip(1)) {
        final card = find.ancestor(
          of: find.text(title),
          matching: find.byType(InkWell),
        );
        expect(tester.widget<InkWell>(card.first).onTap, isNull);
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.text('QuizAI'), findsOneWidget);
      }
      expect(generator.calls, 0);
    },
  );

  testWidgets(
    'Perfil sustituye el contenido y Modalidades restaura las entradas',
    (tester) async {
      await tester.pumpWidget(const QuizAIApp());
      final initialBarPosition = tester.getTopLeft(
        find.byKey(const Key('quizai-bottom-nav')),
      );
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(find.text('Quiz10'), findsNothing);
      expect(find.text('Perfil'), findsNWidgets(2));
      expect(find.text('Todavía no disponible.'), findsOneWidget);
      expect(find.text('QuizAI'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('quizai-bottom-nav'))),
        initialBarPosition,
      );
      await tester.tap(find.byIcon(Icons.grid_view_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Quiz10'), findsOneWidget);
      expect(find.text('Todavía no disponible.'), findsNothing);
      for (final id in ['sala', '1vs1', 'estudio']) {
        final card = find.byKey(Key('quizai-card-$id'));

        expect(card, findsOneWidget);

        final inkWell = find.descendant(
          of: card,
          matching: find.byType(InkWell),
        );

        expect(tester.widget<InkWell>(inkWell).onTap, isNull);
      }
    },
  );

  testWidgets(
    'Configuración abre y vuelve conservando la pestaña seleccionada',
    (tester) async {
      await tester.pumpWidget(const QuizAIApp());
      for (final profile in [false, true]) {
        if (profile) {
          await tester.tap(find.byIcon(Icons.person_outline));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('Configuración'));
        await tester.pumpAndSettle();
        expect(find.text('Configuración'), findsOneWidget);
        expect(find.text('Todavía no disponible.'), findsOneWidget);
        expect(find.byKey(const Key('quizai-bottom-nav')), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('QuizAI'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('quizai-nav-active')),
            matching: find.text(profile ? 'Perfil' : 'Modalidades'),
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'Quiz10 abre directamente la partida y permite volver a Modalidades',
    (tester) async {
      final generator = FakeGenerator();
      await tester.pumpWidget(QuizAIApp(generator: generator));
      await tester.tap(find.text('Quiz10'));
      await tester.pumpAndSettle();
      expect(generator.calls, 1);
      expect(find.text('Pregunta 1 de 10'), findsOneWidget);
      expect(find.text('🎲 Quiz10'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('QuizAI'), findsOneWidget);
      for (final id in ['sala', '1vs1', 'estudio']) {
        final card = find.byKey(Key('quizai-card-$id'));

        expect(card, findsOneWidget);

        final inkWell = find.descendant(
          of: card,
          matching: find.byType(InkWell),
        );

        expect(tester.widget<InkWell>(inkWell).onTap, isNull);
      }
      expect(find.byKey(const Key('quizai-bottom-nav')), findsOneWidget);
      expect(generator.calls, 1);
    },
  );

  testWidgets('carga única, diez respuestas, resultado y otra partida', (
    tester,
  ) async {
    final generator = FakeGenerator()
      ..pending = Completer<List<QuizQuestion>>();
    await tester.pumpWidget(QuizAIApp(generator: generator));
    expect(generator.calls, 0);
    await tester.tap(find.text('Quiz10'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
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
        await tester.pumpWidget(QuizAIApp(generator: generator));
        await tester.tap(find.text('Quiz10'));
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
      await tester.pumpWidget(QuizAIApp(generator: generator));
      await tester.tap(find.text('Quiz10'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(generator.calls, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      generator.pending!.complete(fixtureQuestions(selectQuizAreas(Random(1))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('QuizAI'), findsOneWidget);
    },
  );
  testWidgets('Las cuatro tarjetas caben completas en la pantalla principal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(329, 752);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const QuizAIApp());
    await tester.pumpAndSettle();

    final hero = find.byKey(const Key('quizai-hero'));
    final sala = find.byKey(const Key('quizai-card-sala'));
    final versus = find.byKey(const Key('quizai-card-1vs1'));
    final estudio = find.byKey(const Key('quizai-card-estudio'));
    final nav = find.byKey(const Key('quizai-bottom-nav'));

    expect(hero, findsOneWidget);
    expect(sala, findsOneWidget);
    expect(versus, findsOneWidget);
    expect(estudio, findsOneWidget);

    expect(
      tester.getSize(hero).height,
      greaterThan(tester.getSize(sala).height),
    );

    expect(tester.getSize(sala).height, tester.getSize(versus).height);

    expect(tester.getSize(versus).height, tester.getSize(estudio).height);

    expect(
      tester.getBottomRight(estudio).dy,
      lessThanOrEqualTo(tester.getTopLeft(nav).dy),
    );

    for (final id in ['quiz10', 'sala', '1vs1', 'estudio']) {
      expect(find.byKey(Key('quizai-image-$id')), findsOneWidget);
    }

    expect(tester.takeException(), isNull);
  });
}
