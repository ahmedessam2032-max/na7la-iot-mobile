class FileDownloaderService {
  static Future<String?> saveBytes(List<int> bytes, String fileName) async {
    return 'Downloads/$fileName';
  }
}
