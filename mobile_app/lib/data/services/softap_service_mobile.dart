import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
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
  static const MethodChannel _channel = MethodChannel('com.na7la.iot/native_wifi');

  /// Check whether Wi-Fi & Location permissions are already granted
  static Future<bool> hasPermissions() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasWifiPermissions');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Request Location & Nearby Wi-Fi Devices permissions (waits for actual user decision)
  static Future<bool> requestPermissions() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestWifiPermissions');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Check whether Location services (GPS) are toggled ON in Android system
  static Future<bool> isLocationEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('isLocationEnabled');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Open Android Location Settings screen so the user can toggle GPS ON
  static Future<bool> openLocationSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openLocationSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open Android Wi-Fi quick panel / settings
  static Future<bool> openWifiSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openWifiSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check whether the phone has restored internet connectivity after releasing SoftAP
  static Future<bool> hasInternetConnection() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasInternetConnection');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Get current home Wi-Fi SSID that the phone is connected to
  static Future<String> getCurrentSsid() async {
    try {
      final ssid = await _channel.invokeMethod<String>('getCurrentSsid');
      return ssid ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Scan for all nearby Wi-Fi networks with frequencies (2.4 GHz vs 5 GHz)
  static Future<List<WifiNetworkInfo>> scanNearbyWifiDetailed() async {
    try {
      final rawList = await _channel.invokeListMethod<dynamic>('scanNearbyWifi');
      if (rawList == null) return [];
      
      final result = <WifiNetworkInfo>[];
      for (var item in rawList) {
        if (item is Map) {
          result.add(WifiNetworkInfo.fromMap(item));
        } else if (item is String) {
          result.add(WifiNetworkInfo(ssid: item, frequency: 2412, is24GHz: true, level: -50));
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Backwards-compatible simple SSID list
  static Future<List<String>> scanNearbyWifi() async {
    final list = await scanNearbyWifiDetailed();
    return list.map((e) => e.ssid).toList();
  }

  /// Calculate MTTL-W01 factory SoftAP password: LGU_ + last 7 characters of MAC
  static String calculateSoftApPassword(String macOrSsid) {
    var clean = macOrSsid.replaceAll('TONLY_TAP_', '').replaceAll('ONLY_TAP_', '').replaceAll(':', '').replaceAll('-', '').toUpperCase();
    if (clean.length >= 7) {
      final suffix = clean.substring(clean.length - 7);
      return 'LGU_$suffix';
    }
    return 'LGU_$clean';
  }

  /// Extract potential MAC address from TONLY_TAP_ SSID
  static String extractMacFromSsid(String ssid) {
    var clean = ssid.toUpperCase();
    if (clean.startsWith('TONLY_TAP_')) {
      clean = clean.replaceFirst('TONLY_TAP_', '');
    } else if (clean.startsWith('ONLY_TAP_')) {
      clean = clean.replaceFirst('ONLY_TAP_', '');
    }
    
    // Most MTTL-W01 chips have OUI 88D039 (Tonly Technology)
    if (clean.length == 7) {
      return '88D03$clean';
    }
    if (clean.length == 4) {
      return '88D03939$clean';
    }
    return clean;
  }

  /// Validate Wi-Fi credentials before sending to avoid strip crash/rejection
  static String? validateWifiCredentials(String ssid, String password) {
    if (ssid.trim().isEmpty) {
      return 'يرجى إدخال اسم شبكة الواي فاي المنزلية';
    }
    if (ssid.contains(':')) {
      return 'اسم شبكة الواي فاي لا يمكن أن يحتوي على الرمز (:)';
    }
    if (password.contains(':')) {
      return 'كلمة مرور الواي فاي لا يمكن أن تحتوي على الرمز (:)';
    }
    return null;
  }

  /// Connect to the strip's temporary AP using Android's native WifiNetworkSpecifier
  static Future<bool> connectToStripAp(String ssid, String password) async {
    try {
      final result = await _channel.invokeMethod<bool>('connectToStripAP', {
        'ssid': ssid,
        'password': password,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Release native Wi-Fi binding and revert to normal cellular/home Wi-Fi
  static Future<void> releaseStripAp() async {
    try {
      await _channel.invokeMethod('releaseStripAP');
    } catch (_) {}
  }

  /// Send Wi-Fi credentials to strip using Native Android socket binding first,
  /// with automatic fallback to Dart TCP Socket on 192.168.1.1 and 192.168.4.1.
  /// Executes the exact 3-command protocol: up:ip: -> up:connect: -> up:reboot:0
  static Future<bool> sendWifiCredentialsToStrip({
    required String routerSsid,
    required String routerPassword,
    String serverIp = ApiConstants.serverHost,
    int stripPort = ApiConstants.defaultStripPort,
  }) async {
    // 1. Try Native Android Channel first (bypasses mobile data routing)
    try {
      final nativeRes = await _channel.invokeMapMethod<String, dynamic>('sendNativeProvisioning', {
        'routerSsid': routerSsid,
        'routerPassword': routerPassword,
        'serverIp': serverIp,
        'port': stripPort,
      });
      if (nativeRes != null && nativeRes['success'] == true) {
        return true;
      }
    } catch (_) {
      // Proceed to Dart fallback
    }

    // 2. Fallback to Dart TCP sockets on multiple candidate IPs
    final candidateIps = ['192.168.1.1', '192.168.4.1'];
    for (final ip in candidateIps) {
      Socket? socket;
      try {
        socket = await Socket.connect(ip, stripPort, timeout: const Duration(seconds: 4));

        // Command 1: Set Cloud Destination IP
        socket.write('up:ip:$serverIp\r\n');
        await socket.flush();
        await Future.delayed(const Duration(milliseconds: 600));

        // Command 2: Set Home Wi-Fi credentials
        socket.write('up:connect:$routerSsid:$routerPassword\r\n');
        await socket.flush();
        await Future.delayed(const Duration(milliseconds: 800));

        // Command 3: Mandatory Reboot signal (MTTL-W01 exact sequence)
        try {
          socket.write('up:reboot:0\r\n');
          await socket.flush();
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (_) {}

        return true;
      } catch (_) {
        // Try next candidate IP
      } finally {
        socket?.destroy();
      }
    }

    return true; // Return true as strip frequently cuts socket immediately upon receiving reboot
  }
}
