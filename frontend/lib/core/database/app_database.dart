import 'package:drift/drift.dart';

import 'opened_db.dart';

part 'app_database.g.dart';

/// Local mirror of GET /api/v1/me (single "me" row upserted after sync).
class LocalUsers extends Table {
  TextColumn get internalUserId => text()();
  TextColumn get firebaseUid => text()();
  TextColumn get email => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {internalUserId};
}

class Conversations extends Table {
  TextColumn get conversationId => text()();
  TextColumn get kind => text()();

  TextColumn get otherUserId => text()();
  TextColumn get otherEmail => text().nullable()();
  TextColumn get otherDisplayName => text().nullable()();
  TextColumn get otherPhotoUrl => text().nullable()();

  IntColumn get lastSeq => integer()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {conversationId};
}

class ConversationMembers extends Table {
  TextColumn get conversationId => text()();
  TextColumn get userId => text()();
  IntColumn get lastReadSeq => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {conversationId, userId};
}

class Messages extends Table {
  TextColumn get messageId => text()();
  TextColumn get conversationId => text()();
  IntColumn get seq => integer()();
  TextColumn get senderUserId => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get replyToSeq => integer().nullable()();

  @override
  Set<Column> get primaryKey => {messageId};
}

class OutboxMessages extends Table {
  TextColumn get clientId => text()(); // uuid generated client-side; equals WS envelope id
  TextColumn get conversationId => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get replyToSeq => integer().nullable()();

  /// queued | sending | failed
  TextColumn get status => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {clientId};
}

