import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/app/app_theme.dart';
import 'package:quizai/coverage/coverage_route.dart';
import 'package:quizai/modes/estudio/estudio_generation.dart';
import 'package:quizai/modes/estudio/estudio_page.dart';
import 'package:quizai/semantic_catalog/pivot_catalog.dart';

import 'fixtures.dart';

class _CatalogGenerator implements PivotCatalogGenerator {
  var pending = Completer<PivotCatalog>();
  final contexts = <String>[];

  @override
  Future<PivotCatalog> generateCatalog(String context) {
    contexts.add(context);
    return pending.future;
  }
}

class _QuestionGenerator implements EstudioQuestionGenerator {
  var pending = Completer<List<EstudioQuestion>>();
  final routes = <CoverageRoute>[];

  @override
  Future<List<EstudioQuestion>> generateQuestions(CoverageRoute route) {
    routes.add(route);
    return pending.future;
  }
}

Widget _app(_CatalogGenerator catalog, _QuestionGenerator questions) =>
    MaterialApp(
      theme: quizAITheme,
      home: EstudioPage(
        generator: catalog,
        questionGenerator: questions,
        random: Random(42),
      ),
    );

void main() {
  testWidgets('tema → ruta interna → diez preguntas → partida y resultado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(329, 752);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalogGenerator = _CatalogGenerator();
    final questionGenerator = _QuestionGenerator();
    await tester.pumpWidget(_app(catalogGenerator, questionGenerator));
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'topic',
    );
    expect(
      tester
          .widget<RadioListTile<String>>(
            find.widgetWithText(RadioListTile<String>, 'Sube un archivo'),
          )
          .enabled,
      false,
    );
    await tester.tap(find.text('Generar'));
    await tester.pump();
    expect(find.text('Escribe un tema antes de generar.'), findsOneWidget);
    expect(catalogGenerator.contexts, isEmpty);

    const context = '  Océanos y clima  ';
    await tester.enterText(find.byType(TextField), context);
    await tester.tap(find.text('Generar'));
    await tester.pump();
    expect(catalogGenerator.contexts, [context]);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Generar'), findsNothing);
    expect(questionGenerator.routes, isEmpty);
    final catalog = PivotCatalog.fromJson(pivotJson(context));
    catalogGenerator.pending.complete(catalog);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Ruta de Cobertura'), findsNothing);
    expect(questionGenerator.routes, hasLength(1));
    final actual = questionGenerator.routes.single;
    final expected = compileCoverageRoute(catalog, Random(42));
    expect(actual.context, context);
    for (var i = 0; i < 10; i++) {
      expect(actual.rows[i].pivot, same(expected.rows[i].pivot));
      expect(actual.rows[i].pivot.code, expected.rows[i].pivot.code);
      expect(actual.rows[i].dimension, same(expected.rows[i].dimension));
      expect(actual.rows[i].role, same(expected.rows[i].role));
      expect(actual.rows[i].distractors, expected.rows[i].distractors);
    }
    questionGenerator.pending.complete(estudioQuestions());
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    for (var n = 1; n <= 10; n++) {
      expect(find.text('Pregunta $n de 10'), findsOneWidget);
      expect(find.text('Hecho interno $n'), findsNothing);
      expect(find.textContaining('Pivote'), findsNothing);
      expect(find.textContaining('Atractor'), findsNothing);
      expect(find.textContaining('Dimensión'), findsNothing);
      expect(find.textContaining('Rol'), findsNothing);
      expect(find.textContaining('Competitividad'), findsNothing);
      expect(find.byType(OutlinedButton), findsNWidgets(4));
      expect(find.text('Siguiente'), findsNothing);
      final answer = find.text(n.isOdd ? 'Correcta $n' : 'Alternativa A $n');
      await tester.ensureVisible(answer);
      await tester.tap(answer);
      await tester.pumpAndSettle();
      expect(find.text('Aciertos: ${(n + 1) ~/ 2}'), findsOneWidget);
      expect(
        find.text(n.isOdd ? '¡Correcto!' : 'Respuesta correcta: Correcta $n'),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<OutlinedButton>(find.byType(OutlinedButton))
            .every((button) => button.onPressed == null),
        true,
      );
      await tester.ensureVisible(find.text('Siguiente'));
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Resultado: 5 / 10 aciertos'), findsOneWidget);
    await tester.tap(find.text('Escribir otro tema'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(catalogGenerator.contexts, hasLength(1));
    expect(questionGenerator.routes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final factual in [false, true]) {
    testWidgets('error recuperable en ${factual ? 'preguntas' : 'catálogo'}', (
      tester,
    ) async {
      final catalog = _CatalogGenerator();
      final questions = _QuestionGenerator();
      await tester.pumpWidget(_app(catalog, questions));
      await tester.enterText(find.byType(TextField), 'Historia');
      await tester.tap(find.text('Generar'));
      await tester.pump();
      if (factual) {
        catalog.pending.complete(
          PivotCatalog.fromJson(pivotJson('Historia')),
        );
        await tester.pump();
        // A replacement provider must not start an incomplete game either.
        questions.pending.complete(estudioQuestions().take(9).toList());
      } else {
        catalog.pending.completeError(const FormatException('invalid'));
      }
      await tester.pumpAndSettle();
      expect(
        find.text('La generación recibida no es válida. Vuelve a generar.'),
        findsOneWidget,
      );
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      catalog.pending = Completer<PivotCatalog>();
      questions.pending = Completer<List<EstudioQuestion>>();
      await tester.tap(find.text('Generar'));
      await tester.pump();
      catalog.pending.complete(
        PivotCatalog.fromJson(pivotJson('Historia')),
      );
      await tester.pump();
      questions.pending.complete(estudioQuestions());
      await tester.pumpAndSettle();
      expect(find.text('Pregunta 1 de 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'salir durante ${factual ? 'TERRA' : 'Luna'} no actualiza la pantalla',
      (tester) async {
        final catalog = _CatalogGenerator();
        final questions = _QuestionGenerator();
        await tester.pumpWidget(_app(catalog, questions));
        await tester.enterText(find.byType(TextField), 'Historia');
        await tester.tap(find.text('Generar'));
        await tester.pump();
        if (factual) {
          catalog.pending.complete(
            PivotCatalog.fromJson(pivotJson('Historia')),
          );
          await tester.pump();
        }
        await tester.pumpWidget(const SizedBox());
        if (factual) {
          questions.pending.complete(estudioQuestions());
        } else {
          catalog.pending.complete(
            PivotCatalog.fromJson(pivotJson('Historia')),
          );
        }
        await tester.pumpAndSettle();
        expect(questions.routes, hasLength(factual ? 1 : 0));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Map<String, dynamic> pivotJson(String context) => {
  'context': context,
  'pivots': [for (var i = 1; i <= 10; i++) 'Pivote $i'],
};
