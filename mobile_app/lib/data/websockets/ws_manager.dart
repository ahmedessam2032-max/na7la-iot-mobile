import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/api_constants.dart';

class WebSocketManager {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  String? _currentMac;
  bool _isDisposed = false;
  Timer? _reconnectTimer;

  Stream<Map<String, dynamic>> connect(String mac) {
    if (_currentMac == mac && _channel != null && _controller != null) {
      return _controller!.stream;
    }

    _disconnect();
    _currentMac = mac;
    _isDisposed = false;
    _controller = StreamController<Map<String, dynamic>>.broadcast();

    _initConnection();
    return _controller!.stream;
  }

  void _initConnection() {
    if (_isDisposed || _currentMac == null) return;

    try {
      final uri = Uri.parse('${ApiConstants.wsBaseUrl}/$_currentMac');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data);
            if (parsed is Map<String, dynamic>) {
              _controller?.add(parsed);
            }
          } catch (_) {}
        },
        onError: (error) {
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _initConnection();
    });
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _controller?.close();
    _controller = null;
  }

  void dispose() {
    _isDisposed = true;
    _disconnect();
  }
}
