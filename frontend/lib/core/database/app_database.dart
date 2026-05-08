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

  @override
  Set<Column> get primaryKey => {messageId};
}

@DriftDatabase(tables: [LocalUsers, Conversations, ConversationMembers, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openAppDatabaseConnection());

  @override
  int get schemaVersion => 3;

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
}
