final class StudyContentBlock {
  const StudyContentBlock({
    required this.id,
    required this.text,
    required this.sourceLocator,
  });

  final String id;
  final String text;
  final String sourceLocator;

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'sourceLocator': sourceLocator,
  };

  factory StudyContentBlock.fromJson(Map<String, dynamic> json) =>
      StudyContentBlock(
        id: json['id'] as String,
        text: json['text'] as String,
        sourceLocator: json['sourceLocator'] as String,
      );
}

final class StudySubsection {
  StudySubsection({
    required this.id,
    required this.title,
    required List<StudyContentBlock> blocks,
  }) : blocks = List.unmodifiable(blocks);

  final String id;
  final String title;
  final List<StudyContentBlock> blocks;

  String get text => blocks.map((block) => block.text).join('\n\n');

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'blocks': [for (final block in blocks) block.toJson()],
  };

  factory StudySubsection.fromJson(Map<String, dynamic> json) =>
      StudySubsection(
        id: json['id'] as String,
        title: json['title'] as String,
        blocks: [
          for (final item in json['blocks'] as List)
            StudyContentBlock.fromJson(item as Map<String, dynamic>),
        ],
      );
}

final class StudySection {
  StudySection({
    required this.id,
    required this.title,
    required List<StudyContentBlock> blocks,
    required List<StudySubsection> subsections,
  }) : blocks = List.unmodifiable(blocks),
       subsections = List.unmodifiable(subsections);

  final String id;
  final String title;
  final List<StudyContentBlock> blocks;
  final List<StudySubsection> subsections;

  String get text => [
    for (final block in blocks) block.text,
    for (final subsection in subsections) subsection.text,
  ].where((part) => part.trim().isNotEmpty).join('\n\n');

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'blocks': [for (final block in blocks) block.toJson()],
    'subsections': [
      for (final subsection in subsections) subsection.toJson(),
    ],
  };

  factory StudySection.fromJson(Map<String, dynamic> json) => StudySection(
    id: json['id'] as String,
    title: json['title'] as String,
    blocks: [
      for (final item in json['blocks'] as List)
        StudyContentBlock.fromJson(item as Map<String, dynamic>),
    ],
    subsections: [
      for (final item in json['subsections'] as List)
        StudySubsection.fromJson(item as Map<String, dynamic>),
    ],
  );
}

/// Unidad técnica de ejecución. Nunca forma parte de la jerarquía visible.
final class StudyChunk {
  const StudyChunk({
    required this.id,
    required this.sectionId,
    required this.subsectionId,
    required this.blockIds,
    required this.text,
  });

  final String id;
  final String sectionId;
  final String? subsectionId;
  final List<String> blockIds;
  final String text;

  Map<String, Object?> toJson() => {
    'id': id,
    'sectionId': sectionId,
    'subsectionId': subsectionId,
    'blockIds': blockIds,
    'text': text,
  };

  factory StudyChunk.fromJson(Map<String, dynamic> json) => StudyChunk(
    id: json['id'] as String,
    sectionId: json['sectionId'] as String,
    subsectionId: json['subsectionId'] as String?,
    blockIds: [for (final value in json['blockIds'] as List) value as String],
    text: json['text'] as String,
  );
}

final class StudyQuizUnit {
  const StudyQuizUnit({
    required this.id,
    required this.label,
    required this.sourceText,
  });

  final String id;
  final String label;
  final String sourceText;
}

/// Representación persistible y fiel del contenido extraído.
/// No resume el archivo: conserva el texto que QuizAI usará como fuente.
final class StudyDocument {
  StudyDocument({
    required this.id,
    required this.sourceName,
    required this.sourceExtension,
    required this.createdAt,
    required List<StudySection> sections,
    required List<StudyChunk> chunks,
  }) : sections = List.unmodifiable(sections),
       chunks = List.unmodifiable(chunks);

  final String id;
  final String sourceName;
  final String sourceExtension;
  final DateTime createdAt;
  final List<StudySection> sections;
  final List<StudyChunk> chunks;

  List<StudyQuizUnit> get quizUnits {
    final units = <StudyQuizUnit>[];
    for (final section in sections) {
      final sectionText = section.text.trim();
      if (sectionText.isNotEmpty) {
        units.add(
          StudyQuizUnit(
            id: section.id,
            label: section.title,
            sourceText: sectionText,
          ),
        );
      }
      for (final subsection in section.subsections) {
        final subsectionText = subsection.text.trim();
        if (subsectionText.isNotEmpty) {
          units.add(
            StudyQuizUnit(
              id: subsection.id,
              label: '${section.title} › ${subsection.title}',
              sourceText: subsectionText,
            ),
          );
        }
      }
    }
    return List.unmodifiable(units);
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'id': id,
    'sourceName': sourceName,
    'sourceExtension': sourceExtension,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'sections': [for (final section in sections) section.toJson()],
    'chunks': [for (final chunk in chunks) chunk.toJson()],
  };

  factory StudyDocument.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Versión de StudyDocument no compatible.');
    }
    return StudyDocument(
      id: json['id'] as String,
      sourceName: json['sourceName'] as String,
      sourceExtension: json['sourceExtension'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sections: [
        for (final item in json['sections'] as List)
          StudySection.fromJson(item as Map<String, dynamic>),
      ],
      chunks: [
        for (final item in json['chunks'] as List)
          StudyChunk.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}
