import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

import 'estudio_file_picker.dart';
import 'study_document.dart';

final class EstudioDocumentExtractionException implements Exception {
  const EstudioDocumentExtractionException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class EstudioDocumentLimitException implements Exception {
  const EstudioDocumentLimitException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class EstudioDocumentExtractor {
  Future<StudyDocument> extract(EstudioPickedFile file);
}

final class LocalEstudioDocumentExtractor implements EstudioDocumentExtractor {
  const LocalEstudioDocumentExtractor();

  @override
  Future<StudyDocument> extract(EstudioPickedFile file) async {
    validateEstudioPickedFile(file);
    final path = file.path;
    if (path == null || path.trim().isEmpty) {
      throw const EstudioDocumentExtractionException(
        'El sistema no ha proporcionado acceso al archivo.',
      );
    }

    final extension = file.extension.toLowerCase();
    final sections = switch (extension) {
      'pdf' => await _extractPdf(path, file.name),
      'docx' => await _extractDocx(path, file.name),
      'pptx' => await _extractPptx(path, file.name),
      'jpg' || 'jpeg' || 'png' => await _extractImage(path, file.name),
      _ => throw const FormatException('Formato de archivo no compatible.'),
    };

    if (sections.isEmpty ||
        sections.every((section) => section.text.trim().isEmpty)) {
      throw const EstudioDocumentExtractionException(
        'No se ha podido extraer texto del archivo.',
      );
    }

    final now = DateTime.now().toUtc();
    return StudyDocument(
      id: '${now.microsecondsSinceEpoch}-${_safeId(file.name)}',
      sourceName: file.name,
      sourceExtension: extension,
      createdAt: now,
      sections: sections,
      chunks: buildStudyChunks(sections),
    );
  }
}

Future<List<StudySection>> _extractPdf(String path, String sourceName) async {
  await pdfrxFlutterInitialize();
  final document = await PdfDocument.openFile(path);
  try {
    if (document.pages.length > EstudioMaterialPolicy.maxPdfPages) {
      throw EstudioDocumentLimitException(
        'El PDF supera el límite de '
        '${EstudioMaterialPolicy.maxPdfPages} páginas.',
      );
    }

    final paragraphs = <_ExtractedParagraph>[];
    for (var i = 0; i < document.pages.length; i++) {
      final page = document.pages[i];
      final raw = await page.loadText();
      final text = raw?.fullText.trim() ?? '';
      if (text.isEmpty) continue;
      for (final line in const LineSplitter().convert(text)) {
        final normalized = _normalizeText(line);
        if (normalized.isEmpty) continue;
        paragraphs.add(
          _ExtractedParagraph(
            text: normalized,
            locator: 'página ${i + 1}',
            headingLevel: _plainHeadingLevel(normalized),
          ),
        );
      }
    }

    return _sectionsFromParagraphs(
      paragraphs,
      fallbackTitle: _nameWithoutExtension(sourceName),
    );
  } finally {
    document.dispose();
  }
}

Future<List<StudySection>> _extractDocx(String path, String sourceName) async {
  final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
  final documentFile = archive.findFile('word/document.xml');
  if (documentFile == null || !documentFile.isFile) {
    throw const EstudioDocumentExtractionException(
      'El DOCX no contiene un documento legible.',
    );
  }
  _guardInflatedXml(documentFile, 'DOCX');

  final styles = _docxHeadingStyles(archive.findFile('word/styles.xml'));
  final xml = XmlDocument.parse(utf8.decode(documentFile.readBytes()!));
  final paragraphs = <_ExtractedParagraph>[];
  var wordCount = 0;

  for (final paragraph in _elementsByLocalName(xml, 'p')) {
    final text = _elementsByLocalName(paragraph, 't')
        .map((element) => element.innerText)
        .join();
    final normalized = _normalizeText(text);
    if (normalized.isEmpty) continue;

    wordCount += _countWords(normalized);
    if (wordCount > EstudioMaterialPolicy.maxDocxWords) {
      throw EstudioDocumentLimitException(
        'El DOCX supera el límite de '
        '${EstudioMaterialPolicy.maxDocxWords} palabras.',
      );
    }

    final styleId = _paragraphStyleId(paragraph);
    paragraphs.add(
      _ExtractedParagraph(
        text: normalized,
        locator: 'DOCX',
        headingLevel:
            (styleId == null ? null : styles[styleId]) ??
            _plainHeadingLevel(normalized),
      ),
    );
  }

  return _sectionsFromParagraphs(
    paragraphs,
    fallbackTitle: _nameWithoutExtension(sourceName),
  );
}

Future<List<StudySection>> _extractPptx(String path, String sourceName) async {
  final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
  final slideFiles = archive
      .where(
        (entry) =>
            entry.isFile &&
            RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(entry.name),
      )
      .toList()
    ..sort((a, b) => _slideNumber(a.name).compareTo(_slideNumber(b.name)));

  if (slideFiles.length > EstudioMaterialPolicy.maxPptxSlides) {
    throw EstudioDocumentLimitException(
      'El PPTX supera el límite de '
      '${EstudioMaterialPolicy.maxPptxSlides} diapositivas.',
    );
  }

  final sections = <StudySection>[];
  for (var i = 0; i < slideFiles.length; i++) {
    final slideFile = slideFiles[i];
    _guardInflatedXml(slideFile, 'PPTX');
    final xml = XmlDocument.parse(utf8.decode(slideFile.readBytes()!));
    final texts = _elementsByLocalName(xml, 't')
        .map((element) => _normalizeText(element.innerText))
        .where((text) => text.isNotEmpty)
        .toList();
    if (texts.isEmpty) continue;

    final title = texts.first.length <= 140
        ? texts.first
        : 'Diapositiva ${i + 1}';
    final body = texts.length > 1 ? texts.sublist(1) : texts;
    final blocks = <StudyContentBlock>[
      for (var j = 0; j < body.length; j++)
        StudyContentBlock(
          id: 's${i + 1}-b${j + 1}',
          text: body[j],
          sourceLocator: 'diapositiva ${i + 1}',
        ),
    ];

    sections.add(
      StudySection(
        id: 's${i + 1}',
        title: title,
        blocks: blocks,
        subsections: const [],
      ),
    );
  }

  if (sections.isEmpty) {
    throw EstudioDocumentExtractionException(
      'No se ha encontrado texto en ${_nameWithoutExtension(sourceName)}.',
    );
  }
  return List.unmodifiable(sections);
}

Future<List<StudySection>> _extractImage(String path, String sourceName) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final recognized = await recognizer.processImage(
      InputImage.fromFilePath(path),
    );
    final blocks = <StudyContentBlock>[
      for (var i = 0; i < recognized.blocks.length; i++)
        if (_normalizeText(recognized.blocks[i].text).isNotEmpty)
          StudyContentBlock(
            id: 's1-b${i + 1}',
            text: _normalizeText(recognized.blocks[i].text),
            sourceLocator: 'imagen',
          ),
    ];
    return [
      StudySection(
        id: 's1',
        title: _nameWithoutExtension(sourceName),
        blocks: blocks,
        subsections: const [],
      ),
    ];
  } finally {
    recognizer.close();
  }
}

