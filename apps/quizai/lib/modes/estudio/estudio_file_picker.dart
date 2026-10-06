import 'package:file_picker/file_picker.dart';

const estudioAllowedExtensions = <String>[
  'pdf',
  'docx',
  'pptx',
  'jpg',
  'jpeg',
  'png',
];

final class EstudioPickedFile {
  const EstudioPickedFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.extension,
  });

  final String name;
  final String? path;
  final int sizeBytes;
  final String extension;
}

typedef EstudioFilePicker = Future<EstudioPickedFile?> Function();

Future<EstudioPickedFile?> pickEstudioFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: estudioAllowedExtensions,
    allowMultiple: false,
    withData: false,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final extension = _extensionOf(file);
  if (!estudioAllowedExtensions.contains(extension)) {
    throw const FormatException('Formato de archivo no compatible.');
  }

  return EstudioPickedFile(
    name: file.name,
    path: file.path,
    sizeBytes: file.size,
    extension: extension,
  );
}

String _extensionOf(PlatformFile file) {
  final reported = file.extension?.trim().toLowerCase();
  if (reported != null && reported.isNotEmpty) return reported;

  final dot = file.name.lastIndexOf('.');
  if (dot < 0 || dot == file.name.length - 1) return '';
  return file.name.substring(dot + 1).toLowerCase();
}
