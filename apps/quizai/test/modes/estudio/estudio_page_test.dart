import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/app/app_theme.dart';
import 'package:quizai/coverage/coverage_route.dart';
import 'package:quizai/modes/estudio/estudio_page.dart';
import 'package:quizai/semantic_catalog/semantic_catalog.dart';

import '../../semantic_catalog/fixtures.dart';

class _Generator implements SemanticCatalogGenerator {
  var pending = Completer<SemanticCatalog>();
  final contexts = <String>[];

  @override
  Future<SemanticCatalog> generateCatalog(String context) {
    contexts.add(context);
    return pending.future;
  }
}

void main() {
  testWidgets('tema, carga única y diez filas de la ruta compilada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(329, 752);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final generator = _Generator();
    await tester.pumpWidget(
      MaterialApp(
        theme: quizAITheme,
        home: EstudioPage(generator: generator, random: Random(42)),
      ),
    );
    expect(generator.contexts, isEmpty);
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'topic',
    );
    final file = tester.widget<RadioListTile<String>>(
      find.widgetWithText(RadioListTile<String>, 'Sube un archivo'),
    );
    expect(file.enabled, false);
    await tester.tap(find.text('Generar'));
    await tester.pump();
    expect(find.text('Escribe un tema antes de generar.'), findsOneWidget);
    expect(generator.contexts, isEmpty);

    const context = '  Océanos y clima  ';
    await tester.enterText(find.byType(TextField), context);
    await tester.tap(find.text('Generar'));
    await tester.pump();
    expect(generator.contexts, [context]);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, true);

    final catalog = SemanticCatalog.fromJson(catalogJson(context));
    final expected = compileCoverageRoute(catalog, Random(42));
    generator.pending.complete(catalog);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Ruta de Cobertura'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(10));
    for (final row in expected.rows) {
      final card = find.byKey(ValueKey('coverage-row-${row.number}'));
      for (final text in [
        'Fila ${row.number}',
        'Pivote ${row.pivot.code}: ${row.pivot.name}',
        'Atractor ${row.attractor.code}: ${row.attractor.name}',
        'Dimensión ${row.dimension.code}: ${row.dimension.name}',
        row.dimension.definition,
        'Rol ${row.role.code}: ${row.role.name}',
        row.role.definition,
        'Competitividad de distractores: ${row.distractors.map((d) => d.symbol).join(' / ')}',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsOneWidget,
        );
      }
    }
    await tester.ensureVisible(find.text('Fila 10'));
    expect(find.text('Fila 10').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error recuperable y nueva generación', (tester) async {
    final generator = _Generator();
    await tester.pumpWidget(
      MaterialApp(home: EstudioPage(generator: generator)),
    );
    await tester.enterText(find.byType(TextField), 'Historia');
    await tester.tap(find.text('Generar'));
    await tester.pump();
    generator.pending.completeError(const FormatException('invalid'));
    await tester.pumpAndSettle();
    expect(
      find.text('El catálogo recibido no es válido. Vuelve a generar.'),
      findsOneWidget,
    );
    expect(find.byType(Card), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    generator.pending = Completer<SemanticCatalog>();
    await tester.tap(find.text('Generar'));
    await tester.pump();
    generator.pending.complete(
      SemanticCatalog.fromJson(catalogJson('Historia')),
    );
    await tester.pumpAndSettle();
    expect(generator.contexts, ['Historia', 'Historia']);
    expect(find.text('Ruta de Cobertura'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(10));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'salir durante la generación no actualiza la pantalla desmontada',
    (tester) async {
      final generator = _Generator();
      await tester.pumpWidget(
        MaterialApp(home: EstudioPage(generator: generator)),
      );
      await tester.enterText(find.byType(TextField), 'Historia');
      await tester.tap(find.text('Generar'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      generator.pending.complete(
        SemanticCatalog.fromJson(catalogJson('Historia')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
