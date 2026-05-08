import 'dart:async';

import 'package:apptest_messaging/core/database/app_database.dart';
import 'package:apptest_messaging/features/chat/data/ws_client.dart';
import 'package:uuid/uuid.dart';

class OutboxService {
  OutboxService({required this.db, required this.ws});

  final AppDatabase db;
  final WsClient ws;

  StreamSubscription<bool>? _connSub;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    // If the app was closed mid-send, treat those as queued on next boot.
    // ignore: unawaited_futures
    db.resetOutboxStuckSendingToQueued();
    _connSub = ws.connection.listen((connected) {
      if (connected) {
        // ignore: unawaited_futures
        flush();
      }
    });
  }

  void dispose() {
    _connSub?.cancel();
    _connSub = null;
  }

  Future<void> sendOptimistic({
    required String conversationId,
    required String body,
    int? replyToSeq,
  }) async {
    start();
    final clientId = const Uuid().v4();
    final now = DateTime.now().toUtc();

    await db.upsertOutbox(
      clientId: clientId,
      conversationId: conversationId,
      body: body,
      createdAt: now,
      replyToSeq: replyToSeq,
      status: ws.isConnected ? 'sending' : 'queued',
      attempts: 0,
    );

    if (!ws.isConnected) return;
    await _trySend(clientId: clientId, conversationId: conversationId, body: body, replyToSeq: replyToSeq);
  }

  Future<void> retry(String clientId) async {
    start();
    final row = await (db.select(db.outboxMessages)..where((o) => o.clientId.equals(clientId))).getSingleOrNull();
    if (row == null) return;
    await db.updateOutboxStatus(clientId: clientId, status: ws.isConnected ? 'sending' : 'queued', lastError: null);
    if (!ws.isConnected) return;
    await _trySend(
      clientId: clientId,
      conversationId: row.conversationId,
      body: row.body,
      replyToSeq: row.replyToSeq,
    );
  }

  Future<void> flush() async {
    start();
    if (!ws.isConnected) return;
    final rows = await db.listOutboxSendable(limit: 100);
    for (final o in rows) {
      await _trySend(
        clientId: o.clientId,
        conversationId: o.conversationId,
        body: o.body,
        replyToSeq: o.replyToSeq,
      );
    }
  }

  Future<void> markAcked(String clientId) async {
    await db.deleteOutbox(clientId);
  }

  Future<void> _trySend({
    required String clientId,
    required String conversationId,
    required String body,
    required int? replyToSeq,
  }) async {
    if (!ws.isConnected) {
      await db.updateOutboxStatus(clientId: clientId, status: 'queued');
      return;
    }
    try {
      final existing = await (db.select(db.outboxMessages)..where((o) => o.clientId.equals(clientId))).getSingleOrNull();
      final nextAttempts = (existing?.attempts ?? 0) + 1;
      await db.updateOutboxStatus(clientId: clientId, status: 'sending', attempts: nextAttempts, lastError: null);
      ws.sendMessage(
        id: clientId,
        conversationId: conversationId,
        body: body,
        replyToSeq: replyToSeq,
      );
    } catch (e) {
      await db.updateOutboxStatus(clientId: clientId, status: 'failed', lastError: e.toString());
    }
  }
}

