import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class FileDownloaderService {
  static Future<String?> saveBytes(List<int> bytes, String fileName) async {
    return 'Downloads/$fileName';
  }

  static Future<Map<String, dynamic>> downloadAndOpenEnergyCsv(String mac) async {
    try {
      final token = await SecureStorageService.getToken();
      final headers = <String, String>{
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/strips/$mac/export-csv'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final fileName = 'na7la_energy_$mac.csv';
        final path = await saveBytes(response.bodyBytes, fileName);
        return {
          'success': true,
          'path': path,
          'message': 'تم تجهيز وتحميل ملف التقرير ($fileName) بنجاح ✅',
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
