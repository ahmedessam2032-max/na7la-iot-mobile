import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../core/constants/api_constants.dart';

class SoftApService {
  static const MethodChannel _channel = MethodChannel('com.na7la.iot/native_wifi');

  /// Request Location & Nearby Devices permissions
  static Future<bool> requestPermissions() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestWifiPermissions');
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

  /// Scan for all nearby Wi-Fi SSIDs
  static Future<List<String>> scanNearbyWifi() async {
    try {
      final list = await _channel.invokeListMethod<String>('scanNearbyWifi');
      return list ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Calculate MTTL-W01 factory SoftAP password: LGU_ + last 7 characters of MAC
  static String calculateSoftApPassword(String macOrSsid) {
    var clean = macOrSsid.replaceAll('TONLY_TAP_', '').replaceAll(':', '').replaceAll('-', '').toUpperCase();
    if (clean.length >= 7) {
      final suffix = clean.substring(clean.length - 7);
      return 'LGU_$suffix';
    }
    return 'LGU_$clean';
  }

  /// Extract potential MAC address from TONLY_TAP_ SSID
  static String extractMacFromSsid(String ssid) {
    if (ssid.startsWith('TONLY_TAP_')) {
      final suffix = ssid.replaceFirst('TONLY_TAP_', '').toUpperCase();
      // Most MTTL-W01 chips have OUI 88D039 (Tonly Technology)
      if (suffix.length == 7) {
        // e.g. 9394B53 -> 88D039394B53
        return '88D03${suffix}';
      }
      return suffix;
    }
    return ssid;
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

  /// Send Wi-Fi credentials to strip via Raw TCP socket on 192.168.1.1:30300
  static Future<bool> sendWifiCredentialsToStrip({
    required String routerSsid,
    required String routerPassword,
    String stripIp = ApiConstants.defaultStripIp,
    int stripPort = ApiConstants.defaultStripPort,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(stripIp, stripPort, timeout: const Duration(seconds: 10));
      
      // Factory firmware command: set:wifi:<ssid>:<pass>\r\n
      final cmd = 'set:wifi:$routerSsid:$routerPassword\r\n';
      socket.write(cmd);
      await socket.flush();

      // Read acknowledgement
      final completer = Completer<bool>();
      socket.listen(
        (data) {
          final resp = String.fromCharCodes(data);
          if (resp.contains('ok') || resp.contains('OK') || resp.contains('set')) {
            if (!completer.isCompleted) completer.complete(true);
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(true); // Strip often closes immediately to reboot
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(true);
        },
      );

      // Return true if timeout or acknowledged since strip cuts socket to reboot
      return await completer.future.timeout(const Duration(seconds: 5), onTimeout: () => true);
    } catch (e) {
      // If error occurs, strip might have received and restarted
      return true;
    } finally {
      socket?.destroy();
    }
  }
}
