import 'dart:io';
import 'package:file_picker/file_picker.dart';

class UploadedDocument {
  final String fileName;
  final String content;

  UploadedDocument({required this.fileName, required this.content});
}

class DocumentService {
  Future<UploadedDocument?> pickAndParseDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'], // For simplicity, we parse .txt first.
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        return UploadedDocument(
          fileName: result.files.single.name,
          content: content,
        );
      }
    } catch (e) {
      print('Error parsing document: $e');
    }
    return null;
  }
}
