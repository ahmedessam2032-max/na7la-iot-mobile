import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

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

  static Future<Map<String, dynamic>> downloadAndOpenEnergyCsv(String mac) async {
    try {
      final token = await SecureStorageService.getToken();
      final headers = <String, String>{
        if (token != null) 'X-Na7la-Token': token,
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/strips/$mac/export-csv'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final fileName = 'na7la_energy_${mac}_${DateTime.now().millisecondsSinceEpoch}.csv';
        final path = await saveBytes(response.bodyBytes, fileName);
        return {
          'success': true,
          'path': path,
          'message': 'تم حفظ ملف التقرير بنجاح: ${path ?? fileName}',
        };
      }
      return {
        'success': false,
        'message': 'تعذر تحميل التقرير من السيرفر (${response.statusCode})',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطأ أثناء تصدير ملف الإكسل: $e',
      };
    }
  }
}