List<StudySection> _sectionsFromParagraphs(
  List<_ExtractedParagraph> paragraphs, {
  required String fallbackTitle,
}) {
  if (paragraphs.isEmpty) return const [];

  final mutable = <_MutableSection>[];
  _MutableSection? section;
  _MutableSubsection? subsection;
  var blockNumber = 0;

  void ensureSection() {
    section ??= _MutableSection(
      id: 's${mutable.length + 1}',
      title: fallbackTitle,
    );
    if (!mutable.contains(section)) mutable.add(section!);
  }

  for (final paragraph in paragraphs) {
    if (paragraph.headingLevel == 1) {
      section = _MutableSection(
        id: 's${mutable.length + 1}',
        title: paragraph.text,
      );
      mutable.add(section!);
      subsection = null;
      continue;
    }
    if (paragraph.headingLevel != null && paragraph.headingLevel! >= 2) {
      ensureSection();
      subsection = _MutableSubsection(
        id: '${section!.id}-ss${section!.subsections.length + 1}',
        title: paragraph.text,
      );
      section!.subsections.add(subsection!);
      continue;
    }

    ensureSection();
    blockNumber++;
    final block = StudyContentBlock(
      id: 'b$blockNumber',
      text: paragraph.text,
      sourceLocator: paragraph.locator,
    );
    if (subsection != null) {
      subsection!.blocks.add(block);
    } else {
      section!.blocks.add(block);
    }
  }

  return List.unmodifiable([
    for (final item in mutable)
      if (item.blocks.isNotEmpty ||
          item.subsections.any((subsection) => subsection.blocks.isNotEmpty))
        StudySection(
          id: item.id,
          title: item.title,
          blocks: item.blocks,
          subsections: [
            for (final subsection in item.subsections)
              if (subsection.blocks.isNotEmpty)
                StudySubsection(
                  id: subsection.id,
                  title: subsection.title,
                  blocks: subsection.blocks,
                ),
          ],
        ),
  ]);
}

List<StudyChunk> buildStudyChunks(
  List<StudySection> sections, {
  int maxCharacters = 3500,
}) {
  if (maxCharacters < 500) {
    throw ArgumentError.value(maxCharacters, 'maxCharacters');
  }
  final chunks = <StudyChunk>[];
  for (final section in sections) {
    chunks.addAll(
      _chunksForBlocks(
        sectionId: section.id,
        subsectionId: null,
        blocks: section.blocks,
        firstIndex: chunks.length + 1,
        maxCharacters: maxCharacters,
      ),
    );
    for (final subsection in section.subsections) {
      chunks.addAll(
        _chunksForBlocks(
          sectionId: section.id,
          subsectionId: subsection.id,
          blocks: subsection.blocks,
          firstIndex: chunks.length + 1,
          maxCharacters: maxCharacters,
        ),
      );
    }
  }
  return List.unmodifiable(chunks);
}

