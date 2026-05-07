import 'dart:async';
import 'dart:convert';

import 'package:apptest_messaging/core/config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsClient {
  WsClient();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _idToken;
  bool _closedByUser = false;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> connect({required String idToken}) async {
    _closedByUser = false;
    _idToken = idToken;
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
      _scheduleReconnect();
    }, onError: (_) {
      _pingTimer?.cancel();
      _scheduleReconnect();
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

  void sendMessage({
    required String id,
    required String conversationId,
    required String body,
  }) {
    _send({
      'v': 1,
      't': 'msg.send',
      'id': id,
      'data': {'conversationId': conversationId, 'body': body},
    });
  }

  void sendDelivered({
    required String conversationId,
    required int seq,
  }) {
    _send({
      'v': 1,
      't': 'msg.delivered',
      'data': {'conversationId': conversationId, 'seq': seq},
    });
  }

  void sendReadMark({
    required String conversationId,
    required int lastReadSeq,
  }) {
    _send({
      'v': 1,
      't': 'read.mark',
      'data': {'conversationId': conversationId, 'lastReadSeq': lastReadSeq},
    });
  }

  void _send(Map<String, dynamic> env) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode(env));
  }

  Future<void> close() async {
    _closedByUser = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _scheduleReconnect() {
    if (_closedByUser) return;
    if (_reconnectTimer != null) return;
    final token = _idToken;
    if (token == null || token.isEmpty) return;
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      _reconnectTimer = null;
      if (_closedByUser) return;
      try {
        await connect(idToken: token);
      } catch (_) {}
    });
  }
}

String _toWsUrl(String httpUrl) {
  if (httpUrl.startsWith('https://')) return httpUrl.replaceFirst('https://', 'wss://');
  if (httpUrl.startsWith('http://')) return httpUrl.replaceFirst('http://', 'ws://');
  return httpUrl;
}

