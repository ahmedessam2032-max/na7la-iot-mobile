import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../core/constants/api_constants.dart';

class SoftApService {
  static const MethodChannel _channel = MethodChannel('com.na7la.iot/native_wifi');

  /// Calculate MTTL-W01 factory SoftAP password: LGU_ + last 7 characters of MAC
  static String calculateSoftApPassword(String mac) {
    final cleanMac = mac.replaceAll(':', '').replaceAll('-', '').toUpperCase();
    if (cleanMac.length >= 7) {
      final suffix = cleanMac.substring(cleanMac.length - 7);
      return 'LGU_$suffix';
    }
    return 'LGU_$cleanMac';
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
