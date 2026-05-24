import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsStatus { disconnected, connecting, connected }

class WsClient extends ChangeNotifier {
  static const String defaultServerUrl = 'ws://124.221.115.70:8080/ws';
  static const _keyCode = 'pair_code';
  static const _keyTime = 'pair_time';
  static const int validityHours = 72;

  WebSocketChannel? _channel;
  WsStatus _status = WsStatus.disconnected;
  String? _pairCode;
  final String _serverUrl = defaultServerUrl;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectDelay = 1;
  bool _shouldReconnect = false;
  bool _backgroundDisconnect = false;

  WsStatus get status => _status;
  String? get pairCode => _pairCode;
  String get serverUrl => _serverUrl;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<String?> getSavedPairCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_keyCode);
    final savedAt = prefs.getInt(_keyTime);
    if (code == null || savedAt == null) return null;
    final hoursSince = (DateTime.now().millisecondsSinceEpoch - savedAt) / (1000 * 3600);
    if (hoursSince > validityHours) {
      await prefs.remove(_keyCode);
      await prefs.remove(_keyTime);
      return null;
    }
    return code;
  }

  Future<void> _savePairCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCode, code);
    await prefs.setInt(_keyTime, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> connectAndRegister(String pairCode) async {
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
          _savePairCode(_pairCode ?? '');
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
    if (_backgroundDisconnect) {
      _backgroundDisconnect = false;
      return; // 后台主动断开，不通知 UI、不重连
    }
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

  // 后台静默断开：停止重连，不触发 UI 弹窗
  void disconnectForBackground() {
    _backgroundDisconnect = true;
    _shouldReconnect = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _status = WsStatus.disconnected;
  }

  // 从后台恢复：静默重连，不改变 UI 状态
  Future<void> reconnectSilently() async {
    if (_status == WsStatus.connected || _status == WsStatus.connecting) return;
    final code = await getSavedPairCode();
    if (code == null) return;
    _backgroundDisconnect = false;
    _pairCode = code;
    _shouldReconnect = true;
    _reconnectDelay = 1;
    await _doConnectAndRegister();
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