@DriftDatabase(tables: [LocalUsers, Conversations, ConversationMembers, Messages, OutboxMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openAppDatabaseConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(conversations);
            await m.createTable(conversationMembers);
            await m.createTable(messages);
          }
          // Schema 1→2 path above creates [messages] from the current Dart schema,
          // which already includes [deletedAt]. Only legacy DBs at version 2 need
          // the ALTER; running addColumn after createTable(from<2) causes
          // "duplicate column name: deleted_at" (seen on persistent browser storage).
          if (from >= 2 && from < 3) {
            await m.addColumn(messages, messages.deletedAt);
          }
          if (from >= 3 && from < 4) {
            await m.addColumn(messages, messages.replyToSeq);
          }
          // Ensure outbox table exists regardless of upgrade starting point.
          // If upgrading from <2 directly to v5, the guard (from>=4) would skip it.
          if (from < 5) {
            await m.createTable(outboxMessages);
          }
        },
        beforeOpen: (details) async {
          // Defensive repair: some deployed browsers may have schemaVersion=5 but
          // missed creating the outbox table due to an older migration bug.
          // Ensure it's present to prevent "no such table: outbox_messages".
          if (details.versionNow >= 5) {
            await customStatement('''
CREATE TABLE IF NOT EXISTS outbox_messages (
  client_id TEXT NOT NULL PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  reply_to_seq INTEGER NULL,
  status TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT NULL,
  updated_at INTEGER NOT NULL
);
''');
            await customStatement('''
CREATE INDEX IF NOT EXISTS idx_outbox_messages_conversation_created_at
  ON outbox_messages (conversation_id, created_at DESC);
''');
          }
        },
      );

  /// Upserts the signed-in user's profile row and removes other cached profiles
  /// (PK is [internalUserId], so each account was adding a row; multiple rows
  /// broke [getMe] which used `getSingleOrNull` on the whole table).
  Future<void> upsertMe({
    required String internalUserId,
    required String firebaseUid,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    await transaction(() async {
      await into(localUsers).insertOnConflictUpdate(
        LocalUsersCompanion(
          internalUserId: Value(internalUserId),
          firebaseUid: Value(firebaseUid),
          email: Value(email),
          displayName: Value(displayName),
          photoUrl: Value(photoUrl),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await (delete(localUsers)
            ..where((u) => u.internalUserId.equals(internalUserId).not()))
          .go();
    });
  }

  /// Latest signed-in profile (by [updatedAt]). Never use `getSingleOrNull` on
  /// the full table — more than one account may have rows after PK-per-user upserts.
  Future<LocalUser?> getMe() async {
    final rows = await (select(localUsers)
          ..orderBy([
            (u) => OrderingTerm(
                  expression: u.updatedAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Conversation?> getConversationById(String conversationId) {
    return (select(conversations)..where((c) => c.conversationId.equals(conversationId)))
        .getSingleOrNull();
  }

  Future<void> upsertConversation({
    required String conversationId,
    required String kind,
    required String otherUserId,
    String? otherEmail,
    String? otherDisplayName,
    String? otherPhotoUrl,
    required int lastSeq,
    DateTime? lastMessageAt,
  }) async {
    await into(conversations).insertOnConflictUpdate(
      ConversationsCompanion(
        conversationId: Value(conversationId),
        kind: Value(kind),
        otherUserId: Value(otherUserId),
        otherEmail: Value(otherEmail),
        otherDisplayName: Value(otherDisplayName),
        otherPhotoUrl: Value(otherPhotoUrl),
        lastSeq: Value(lastSeq),
        lastMessageAt: Value(lastMessageAt),
      ),
    );
  }

  Future<void> upsertMember({
    required String conversationId,
    required String userId,
    required int lastReadSeq,
  }) async {
    await into(conversationMembers).insertOnConflictUpdate(
      ConversationMembersCompanion(
        conversationId: Value(conversationId),
        userId: Value(userId),
        lastReadSeq: Value(lastReadSeq),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> upsertMessage({
    required String messageId,
    required String conversationId,
    required int seq,
    required String senderUserId,
    required String body,
    required DateTime createdAt,
    DateTime? deliveredAt,
    DateTime? deletedAt,
    int? replyToSeq,
  }) async {
    await into(messages).insertOnConflictUpdate(
      MessagesCompanion(
        messageId: Value(messageId),
        conversationId: Value(conversationId),
        seq: Value(seq),
        senderUserId: Value(senderUserId),
        body: Value(body),
        createdAt: Value(createdAt),
        deliveredAt: Value(deliveredAt),
        deletedAt: Value(deletedAt),
        replyToSeq: Value(replyToSeq),
      ),
    );
  }

  Future<void> updateConversationLast({
    required String conversationId,
    required int lastSeq,
    DateTime? lastMessageAt,
  }) async {
    await (update(conversations)..where((c) => c.conversationId.equals(conversationId))).write(
      ConversationsCompanion(
        lastSeq: Value(lastSeq),
        lastMessageAt: Value(lastMessageAt),
      ),
    );
  }

  Future<void> updateMessageDeliveredAt({
    required String conversationId,
    required int seq,
    required DateTime deliveredAt,
  }) async {
    await (update(messages)
          ..where((m) => m.conversationId.equals(conversationId) & m.seq.equals(seq)))
        .write(MessagesCompanion(deliveredAt: Value(deliveredAt)));
  }

  Future<void> deleteMessageById(String messageId) async {
    await (delete(messages)..where((m) => m.messageId.equals(messageId))).go();
  }

  Future<void> markMessageDeleted({
    required String conversationId,
    required int seq,
    required DateTime deletedAt,
  }) async {
    await (update(messages)
          ..where((m) => m.conversationId.equals(conversationId) & m.seq.equals(seq)))
        .write(
      MessagesCompanion(
        body: const Value('Message deleted'),
        deletedAt: Value(deletedAt),
      ),
    );
  }

  Future<void> deleteConversationLocal(String conversationId) async {
    await transaction(() async {
      await (delete(messages)
            ..where((m) => m.conversationId.equals(conversationId)))
          .go();
      await (delete(conversationMembers)
            ..where((m) => m.conversationId.equals(conversationId)))
          .go();
      await (delete(conversations)
            ..where((c) => c.conversationId.equals(conversationId)))
          .go();
    });
  }

  /// Wipes cached inbox/messages when switching accounts (e.g. Google → anonymous).
  /// Prevents showing another user's threads and 403 "not a member" on API calls.
  Future<void> clearAllLocalChatData() async {
    await transaction(() async {
      await delete(messages).go();
      await delete(conversationMembers).go();
      await delete(conversations).go();
    });
  }

  Future<List<Conversation>> listInbox() {
    return (select(conversations)
          ..orderBy([
            (c) => OrderingTerm(
                  expression: c.lastMessageAt,
                  mode: OrderingMode.desc,
                  nulls: NullsOrder.last,
                ),
            (c) => OrderingTerm(expression: c.conversationId),
          ]))
        .get();
  }

  Future<List<Message>> listMessagesLatest({
    required String conversationId,
    int limit = 50,
  }) {
    return (select(messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm(expression: m.seq, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
  }

  Future<List<Message>> listMessagesBeforeSeq({
    required String conversationId,
    required int beforeSeq,
    int limit = 50,
  }) {
    return (select(messages)
          ..where((m) => m.conversationId.equals(conversationId) & m.seq.isSmallerThanValue(beforeSeq))
          ..orderBy([(m) => OrderingTerm(expression: m.seq, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
  }

  Future<int> getLastReadSeq({
    required String conversationId,
    required String userId,
  }) async {
    final row = await (select(conversationMembers)
          ..where((m) => m.conversationId.equals(conversationId) & m.userId.equals(userId)))
        .getSingleOrNull();
    return row?.lastReadSeq ?? 0;
  }

  Stream<List<OutboxMessage>> watchOutboxForConversation(String conversationId) {
    return (select(outboxMessages)
          ..where((o) => o.conversationId.equals(conversationId))
          ..orderBy([
            (o) => OrderingTerm(expression: o.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<void> upsertOutbox({
    required String clientId,
    required String conversationId,
    required String body,
    required DateTime createdAt,
    int? replyToSeq,
    required String status,
    int attempts = 0,
    String? lastError,
  }) async {
    await into(outboxMessages).insertOnConflictUpdate(
      OutboxMessagesCompanion(
        clientId: Value(clientId),
        conversationId: Value(conversationId),
        body: Value(body),
        createdAt: Value(createdAt),
        replyToSeq: Value(replyToSeq),
        status: Value(status),
        attempts: Value(attempts),
        lastError: Value(lastError),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> updateOutboxStatus({
    required String clientId,
    required String status,
    String? lastError,
    int? attempts,
  }) async {
    await (update(outboxMessages)..where((o) => o.clientId.equals(clientId))).write(
      OutboxMessagesCompanion(
        status: Value(status),
        lastError: Value(lastError),
        attempts: attempts == null ? const Value.absent() : Value(attempts),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> deleteOutbox(String clientId) async {
    await (delete(outboxMessages)..where((o) => o.clientId.equals(clientId))).go();
  }

  Future<List<OutboxMessage>> listOutboxSendable({int limit = 100}) {
    return (select(outboxMessages)
          ..where((o) =>
              o.status.equals('queued') |
              o.status.equals('failed') |
              o.status.equals('sending'))
          ..orderBy([
            (o) => OrderingTerm(expression: o.updatedAt, mode: OrderingMode.asc),
          ])
          ..limit(limit))
        .get();
  }

  Future<void> resetOutboxStuckSendingToQueued() async {
    await (update(outboxMessages)..where((o) => o.status.equals('sending'))).write(
      OutboxMessagesCompanion(
        status: const Value('queued'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
