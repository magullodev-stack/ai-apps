import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'study_document.dart';

abstract interface class EstudioDocumentStore {
  Future<StudyDocument?> load();
  Future<void> save(StudyDocument document);
  Future<void> clear();
}

/// Persiste solo la representación procesada actual, no el archivo original.
final class LocalEstudioDocumentStore implements EstudioDocumentStore {
  static const _directoryName = 'estudio';
  static const _fileName = 'current_study_document.json';

  Future<File> _file() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/$_directoryName');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/$_fileName');
  }

  @override
  Future<StudyDocument?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      return StudyDocument.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(StudyDocument document) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(document.toJson()), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
