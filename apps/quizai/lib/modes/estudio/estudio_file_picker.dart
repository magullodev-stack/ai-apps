import 'package:file_picker/file_picker.dart';

abstract final class EstudioMaterialPolicy {
  static const maxPdfSizeMegabytes = 25;
  static const maxDocxSizeMegabytes = 10;
  static const maxPptxSizeMegabytes = 20;
  static const maxImageSizeMegabytes = 10;

  static const maxPdfPages = 300;
  static const maxDocxWords = 75000;
  static const maxPptxSlides = 100;

  static int maxSizeMegabytesForExtension(String extension) {
    return switch (extension.toLowerCase()) {
      'pdf' => maxPdfSizeMegabytes,
      'docx' => maxDocxSizeMegabytes,
      'pptx' => maxPptxSizeMegabytes,
      'jpg' || 'jpeg' || 'png' => maxImageSizeMegabytes,
      _ => throw ArgumentError.value(extension, 'extension'),
    };
  }

  static int maxSizeBytesForExtension(String extension) {
    return maxSizeMegabytesForExtension(extension) * 1024 * 1024;
  }
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
  const EstudioFileTooLargeException(this.maxSizeMegabytes);

  final int maxSizeMegabytes;
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
  final maxSizeBytes = EstudioMaterialPolicy.maxSizeBytesForExtension(
    file.extension,
  );
  if (file.sizeBytes > maxSizeBytes) {
    throw EstudioFileTooLargeException(
      EstudioMaterialPolicy.maxSizeMegabytesForExtension(file.extension),
    );
  }
}

String _extensionOf(PlatformFile file) {
  final reported = file.extension?.trim().toLowerCase();
  if (reported != null && reported.isNotEmpty) return reported;

  final dot = file.name.lastIndexOf('.');
  if (dot < 0 || dot == file.name.length - 1) return '';
  return file.name.substring(dot + 1).toLowerCase();
}
