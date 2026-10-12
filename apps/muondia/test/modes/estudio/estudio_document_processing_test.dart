import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/modes/estudio/estudio_document_extractor.dart';
import 'package:muondia/modes/estudio/estudio_file_picker.dart';
import 'package:muondia/modes/estudio/study_document.dart';

void main() {
  test('DOCX conserva títulos, texto y fragmentación técnica', () async {
    final directory = await Directory.systemTemp.createTemp('muondia-docx-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tema.docx');

    final archive = Archive()
      ..add(
        ArchiveFile.bytes(
          'word/styles.xml',
          Uint8List.fromList(
            '''<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:style w:type="paragraph" w:styleId="Heading1">
                <w:name w:val="heading 1"/>
              </w:style>
              <w:style w:type="paragraph" w:styleId="Heading2">
                <w:name w:val="heading 2"/>
              </w:style>
            </w:styles>'''.codeUnits,
          ),
        ),
      )
      ..add(
        ArchiveFile.bytes(
          'word/document.xml',
          Uint8List.fromList(
            '''<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:body>
                <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Tema constitucional</w:t></w:r></w:p>
                <w:p><w:r><w:t>La soberanía nacional reside en el pueblo español.</w:t></w:r></w:p>
                <w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Derechos</w:t></w:r></w:p>
                <w:p><w:r><w:t>El texto reconoce derechos y libertades.</w:t></w:r></w:p>
              </w:body>
            </w:document>'''.codeUnits,
          ),
        ),
      );
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive));

    final document = await const LocalEstudioDocumentExtractor().extract(
      EstudioPickedFile(
        name: 'tema.docx',
        path: file.path,
        sizeBytes: await file.length(),
        extension: 'docx',
      ),
    );

    expect(document.sections, hasLength(1));
    expect(document.sections.single.title, 'Tema constitucional');
    expect(document.sections.single.blocks.single.text, contains('soberanía'));
    expect(document.sections.single.subsections.single.title, 'Derechos');
    expect(document.sections.single.subsections.single.text, contains('libertades'));
    expect(document.chunks, isNotEmpty);
    expect(document.quizUnits.map((unit) => unit.label), contains('Tema constitucional › Derechos'));
  });

  test('PPTX conserva una sección visible por diapositiva con texto', () async {
    final directory = await Directory.systemTemp.createTemp('muondia-pptx-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/clase.pptx');

    final archive = Archive()
      ..add(
        ArchiveFile.bytes(
          'ppt/slides/slide1.xml',
          Uint8List.fromList(
            '''<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
              <a:t>Introducción</a:t><a:t>Concepto principal de la clase.</a:t>
            </p:sld>'''.codeUnits,
          ),
        ),
      )
      ..add(
        ArchiveFile.bytes(
          'ppt/slides/slide2.xml',
          Uint8List.fromList(
            '''<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
              <a:t>Conclusiones</a:t><a:t>Segundo contenido verificable.</a:t>
            </p:sld>'''.codeUnits,
          ),
        ),
      );
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive));

    final document = await const LocalEstudioDocumentExtractor().extract(
      EstudioPickedFile(
        name: 'clase.pptx',
        path: file.path,
        sizeBytes: await file.length(),
        extension: 'pptx',
      ),
    );

    expect(document.sections, hasLength(2));
    expect(document.sections.first.title, 'Introducción');
    expect(document.sections.first.text, 'Concepto principal de la clase.');
    expect(document.sections.last.title, 'Conclusiones');
  });

  test('DOCX aplica el límite documental de palabras al contenido real', () async {
    final directory = await Directory.systemTemp.createTemp('muondia-docx-limit-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/enorme.docx');
    final words = List.filled(
      EstudioMaterialPolicy.maxDocxWords + 1,
      'palabra',
    ).join(' ');

    final archive = Archive()
      ..add(
        ArchiveFile.bytes(
          'word/document.xml',
          Uint8List.fromList(
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>$words</w:t></w:r></w:p></w:body></w:document>'
                .codeUnits,
          ),
        ),
      );
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive));

    await expectLater(
      const LocalEstudioDocumentExtractor().extract(
        EstudioPickedFile(
          name: 'enorme.docx',
          path: file.path,
          sizeBytes: file.lengthSync(),
          extension: 'docx',
        ),
      ),
      throwsA(isA<EstudioDocumentLimitException>()),
    );
  });

  test('StudyDocument serializa el texto estructurado sin perder fuente', () {
    final original = StudyDocument(
      id: 'doc',
      sourceName: 'tema.pdf',
      sourceExtension: 'pdf',
      createdAt: DateTime.utc(2026, 10, 7),
      sections: [
        StudySection(
          id: 's1',
          title: 'Tema 1',
          blocks: const [
            StudyContentBlock(
              id: 'b1',
              text: 'Texto literal del documento.',
              sourceLocator: 'página 2',
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
          text: 'Texto literal del documento.',
        ),
      ],
    );

    final restored = StudyDocument.fromJson(original.toJson());

    expect(restored.sourceName, 'tema.pdf');
    expect(restored.sections.single.blocks.single.text, 'Texto literal del documento.');
    expect(restored.sections.single.blocks.single.sourceLocator, 'página 2');
    expect(restored.quizUnits.single.sourceText, 'Texto literal del documento.');
  });
}
