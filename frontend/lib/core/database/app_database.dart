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

@DriftDatabase(tables: [LocalUsers])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openAppDatabaseConnection());

  @override
  int get schemaVersion => 1;

  /// Upserts the single local profile row for the signed-in user.
  Future<void> upsertMe({
    required String internalUserId,
    required String firebaseUid,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
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
  }

  Future<LocalUser?> getMe() => select(localUsers).getSingleOrNull();
}
