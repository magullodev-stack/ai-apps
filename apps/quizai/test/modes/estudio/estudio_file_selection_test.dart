import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/coverage/coverage_route.dart';
import 'package:quizai/modes/estudio/estudio_document_extractor.dart';
import 'package:quizai/modes/estudio/estudio_document_store.dart';
import 'package:quizai/modes/estudio/estudio_file_picker.dart';
import 'package:quizai/modes/estudio/estudio_generation.dart';
import 'package:quizai/modes/estudio/estudio_page.dart';
import 'package:quizai/modes/estudio/study_document.dart';
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


final class _FakeExtractor implements EstudioDocumentExtractor {
  @override
  Future<StudyDocument> extract(EstudioPickedFile file) async => StudyDocument(
    id: 'doc-1',
    sourceName: file.name,
    sourceExtension: file.extension,
    createdAt: DateTime.utc(2026, 10, 7),
    sections: [
      StudySection(
        id: 's1',
        title: 'Tema 1',
        blocks: const [
          StudyContentBlock(
            id: 'b1',
            text: 'Contenido real del tema uno.',
            sourceLocator: 'página 1',
          ),
        ],
        subsections: const [],
      ),
    ],
    chunks: const [
      StudyChunk(
        id: 'c1',
        sectionId: 's1',
        subsectionId: null,
        blockIds: ['b1'],
        text: 'Contenido real del tema uno.',
      ),
    ],
  );
}

final class _MemoryStore implements EstudioDocumentStore {
  StudyDocument? document;

  @override
  Future<void> clear() async => document = null;

  @override
  Future<StudyDocument?> load() async => document;

  @override
  Future<void> save(StudyDocument value) async => document = value;
}

void main() {
  test('la política de Estudio fija límites por formato y contenido', () {
    expect(EstudioMaterialPolicy.maxPdfSizeMegabytes, 25);
    expect(EstudioMaterialPolicy.maxDocxSizeMegabytes, 10);
    expect(EstudioMaterialPolicy.maxPptxSizeMegabytes, 20);
    expect(EstudioMaterialPolicy.maxImageSizeMegabytes, 10);
    expect(EstudioMaterialPolicy.maxPdfPages, 300);
    expect(EstudioMaterialPolicy.maxDocxWords, 75000);
    expect(EstudioMaterialPolicy.maxPptxSlides, 100);
  });

  test('aplica el límite de tamaño correspondiente a cada formato', () {
    const cases = <(String, int)>[
      ('pdf', 25),
      ('docx', 10),
      ('pptx', 20),
      ('jpg', 10),
      ('jpeg', 10),
      ('png', 10),
    ];

    for (final (extension, maxMegabytes) in cases) {
      validateEstudioPickedFile(
        EstudioPickedFile(
          name: 'material.$extension',
          path: '/tmp/material.$extension',
          sizeBytes: maxMegabytes * 1024 * 1024,
          extension: extension,
        ),
      );
      expect(
        () => validateEstudioPickedFile(
          EstudioPickedFile(
            name: 'material.$extension',
            path: '/tmp/material.$extension',
            sizeBytes: (maxMegabytes * 1024 * 1024) + 1,
            extension: extension,
          ),
        ),
        throwsA(
          isA<EstudioFileTooLargeException>().having(
            (error) => error.maxSizeMegabytes,
            'maxSizeMegabytes',
            maxMegabytes,
          ),
        ),
      );
    }
  });

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
          documentExtractor: _FakeExtractor(),
          documentStore: _MemoryStore(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('estudio-upload-file')));
    await tester.pumpAndSettle();

    expect(pickerCalls, 1);
    expect(find.byKey(const Key('estudio-selected-file')), findsOneWidget);
    expect(find.text('Tema 1.pdf'), findsOneWidget);
    expect(find.text('1.5 KB'), findsOneWidget);
    expect(find.byKey(const Key('estudio-study-document')), findsOneWidget);
    expect(find.text('Tema 1'), findsOneWidget);
    expect(find.text('1 sección detectada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Estudio informa del límite específico del formato', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EstudioPage(
          generator: _UnusedPivotGenerator(),
          questionGenerator: _UnusedQuestionGenerator(),
          filePicker: () async => const EstudioPickedFile(
            name: 'apuntes.docx',
            path: '/tmp/apuntes.docx',
            sizeBytes: (10 * 1024 * 1024) + 1,
            extension: 'docx',
          ),
          documentExtractor: _FakeExtractor(),
          documentStore: _MemoryStore(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('estudio-upload-file')));
    await tester.pumpAndSettle();

    expect(
      find.text('El archivo supera el límite de 10 MB para este formato.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('estudio-selected-file')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
