import 'dart:async';
import 'dart:convert';

import 'package:apptest_messaging/core/config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsClient {
  WsClient();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> connect({required String idToken}) async {
    await close();

    final base = requireApiBaseUrl();
    final wsUrl = _toWsUrl('$base/ws');
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel = channel;

    _sub = channel.stream.listen((raw) {
      try {
        final m = jsonDecode(raw as String) as Map<String, dynamic>;
        _events.add(m);
      } catch (_) {}
    }, onDone: () {
      _pingTimer?.cancel();
    }, onError: (_) {
      _pingTimer?.cancel();
    });

    _send({
      'v': 1,
      't': 'auth',
      'data': {'idToken': idToken},
    });

    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _send({
        'v': 1,
        't': 'ping',
        'data': {'ts': DateTime.now().toUtc().toIso8601String()},
      });
    });
  }

  void _send(Map<String, dynamic> env) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode(env));
  }

  Future<void> close() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }
}

String _toWsUrl(String httpUrl) {
  if (httpUrl.startsWith('https://')) return httpUrl.replaceFirst('https://', 'wss://');
  if (httpUrl.startsWith('http://')) return httpUrl.replaceFirst('http://', 'ws://');
  return httpUrl;
}

