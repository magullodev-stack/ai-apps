import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/coverage/coverage_route.dart';
import 'package:quizai/modes/estudio/estudio_file_picker.dart';
import 'package:quizai/modes/estudio/estudio_generation.dart';
import 'package:quizai/modes/estudio/estudio_page.dart';
import 'package:quizai/semantic_catalog/pivot_catalog.dart';

final class _UnusedPivotGenerator implements PivotCatalogGenerator {
  @override
  Future<PivotCatalog> generateCatalog(String context) =>
      Future.error(StateError('No se usa en esta prueba.'));
}

final class _UnusedQuestionGenerator implements EstudioQuestionGenerator {
  @override
  Future<List<EstudioQuestion>> generateQuestions(CoverageRoute route) async =>
      const <EstudioQuestion>[];
}

void main() {
  testWidgets('Estudio muestra el archivo elegido por el selector', (
    tester,
  ) async {
    var pickerCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: EstudioPage(
          generator: _UnusedPivotGenerator(),
          questionGenerator: _UnusedQuestionGenerator(),
          filePicker: () async {
            pickerCalls++;
            return const EstudioPickedFile(
              name: 'Tema 1.pdf',
              path: '/tmp/Tema 1.pdf',
              sizeBytes: 1536,
              extension: 'pdf',
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('estudio-upload-file')));
    await tester.pumpAndSettle();

    expect(pickerCalls, 1);
    expect(find.byKey(const Key('estudio-selected-file')), findsOneWidget);
    expect(find.text('Tema 1.pdf'), findsOneWidget);
    expect(find.text('1.5 KB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
