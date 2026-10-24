import 'dart:async';
import '../../core/constants/api_constants.dart';

class WifiNetworkInfo {
  final String ssid;
  final int frequency;
  final bool is24GHz;
  final int level;

  WifiNetworkInfo({
    required this.ssid,
    required this.frequency,
    required this.is24GHz,
    required this.level,
  });

  factory WifiNetworkInfo.fromMap(Map<dynamic, dynamic> map) {
    return WifiNetworkInfo(
      ssid: map['ssid']?.toString() ?? '',
      frequency: (map['frequency'] as num?)?.toInt() ?? 0,
      is24GHz: map['is24GHz'] == true,
      level: (map['level'] as num?)?.toInt() ?? 0,
    );
  }
}

class SoftApService {
  static Future<bool> hasPermissions() async => true;
  static Future<bool> requestPermissions() async => true;
  static Future<bool> isLocationEnabled() async => true;
  static Future<bool> openLocationSettings() async => false;
  static Future<bool> openWifiSettings() async => false;
  static Future<bool> hasInternetConnection() async => true;
  static Future<String> getCurrentSsid() async => 'Web_Simulated_WiFi';
  static Future<List<WifiNetworkInfo>> scanNearbyWifiDetailed() async => [];
  static Future<List<String>> scanNearbyWifi() async => [];

  static String calculateSoftApPassword(String macOrSsid) {
    var clean = macOrSsid.replaceAll('TONLY_TAP_', '').replaceAll('ONLY_TAP_', '').replaceAll(':', '').replaceAll('-', '').toUpperCase();
    if (clean.length >= 7) {
      final suffix = clean.substring(clean.length - 7);
      return 'LGU_$suffix';
    }
    return 'LGU_$clean';
  }

  static String extractMacFromSsid(String ssid) {
    var clean = ssid.toUpperCase();
    if (clean.startsWith('TONLY_TAP_')) {
      clean = clean.replaceFirst('TONLY_TAP_', '');
    } else if (clean.startsWith('ONLY_TAP_')) {
      clean = clean.replaceFirst('ONLY_TAP_', '');
    }
    if (clean.length == 7) return '88D03$clean';
    if (clean.length == 4) return '88D03939$clean';
    return clean;
  }

  static String? validateWifiCredentials(String ssid, String password) {
    if (ssid.trim().isEmpty) return 'يرجى إدخال اسم شبكة الواي فاي المنزلية';
    if (ssid.contains(':')) return 'اسم شبكة الواي فاي لا يمكن أن يحتوي على الرمز (:)';
    if (password.contains(':')) return 'كلمة مرور الواي فاي لا يمكن أن تحتوي على الرمز (:)';
    return null;
  }

  static Future<bool> connectToStripAp(String ssid, String password) async => true;
  static Future<void> releaseStripAp() async {}

  static Future<bool> sendWifiCredentialsToStrip({
    required String routerSsid,
    required String routerPassword,
    String serverIp = ApiConstants.serverHost,
    int stripPort = ApiConstants.defaultStripPort,
  }) async => true;
}
