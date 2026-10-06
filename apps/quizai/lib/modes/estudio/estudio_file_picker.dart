import 'package:file_picker/file_picker.dart';

abstract final class EstudioMaterialPolicy {
  static const maxFileSizeBytes = 50 * 1024 * 1024;
  static const maxPdfPages = 300;
  static const maxPptxSlides = 300;
  static const maxMaterialsPerUser = 20;
  static const maxTotalStorageBytes = 500 * 1024 * 1024;
}

const estudioAllowedExtensions = <String>[
  'pdf',
  'docx',
  'pptx',
  'jpg',
  'jpeg',
  'png',
];

final class EstudioFileTooLargeException implements Exception {
  const EstudioFileTooLargeException();
}

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
  final pickedFile = EstudioPickedFile(
    name: file.name,
    path: file.path,
    sizeBytes: file.size,
    extension: _extensionOf(file),
  );
  validateEstudioPickedFile(pickedFile);
  return pickedFile;
}

void validateEstudioPickedFile(EstudioPickedFile file) {
  if (!estudioAllowedExtensions.contains(file.extension.toLowerCase())) {
    throw const FormatException('Formato de archivo no compatible.');
  }
  if (file.sizeBytes > EstudioMaterialPolicy.maxFileSizeBytes) {
    throw const EstudioFileTooLargeException();
  }
}

String _extensionOf(PlatformFile file) {
  final reported = file.extension?.trim().toLowerCase();
  if (reported != null && reported.isNotEmpty) return reported;

  final dot = file.name.lastIndexOf('.');
  if (dot < 0 || dot == file.name.length - 1) return '';
  return file.name.substring(dot + 1).toLowerCase();
}
