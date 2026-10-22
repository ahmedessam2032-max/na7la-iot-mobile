import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileDownloaderService {
  static Future<String?> saveBytes(List<int> bytes, String fileName) async {
    try {
      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
