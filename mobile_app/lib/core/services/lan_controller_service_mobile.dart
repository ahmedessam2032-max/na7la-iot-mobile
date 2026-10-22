import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../../data/models/strip_model.dart';
import '../../data/models/socket_model.dart';

enum ControllerMode { cloud, localLan }

class LanControllerService {
  static final LanControllerService _instance = LanControllerService._internal();
  factory LanControllerService() => _instance;
  LanControllerService._internal();

  ServerSocket? _server;
  Socket? _clientSocket;
  bool _isRunning = false;

  final _telemetryController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get telemetryStream => _telemetryController.stream;

  bool get isRunning => _isRunning;
  bool get hasConnectedStrip => _clientSocket != null;

  /// بدء تشغيل خادم TCP محلي على منفذ 10086 داخل هاتف المستخدم
  Future<bool> startLocalHub({int port = 10086}) async {
    if (_isRunning) return true;
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _isRunning = true;
      _server!.listen(_handleIncomingClient, onError: (e) {
        _stopLocalHub();
      });
      return true;
    } catch (e) {
      _isRunning = false;
      return false;
    }
  }

  void _handleIncomingClient(Socket socket) {
    _clientSocket = socket;
    socket.listen(
      (data) {
        final text = utf8.decode(data, allowMalformed: true);
        final lines = text.split(RegExp(r'[\r\n]+'));
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          _parseStripLine(line.trim());
        }
      },
      onDone: () {
        _clientSocket = null;
      },
      onError: (e) {
        _clientSocket = null;
      },
    );

    // فور اتصال المشترك بالهاتف محلياً، نطلب الحالة الكاملة
    sendCommand("up:getinfo:all");
    sendCommand("up:power_report:1:vol");
  }

  void _parseStripLine(String line) {
    if (line.startsWith("up:getinfo:")) {
      _telemetryController.add({"event": "lan_getinfo", "raw": line});
    } else if (line.startsWith("up:power_report:")) {
      final parts = line.split(":");
      if (parts.length >= 3) {
        final val = int.tryParse(parts[2]) ?? 0;
        if (val > 50000) {
          _telemetryController.add({"event": "lan_voltage", "voltage": val / 1000.0});
        }
      }
    } else if (line.startsWith("up:childlock:") || line.startsWith("up:cl:")) {
      _telemetryController.add({"event": "lan_childlock", "raw": line});
    }
  }

  /// إرسال أمر بروتوكول مباشر لمشترك الواي فاي محلياً
  bool sendCommand(String cmd) {
    if (_clientSocket == null) return false;
    try {
      _clientSocket!.write("$cmd\r\n");
      return true;
    } catch (_) {
      return false;
    }
  }

  /// تبديل مخرج محلياً بدون إنترنت
  bool switchOutlet(int channel, bool on) {
    return sendCommand("up:onoff:$channel:${on ? 'on' : 'off'}");
  }

  /// تفعيل أو تعطيل قفل الأطفال محلياً
  bool setChildLock(bool enabled) {
    return sendCommand("up:childlock:${enabled ? 31 : 0}");
  }

  void _stopLocalHub() {
    _clientSocket?.destroy();
    _clientSocket = null;
    _server?.close();
    _server = null;
    _isRunning = false;
  }

  void dispose() {
    _stopLocalHub();
    _telemetryController.close();
  }
}
