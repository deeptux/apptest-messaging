import 'package:apptest_messaging/core/database/app_database.dart';
import 'package:apptest_messaging/features/chat/data/chat_api.dart';

class ChatRepository {
  ChatRepository({required this.api, required this.db});

  final ChatApi api;
  final AppDatabase db;

  Future<void> syncInbox({required String selfUserId}) async {
    final rows = await api.fetchInbox(limit: 50);
    for (final c in rows) {
      final other = (c['otherUser'] as Map?)?.cast<String, dynamic>() ?? const {};
      await db.upsertConversation(
        conversationId: c['conversationId'] as String,
        kind: c['kind'] as String,
        otherUserId: other['userId'] as String,
        otherEmail: other['email'] as String?,
        otherDisplayName: other['displayName'] as String?,
        otherPhotoUrl: other['photoUrl'] as String?,
        lastSeq: (c['lastSeq'] as num?)?.toInt() ?? 0,
        lastMessageAt: _parseDateTime(c['lastMessageAt']),
      );
      await db.upsertMember(
        conversationId: c['conversationId'] as String,
        userId: selfUserId,
        lastReadSeq: (c['lastReadSeq'] as num?)?.toInt() ?? 0,
      );
    }
  }

  Future<void> syncLatestMessages({
    required String conversationId,
    int limit = 50,
  }) async {
    final rows = await api.fetchMessages(conversationId: conversationId, limit: limit);
    for (final m in rows) {
      await db.upsertMessage(
        messageId: m['messageId'] as String,
        conversationId: m['conversationId'] as String,
        seq: (m['seq'] as num).toInt(),
        senderUserId: m['senderUserId'] as String,
        body: m['body'] as String,
        createdAt: _parseDateTime(m['createdAt']) ?? DateTime.now().toUtc(),
        deliveredAt: _parseDateTime(m['deliveredAt']),
        deletedAt: _parseDateTime(m['deletedAt']),
      );
    }
  }

  Future<void> syncOlderMessages({
    required String conversationId,
    required int beforeSeq,
    int limit = 50,
  }) async {
    final rows = await api.fetchMessages(
      conversationId: conversationId,
      limit: limit,
      beforeSeq: beforeSeq,
    );
    for (final m in rows) {
      await db.upsertMessage(
        messageId: m['messageId'] as String,
        conversationId: m['conversationId'] as String,
        seq: (m['seq'] as num).toInt(),
        senderUserId: m['senderUserId'] as String,
        body: m['body'] as String,
        createdAt: _parseDateTime(m['createdAt']) ?? DateTime.now().toUtc(),
        deliveredAt: _parseDateTime(m['deliveredAt']),
        deletedAt: _parseDateTime(m['deletedAt']),
      );
    }
  }

  Future<String> openOrCreateDirect({required String otherUserId}) async {
    final res = await api.openOrCreateDirect(otherUserId: otherUserId);
    return res['conversationId'] as String;
  }

  Future<void> markRead({
    required String conversationId,
    required int lastReadSeq,
  }) async {
    await api.markRead(conversationId: conversationId, lastReadSeq: lastReadSeq);
  }

  Future<void> hideConversation({
    required String selfUserId,
    required String conversationId,
  }) async {
    await api.hideConversation(conversationId: conversationId);
    await db.deleteConversationLocal(conversationId);
    // Keep local inbox consistent with server-side hide filtering.
    await syncInbox(selfUserId: selfUserId);
  }
}

DateTime? _parseDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is String) return DateTime.tryParse(raw)?.toUtc();
  return null;
}