List<StudyChunk> _chunksForBlocks({
  required String sectionId,
  required String? subsectionId,
  required List<StudyContentBlock> blocks,
  required int firstIndex,
  required int maxCharacters,
}) {
  final chunks = <StudyChunk>[];
  final buffer = StringBuffer();
  final ids = <String>[];

  void flush() {
    final text = buffer.toString().trim();
    if (text.isEmpty) return;
    chunks.add(
      StudyChunk(
        id: 'c${firstIndex + chunks.length}',
        sectionId: sectionId,
        subsectionId: subsectionId,
        blockIds: List.unmodifiable([...ids]),
        text: text,
      ),
    );
    buffer.clear();
    ids.clear();
  }

  for (final block in blocks) {
    for (final piece in _splitText(block.text, maxCharacters)) {
      final separator = buffer.isEmpty ? 0 : 2;
      if (buffer.length + separator + piece.length > maxCharacters) flush();
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(piece);
      if (!ids.contains(block.id)) ids.add(block.id);
    }
  }
  flush();
  return chunks;
}

Iterable<String> _splitText(String text, int maxCharacters) sync* {
  var remaining = text.trim();
  while (remaining.length > maxCharacters) {
    var cut = remaining.lastIndexOf(' ', maxCharacters);
    if (cut < maxCharacters ~/ 2) cut = maxCharacters;
    yield remaining.substring(0, cut).trim();
    remaining = remaining.substring(cut).trimLeft();
  }
  if (remaining.isNotEmpty) yield remaining;
}

Map<String, int> _docxHeadingStyles(ArchiveFile? stylesFile) {
  final levels = <String, int>{};
  if (stylesFile == null || !stylesFile.isFile) return levels;
  _guardInflatedXml(stylesFile, 'DOCX');

  final xml = XmlDocument.parse(utf8.decode(stylesFile.readBytes()!));
  for (final style in _elementsByLocalName(xml, 'style')) {
    final styleId = _attributeByLocalName(style, 'styleId');
    if (styleId == null) continue;
    final nameElement = _elementsByLocalName(style, 'name').firstOrNull;
    final name = nameElement == null
        ? ''
        : (_attributeByLocalName(nameElement, 'val') ?? '');
    final candidate = '$styleId $name'.toLowerCase();
    final match = RegExp(
      r'(?:heading|t[ií]tulo|titre|überschrift|titolo)\s*([1-9])',
      caseSensitive: false,
    ).firstMatch(candidate);
    if (match != null) {
      levels[styleId] = int.parse(match.group(1)!);
      continue;
    }

    final outline = _elementsByLocalName(style, 'outlineLvl').firstOrNull;
    final value = outline == null ? null : _attributeByLocalName(outline, 'val');
    final parsed = value == null ? null : int.tryParse(value);
    if (parsed != null) levels[styleId] = parsed + 1;
  }
  return levels;
}

String? _paragraphStyleId(XmlElement paragraph) {
  final style = _elementsByLocalName(paragraph, 'pStyle').firstOrNull;
  return style == null ? null : _attributeByLocalName(style, 'val');
}

Iterable<XmlElement> _elementsByLocalName(XmlNode node, String localName) =>
    node.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == localName);

String? _attributeByLocalName(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) return attribute.value;
  }
  return null;
}

int? _plainHeadingLevel(String text) {
  if (text.length > 140) return null;
  if (RegExp(
    r'^(tema|unidad|cap[ií]tulo|bloque|lecci[oó]n)\s+[0-9IVXLC]+\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 1;
  }
  if (RegExp(r'^\d+\.\d+(?:\.\d+)*\s+\S').hasMatch(text)) return 2;
  if (RegExp(r'^\d+[.)]\s+[A-ZÁÉÍÓÚÜÑ]').hasMatch(text)) return 1;
  return null;
}

void _guardInflatedXml(ArchiveFile file, String format) {
  const maxXmlBytes = 32 * 1024 * 1024;
  if (file.size > maxXmlBytes) {
    throw EstudioDocumentExtractionException(
      'El $format contiene una estructura interna demasiado grande.',
    );
  }
}

int _slideNumber(String path) =>
    int.parse(RegExp(r'slide(\d+)\.xml$').firstMatch(path)!.group(1)!);

int _countWords(String text) =>
    RegExp(r'\S+').allMatches(text.trim()).length;

String _normalizeText(String text) =>
    text.replaceAll(RegExp(r'[ \t\r]+'), ' ').trim();

String _nameWithoutExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

String _safeId(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

final class _ExtractedParagraph {
  const _ExtractedParagraph({
    required this.text,
    required this.locator,
    required this.headingLevel,
  });

  final String text;
  final String locator;
  final int? headingLevel;
}

final class _MutableSection {
  _MutableSection({required this.id, required this.title});

  final String id;
  final String title;
  final List<StudyContentBlock> blocks = [];
  final List<_MutableSubsection> subsections = [];
}

final class _MutableSubsection {
  _MutableSubsection({required this.id, required this.title});

  final String id;
  final String title;
  final List<StudyContentBlock> blocks = [];
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
