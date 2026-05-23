import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsStatus { disconnected, connecting, connected }

class WsClient extends ChangeNotifier {
  WebSocketChannel? _channel;
  WsStatus _status = WsStatus.disconnected;
  String? _pairCode;
  String _serverUrl = '';
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectDelay = 1;
  bool _shouldReconnect = false;

  WsStatus get status => _status;
  String? get pairCode => _pairCode;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connectAndRegister(String serverUrl, String pairCode) async {
    _serverUrl = serverUrl;
    _pairCode = pairCode;
    _shouldReconnect = true;
    await _doConnectAndRegister();
  }

  Future<void> _doConnectAndRegister() async {
    _status = WsStatus.connecting;
    notifyListeners();

    try {
      final uri = Uri.parse(_serverUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _channel!.stream.listen(
        _onMessage,
        onError: (e) => _onDisconnect(),
        onDone: _onDisconnect,
      );

      _send({
        'type': 'register',
        'pair_code': _pairCode,
        'client_type': 'phone',
      });
    } catch (e) {
      debugPrint('WsClient connect error: $e');
      _status = WsStatus.disconnected;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void sendCommand(String content) {
    _send({'type': 'command', 'payload': content});
  }

  void sendAck(int seq) {
    _send({'type': 'ack', 'seq': seq});
  }

  void _send(Map<String, dynamic> msg) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(msg));
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'paired':
          _status = WsStatus.connected;
          _reconnectDelay = 1;
          _startHeartbeat();
          notifyListeners();
          break;
        case 'heartbeat':
          break;
        case 'error':
          debugPrint('WsClient server error: ${msg['payload']}');
          break;
        case 'disconnect':
          debugPrint('WsClient peer disconnected: ${msg['payload']}');
          break;
        default:
          _messageController.add(msg);
      }
    } catch (e) {
      debugPrint('WsClient parse error: $e');
    }
  }

  void _onDisconnect() {
    _status = WsStatus.disconnected;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    notifyListeners();
    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _send({'type': 'heartbeat'});
    });
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _reconnectDelay = (_reconnectDelay * 2).clamp(1, 30);
      _doConnectAndRegister();
    });
  }

  void disconnect() {
    _shouldReconnect = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _status = WsStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
