import 'dart:async';

enum ControllerMode { cloud, localLan }

class LanControllerService {
  static final LanControllerService _instance = LanControllerService._internal();
  factory LanControllerService() => _instance;
  LanControllerService._internal();

  final _telemetryController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get telemetryStream => _telemetryController.stream;

  bool get isRunning => false;
  bool get hasConnectedStrip => false;

  Future<bool> startLocalHub({int port = 10086}) async => false;
  bool sendCommand(String cmd) => false;
  bool switchOutlet(int channel, bool on) => false;
  bool setChildLock(bool enabled) => false;
  void dispose() => _telemetryController.close();
}
