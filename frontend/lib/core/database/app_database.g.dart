// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalUsersTable extends LocalUsers
    with TableInfo<$LocalUsersTable, LocalUser> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalUsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _internalUserIdMeta =
      const VerificationMeta('internalUserId');
  @override
  late final GeneratedColumn<String> internalUserId = GeneratedColumn<String>(
      'internal_user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _firebaseUidMeta =
      const VerificationMeta('firebaseUid');
  @override
  late final GeneratedColumn<String> firebaseUid = GeneratedColumn<String>(
      'firebase_uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _photoUrlMeta =
      const VerificationMeta('photoUrl');
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
      'photo_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [internalUserId, firebaseUid, email, displayName, photoUrl, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_users';
  @override
  VerificationContext validateIntegrity(Insertable<LocalUser> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('internal_user_id')) {
      context.handle(
          _internalUserIdMeta,
          internalUserId.isAcceptableOrUnknown(
              data['internal_user_id']!, _internalUserIdMeta));
    } else if (isInserting) {
      context.missing(_internalUserIdMeta);
    }
    if (data.containsKey('firebase_uid')) {
      context.handle(
          _firebaseUidMeta,
          firebaseUid.isAcceptableOrUnknown(
              data['firebase_uid']!, _firebaseUidMeta));
    } else if (isInserting) {
      context.missing(_firebaseUidMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('photo_url')) {
      context.handle(_photoUrlMeta,
          photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {internalUserId};
  @override
  LocalUser map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalUser(
      internalUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}internal_user_id'])!,
      firebaseUid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}firebase_uid'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      photoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photo_url']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalUsersTable createAlias(String alias) {
    return $LocalUsersTable(attachedDatabase, alias);
  }
}

class LocalUser extends DataClass implements Insertable<LocalUser> {
  final String internalUserId;
  final String firebaseUid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final DateTime updatedAt;
  const LocalUser(
      {required this.internalUserId,
      required this.firebaseUid,
      this.email,
      this.displayName,
      this.photoUrl,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['internal_user_id'] = Variable<String>(internalUserId);
    map['firebase_uid'] = Variable<String>(firebaseUid);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalUsersCompanion toCompanion(bool nullToAbsent) {
    return LocalUsersCompanion(
      internalUserId: Value(internalUserId),
      firebaseUid: Value(firebaseUid),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalUser.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalUser(
      internalUserId: serializer.fromJson<String>(json['internalUserId']),
      firebaseUid: serializer.fromJson<String>(json['firebaseUid']),
      email: serializer.fromJson<String?>(json['email']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'internalUserId': serializer.toJson<String>(internalUserId),
      'firebaseUid': serializer.toJson<String>(firebaseUid),
      'email': serializer.toJson<String?>(email),
      'displayName': serializer.toJson<String?>(displayName),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalUser copyWith(
          {String? internalUserId,
          String? firebaseUid,
          Value<String?> email = const Value.absent(),
          Value<String?> displayName = const Value.absent(),
          Value<String?> photoUrl = const Value.absent(),
          DateTime? updatedAt}) =>
      LocalUser(
        internalUserId: internalUserId ?? this.internalUserId,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        email: email.present ? email.value : this.email,
        displayName: displayName.present ? displayName.value : this.displayName,
        photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalUser copyWithCompanion(LocalUsersCompanion data) {
    return LocalUser(
      internalUserId: data.internalUserId.present
          ? data.internalUserId.value
          : this.internalUserId,
      firebaseUid:
          data.firebaseUid.present ? data.firebaseUid.value : this.firebaseUid,
      email: data.email.present ? data.email.value : this.email,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalUser(')
          ..write('internalUserId: $internalUserId, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      internalUserId, firebaseUid, email, displayName, photoUrl, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalUser &&
          other.internalUserId == this.internalUserId &&
          other.firebaseUid == this.firebaseUid &&
          other.email == this.email &&
          other.displayName == this.displayName &&
          other.photoUrl == this.photoUrl &&
          other.updatedAt == this.updatedAt);
}

class LocalUsersCompanion extends UpdateCompanion<LocalUser> {
  final Value<String> internalUserId;
  final Value<String> firebaseUid;
  final Value<String?> email;
  final Value<String?> displayName;
  final Value<String?> photoUrl;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalUsersCompanion({
    this.internalUserId = const Value.absent(),
    this.firebaseUid = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalUsersCompanion.insert({
    required String internalUserId,
    required String firebaseUid,
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.photoUrl = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : internalUserId = Value(internalUserId),
        firebaseUid = Value(firebaseUid),
        updatedAt = Value(updatedAt);
  static Insertable<LocalUser> custom({
    Expression<String>? internalUserId,
    Expression<String>? firebaseUid,
    Expression<String>? email,
    Expression<String>? displayName,
    Expression<String>? photoUrl,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (internalUserId != null) 'internal_user_id': internalUserId,
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalUsersCompanion copyWith(
      {Value<String>? internalUserId,
      Value<String>? firebaseUid,
      Value<String?>? email,
      Value<String?>? displayName,
      Value<String?>? photoUrl,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LocalUsersCompanion(
      internalUserId: internalUserId ?? this.internalUserId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (internalUserId.present) {
      map['internal_user_id'] = Variable<String>(internalUserId.value);
    }
    if (firebaseUid.present) {
      map['firebase_uid'] = Variable<String>(firebaseUid.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalUsersCompanion(')
          ..write('internalUserId: $internalUserId, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _otherUserIdMeta =
      const VerificationMeta('otherUserId');
  @override
  late final GeneratedColumn<String> otherUserId = GeneratedColumn<String>(
      'other_user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _otherEmailMeta =
      const VerificationMeta('otherEmail');
  @override
  late final GeneratedColumn<String> otherEmail = GeneratedColumn<String>(
      'other_email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _otherDisplayNameMeta =
      const VerificationMeta('otherDisplayName');
  @override
  late final GeneratedColumn<String> otherDisplayName = GeneratedColumn<String>(
      'other_display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _otherPhotoUrlMeta =
      const VerificationMeta('otherPhotoUrl');
  @override
  late final GeneratedColumn<String> otherPhotoUrl = GeneratedColumn<String>(
      'other_photo_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastSeqMeta =
      const VerificationMeta('lastSeq');
  @override
  late final GeneratedColumn<int> lastSeq = GeneratedColumn<int>(
      'last_seq', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _lastMessageAtMeta =
      const VerificationMeta('lastMessageAt');
  @override
  late final GeneratedColumn<DateTime> lastMessageAt =
      GeneratedColumn<DateTime>('last_message_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        conversationId,
        kind,
        otherUserId,
        otherEmail,
        otherDisplayName,
        otherPhotoUrl,
        lastSeq,
        lastMessageAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(Insertable<Conversation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('other_user_id')) {
      context.handle(
          _otherUserIdMeta,
          otherUserId.isAcceptableOrUnknown(
              data['other_user_id']!, _otherUserIdMeta));
    } else if (isInserting) {
      context.missing(_otherUserIdMeta);
    }
    if (data.containsKey('other_email')) {
      context.handle(
          _otherEmailMeta,
          otherEmail.isAcceptableOrUnknown(
              data['other_email']!, _otherEmailMeta));
    }
    if (data.containsKey('other_display_name')) {
      context.handle(
          _otherDisplayNameMeta,
          otherDisplayName.isAcceptableOrUnknown(
              data['other_display_name']!, _otherDisplayNameMeta));
    }
    if (data.containsKey('other_photo_url')) {
      context.handle(
          _otherPhotoUrlMeta,
          otherPhotoUrl.isAcceptableOrUnknown(
              data['other_photo_url']!, _otherPhotoUrlMeta));
    }
    if (data.containsKey('last_seq')) {
      context.handle(_lastSeqMeta,
          lastSeq.isAcceptableOrUnknown(data['last_seq']!, _lastSeqMeta));
    } else if (isInserting) {
      context.missing(_lastSeqMeta);
    }
    if (data.containsKey('last_message_at')) {
      context.handle(
          _lastMessageAtMeta,
          lastMessageAt.isAcceptableOrUnknown(
              data['last_message_at']!, _lastMessageAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      otherUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}other_user_id'])!,
      otherEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}other_email']),
      otherDisplayName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}other_display_name']),
      otherPhotoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}other_photo_url']),
      lastSeq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_seq'])!,
      lastMessageAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_message_at']),
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final String conversationId;
  final String kind;
  final String otherUserId;
  final String? otherEmail;
  final String? otherDisplayName;
  final String? otherPhotoUrl;
  final int lastSeq;
  final DateTime? lastMessageAt;
  const Conversation(
      {required this.conversationId,
      required this.kind,
      required this.otherUserId,
      this.otherEmail,
      this.otherDisplayName,
      this.otherPhotoUrl,
      required this.lastSeq,
      this.lastMessageAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['kind'] = Variable<String>(kind);
    map['other_user_id'] = Variable<String>(otherUserId);
    if (!nullToAbsent || otherEmail != null) {
      map['other_email'] = Variable<String>(otherEmail);
    }
    if (!nullToAbsent || otherDisplayName != null) {
      map['other_display_name'] = Variable<String>(otherDisplayName);
    }
    if (!nullToAbsent || otherPhotoUrl != null) {
      map['other_photo_url'] = Variable<String>(otherPhotoUrl);
    }
    map['last_seq'] = Variable<int>(lastSeq);
    if (!nullToAbsent || lastMessageAt != null) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt);
    }
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      conversationId: Value(conversationId),
      kind: Value(kind),
      otherUserId: Value(otherUserId),
      otherEmail: otherEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(otherEmail),
      otherDisplayName: otherDisplayName == null && nullToAbsent
          ? const Value.absent()
          : Value(otherDisplayName),
      otherPhotoUrl: otherPhotoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(otherPhotoUrl),
      lastSeq: Value(lastSeq),
      lastMessageAt: lastMessageAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAt),
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      kind: serializer.fromJson<String>(json['kind']),
      otherUserId: serializer.fromJson<String>(json['otherUserId']),
      otherEmail: serializer.fromJson<String?>(json['otherEmail']),
      otherDisplayName: serializer.fromJson<String?>(json['otherDisplayName']),
      otherPhotoUrl: serializer.fromJson<String?>(json['otherPhotoUrl']),
      lastSeq: serializer.fromJson<int>(json['lastSeq']),
      lastMessageAt: serializer.fromJson<DateTime?>(json['lastMessageAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'kind': serializer.toJson<String>(kind),
      'otherUserId': serializer.toJson<String>(otherUserId),
      'otherEmail': serializer.toJson<String?>(otherEmail),
      'otherDisplayName': serializer.toJson<String?>(otherDisplayName),
      'otherPhotoUrl': serializer.toJson<String?>(otherPhotoUrl),
      'lastSeq': serializer.toJson<int>(lastSeq),
      'lastMessageAt': serializer.toJson<DateTime?>(lastMessageAt),
    };
  }

  Conversation copyWith(
          {String? conversationId,
          String? kind,
          String? otherUserId,
          Value<String?> otherEmail = const Value.absent(),
          Value<String?> otherDisplayName = const Value.absent(),
          Value<String?> otherPhotoUrl = const Value.absent(),
          int? lastSeq,
          Value<DateTime?> lastMessageAt = const Value.absent()}) =>
      Conversation(
        conversationId: conversationId ?? this.conversationId,
        kind: kind ?? this.kind,
        otherUserId: otherUserId ?? this.otherUserId,
        otherEmail: otherEmail.present ? otherEmail.value : this.otherEmail,
        otherDisplayName: otherDisplayName.present
            ? otherDisplayName.value
            : this.otherDisplayName,
        otherPhotoUrl:
            otherPhotoUrl.present ? otherPhotoUrl.value : this.otherPhotoUrl,
        lastSeq: lastSeq ?? this.lastSeq,
        lastMessageAt:
            lastMessageAt.present ? lastMessageAt.value : this.lastMessageAt,
      );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      kind: data.kind.present ? data.kind.value : this.kind,
      otherUserId:
          data.otherUserId.present ? data.otherUserId.value : this.otherUserId,
      otherEmail:
          data.otherEmail.present ? data.otherEmail.value : this.otherEmail,
      otherDisplayName: data.otherDisplayName.present
          ? data.otherDisplayName.value
          : this.otherDisplayName,
      otherPhotoUrl: data.otherPhotoUrl.present
          ? data.otherPhotoUrl.value
          : this.otherPhotoUrl,
      lastSeq: data.lastSeq.present ? data.lastSeq.value : this.lastSeq,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('conversationId: $conversationId, ')
          ..write('kind: $kind, ')
          ..write('otherUserId: $otherUserId, ')
          ..write('otherEmail: $otherEmail, ')
          ..write('otherDisplayName: $otherDisplayName, ')
          ..write('otherPhotoUrl: $otherPhotoUrl, ')
          ..write('lastSeq: $lastSeq, ')
          ..write('lastMessageAt: $lastMessageAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(conversationId, kind, otherUserId, otherEmail,
      otherDisplayName, otherPhotoUrl, lastSeq, lastMessageAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.conversationId == this.conversationId &&
          other.kind == this.kind &&
          other.otherUserId == this.otherUserId &&
          other.otherEmail == this.otherEmail &&
          other.otherDisplayName == this.otherDisplayName &&
          other.otherPhotoUrl == this.otherPhotoUrl &&
          other.lastSeq == this.lastSeq &&
          other.lastMessageAt == this.lastMessageAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<String> conversationId;
  final Value<String> kind;
  final Value<String> otherUserId;
  final Value<String?> otherEmail;
  final Value<String?> otherDisplayName;
  final Value<String?> otherPhotoUrl;
  final Value<int> lastSeq;
  final Value<DateTime?> lastMessageAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.conversationId = const Value.absent(),
    this.kind = const Value.absent(),
    this.otherUserId = const Value.absent(),
    this.otherEmail = const Value.absent(),
    this.otherDisplayName = const Value.absent(),
    this.otherPhotoUrl = const Value.absent(),
    this.lastSeq = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String conversationId,
    required String kind,
    required String otherUserId,
    this.otherEmail = const Value.absent(),
    this.otherDisplayName = const Value.absent(),
    this.otherPhotoUrl = const Value.absent(),
    required int lastSeq,
    this.lastMessageAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : conversationId = Value(conversationId),
        kind = Value(kind),
        otherUserId = Value(otherUserId),
        lastSeq = Value(lastSeq);
  static Insertable<Conversation> custom({
    Expression<String>? conversationId,
    Expression<String>? kind,
    Expression<String>? otherUserId,
    Expression<String>? otherEmail,
    Expression<String>? otherDisplayName,
    Expression<String>? otherPhotoUrl,
    Expression<int>? lastSeq,
    Expression<DateTime>? lastMessageAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (kind != null) 'kind': kind,
      if (otherUserId != null) 'other_user_id': otherUserId,
      if (otherEmail != null) 'other_email': otherEmail,
      if (otherDisplayName != null) 'other_display_name': otherDisplayName,
      if (otherPhotoUrl != null) 'other_photo_url': otherPhotoUrl,
      if (lastSeq != null) 'last_seq': lastSeq,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith(
      {Value<String>? conversationId,
      Value<String>? kind,
      Value<String>? otherUserId,
      Value<String?>? otherEmail,
      Value<String?>? otherDisplayName,
      Value<String?>? otherPhotoUrl,
      Value<int>? lastSeq,
      Value<DateTime?>? lastMessageAt,
      Value<int>? rowid}) {
    return ConversationsCompanion(
      conversationId: conversationId ?? this.conversationId,
      kind: kind ?? this.kind,
      otherUserId: otherUserId ?? this.otherUserId,
      otherEmail: otherEmail ?? this.otherEmail,
      otherDisplayName: otherDisplayName ?? this.otherDisplayName,
      otherPhotoUrl: otherPhotoUrl ?? this.otherPhotoUrl,
      lastSeq: lastSeq ?? this.lastSeq,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (otherUserId.present) {
      map['other_user_id'] = Variable<String>(otherUserId.value);
    }
    if (otherEmail.present) {
      map['other_email'] = Variable<String>(otherEmail.value);
    }
    if (otherDisplayName.present) {
      map['other_display_name'] = Variable<String>(otherDisplayName.value);
    }
    if (otherPhotoUrl.present) {
      map['other_photo_url'] = Variable<String>(otherPhotoUrl.value);
    }
    if (lastSeq.present) {
      map['last_seq'] = Variable<int>(lastSeq.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('kind: $kind, ')
          ..write('otherUserId: $otherUserId, ')
          ..write('otherEmail: $otherEmail, ')
          ..write('otherDisplayName: $otherDisplayName, ')
          ..write('otherPhotoUrl: $otherPhotoUrl, ')
          ..write('lastSeq: $lastSeq, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationMembersTable extends ConversationMembers
    with TableInfo<$ConversationMembersTable, ConversationMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastReadSeqMeta =
      const VerificationMeta('lastReadSeq');
  @override
  late final GeneratedColumn<int> lastReadSeq = GeneratedColumn<int>(
      'last_read_seq', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [conversationId, userId, lastReadSeq, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_members';
  @override
  VerificationContext validateIntegrity(Insertable<ConversationMember> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('last_read_seq')) {
      context.handle(
          _lastReadSeqMeta,
          lastReadSeq.isAcceptableOrUnknown(
              data['last_read_seq']!, _lastReadSeqMeta));
    } else if (isInserting) {
      context.missing(_lastReadSeqMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId, userId};
  @override
  ConversationMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationMember(
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      lastReadSeq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_read_seq'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ConversationMembersTable createAlias(String alias) {
    return $ConversationMembersTable(attachedDatabase, alias);
  }
}

class ConversationMember extends DataClass
    implements Insertable<ConversationMember> {
  final String conversationId;
  final String userId;
  final int lastReadSeq;
  final DateTime updatedAt;
  const ConversationMember(
      {required this.conversationId,
      required this.userId,
      required this.lastReadSeq,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['user_id'] = Variable<String>(userId);
    map['last_read_seq'] = Variable<int>(lastReadSeq);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationMembersCompanion toCompanion(bool nullToAbsent) {
    return ConversationMembersCompanion(
      conversationId: Value(conversationId),
      userId: Value(userId),
      lastReadSeq: Value(lastReadSeq),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConversationMember.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationMember(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      userId: serializer.fromJson<String>(json['userId']),
      lastReadSeq: serializer.fromJson<int>(json['lastReadSeq']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'userId': serializer.toJson<String>(userId),
      'lastReadSeq': serializer.toJson<int>(lastReadSeq),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConversationMember copyWith(
          {String? conversationId,
          String? userId,
          int? lastReadSeq,
          DateTime? updatedAt}) =>
      ConversationMember(
        conversationId: conversationId ?? this.conversationId,
        userId: userId ?? this.userId,
        lastReadSeq: lastReadSeq ?? this.lastReadSeq,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ConversationMember copyWithCompanion(ConversationMembersCompanion data) {
    return ConversationMember(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      userId: data.userId.present ? data.userId.value : this.userId,
      lastReadSeq:
          data.lastReadSeq.present ? data.lastReadSeq.value : this.lastReadSeq,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMember(')
          ..write('conversationId: $conversationId, ')
          ..write('userId: $userId, ')
          ..write('lastReadSeq: $lastReadSeq, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(conversationId, userId, lastReadSeq, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationMember &&
          other.conversationId == this.conversationId &&
          other.userId == this.userId &&
          other.lastReadSeq == this.lastReadSeq &&
          other.updatedAt == this.updatedAt);
}

class ConversationMembersCompanion extends UpdateCompanion<ConversationMember> {
  final Value<String> conversationId;
  final Value<String> userId;
  final Value<int> lastReadSeq;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationMembersCompanion({
    this.conversationId = const Value.absent(),
    this.userId = const Value.absent(),
    this.lastReadSeq = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationMembersCompanion.insert({
    required String conversationId,
    required String userId,
    required int lastReadSeq,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : conversationId = Value(conversationId),
        userId = Value(userId),
        lastReadSeq = Value(lastReadSeq),
        updatedAt = Value(updatedAt);
  static Insertable<ConversationMember> custom({
    Expression<String>? conversationId,
    Expression<String>? userId,
    Expression<int>? lastReadSeq,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (userId != null) 'user_id': userId,
      if (lastReadSeq != null) 'last_read_seq': lastReadSeq,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationMembersCompanion copyWith(
      {Value<String>? conversationId,
      Value<String>? userId,
      Value<int>? lastReadSeq,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ConversationMembersCompanion(
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      lastReadSeq: lastReadSeq ?? this.lastReadSeq,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (lastReadSeq.present) {
      map['last_read_seq'] = Variable<int>(lastReadSeq.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMembersCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('userId: $userId, ')
          ..write('lastReadSeq: $lastReadSeq, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
      'seq', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _senderUserIdMeta =
      const VerificationMeta('senderUserId');
  @override
  late final GeneratedColumn<String> senderUserId = GeneratedColumn<String>(
      'sender_user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deliveredAtMeta =
      const VerificationMeta('deliveredAt');
  @override
  late final GeneratedColumn<DateTime> deliveredAt = GeneratedColumn<DateTime>(
      'delivered_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        messageId,
        conversationId,
        seq,
        senderUserId,
        body,
        createdAt,
        deliveredAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<Message> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
          _seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('sender_user_id')) {
      context.handle(
          _senderUserIdMeta,
          senderUserId.isAcceptableOrUnknown(
              data['sender_user_id']!, _senderUserIdMeta));
    } else if (isInserting) {
      context.missing(_senderUserIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('delivered_at')) {
      context.handle(
          _deliveredAtMeta,
          deliveredAt.isAcceptableOrUnknown(
              data['delivered_at']!, _deliveredAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      seq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      senderUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_user_id'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      deliveredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}delivered_at']),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String messageId;
  final String conversationId;
  final int seq;
  final String senderUserId;
  final String body;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  const Message(
      {required this.messageId,
      required this.conversationId,
      required this.seq,
      required this.senderUserId,
      required this.body,
      required this.createdAt,
      this.deliveredAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['seq'] = Variable<int>(seq);
    map['sender_user_id'] = Variable<String>(senderUserId);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      messageId: Value(messageId),
      conversationId: Value(conversationId),
      seq: Value(seq),
      senderUserId: Value(senderUserId),
      body: Value(body),
      createdAt: Value(createdAt),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
    );
  }

  factory Message.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      messageId: serializer.fromJson<String>(json['messageId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      seq: serializer.fromJson<int>(json['seq']),
      senderUserId: serializer.fromJson<String>(json['senderUserId']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deliveredAt: serializer.fromJson<DateTime?>(json['deliveredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'conversationId': serializer.toJson<String>(conversationId),
      'seq': serializer.toJson<int>(seq),
      'senderUserId': serializer.toJson<String>(senderUserId),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deliveredAt': serializer.toJson<DateTime?>(deliveredAt),
    };
  }

  Message copyWith(
          {String? messageId,
          String? conversationId,
          int? seq,
          String? senderUserId,
          String? body,
          DateTime? createdAt,
          Value<DateTime?> deliveredAt = const Value.absent()}) =>
      Message(
        messageId: messageId ?? this.messageId,
        conversationId: conversationId ?? this.conversationId,
        seq: seq ?? this.seq,
        senderUserId: senderUserId ?? this.senderUserId,
        body: body ?? this.body,
        createdAt: createdAt ?? this.createdAt,
        deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
      );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      seq: data.seq.present ? data.seq.value : this.seq,
      senderUserId: data.senderUserId.present
          ? data.senderUserId.value
          : this.senderUserId,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deliveredAt:
          data.deliveredAt.present ? data.deliveredAt.value : this.deliveredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('seq: $seq, ')
          ..write('senderUserId: $senderUserId, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveredAt: $deliveredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, conversationId, seq, senderUserId,
      body, createdAt, deliveredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.messageId == this.messageId &&
          other.conversationId == this.conversationId &&
          other.seq == this.seq &&
          other.senderUserId == this.senderUserId &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.deliveredAt == this.deliveredAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> messageId;
  final Value<String> conversationId;
  final Value<int> seq;
  final Value<String> senderUserId;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deliveredAt;
  final Value<int> rowid;
  const MessagesCompanion({
    this.messageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.seq = const Value.absent(),
    this.senderUserId = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String messageId,
    required String conversationId,
    required int seq,
    required String senderUserId,
    required String body,
    required DateTime createdAt,
    this.deliveredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : messageId = Value(messageId),
        conversationId = Value(conversationId),
        seq = Value(seq),
        senderUserId = Value(senderUserId),
        body = Value(body),
        createdAt = Value(createdAt);
  static Insertable<Message> custom({
    Expression<String>? messageId,
    Expression<String>? conversationId,
    Expression<int>? seq,
    Expression<String>? senderUserId,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deliveredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (seq != null) 'seq': seq,
      if (senderUserId != null) 'sender_user_id': senderUserId,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith(
      {Value<String>? messageId,
      Value<String>? conversationId,
      Value<int>? seq,
      Value<String>? senderUserId,
      Value<String>? body,
      Value<DateTime>? createdAt,
      Value<DateTime?>? deliveredAt,
      Value<int>? rowid}) {
    return MessagesCompanion(
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      seq: seq ?? this.seq,
      senderUserId: senderUserId ?? this.senderUserId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (senderUserId.present) {
      map['sender_user_id'] = Variable<String>(senderUserId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('seq: $seq, ')
          ..write('senderUserId: $senderUserId, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalUsersTable localUsers = $LocalUsersTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $ConversationMembersTable conversationMembers =
      $ConversationMembersTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [localUsers, conversations, conversationMembers, messages];
}

typedef $$LocalUsersTableCreateCompanionBuilder = LocalUsersCompanion Function({
  required String internalUserId,
  required String firebaseUid,
  Value<String?> email,
  Value<String?> displayName,
  Value<String?> photoUrl,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalUsersTableUpdateCompanionBuilder = LocalUsersCompanion Function({
  Value<String> internalUserId,
  Value<String> firebaseUid,
  Value<String?> email,
  Value<String?> displayName,
  Value<String?> photoUrl,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalUsersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalUsersTable> {
  $$LocalUsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get internalUserId => $composableBuilder(
      column: $table.internalUserId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalUsersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalUsersTable> {
  $$LocalUsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get internalUserId => $composableBuilder(
      column: $table.internalUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photoUrl => $composableBuilder(
      column: $table.photoUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalUsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalUsersTable> {
  $$LocalUsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get internalUserId => $composableBuilder(
      column: $table.internalUserId, builder: (column) => column);

  GeneratedColumn<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalUsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalUsersTable,
    LocalUser,
    $$LocalUsersTableFilterComposer,
    $$LocalUsersTableOrderingComposer,
    $$LocalUsersTableAnnotationComposer,
    $$LocalUsersTableCreateCompanionBuilder,
    $$LocalUsersTableUpdateCompanionBuilder,
    (LocalUser, BaseReferences<_$AppDatabase, $LocalUsersTable, LocalUser>),
    LocalUser,
    PrefetchHooks Function()> {
  $$LocalUsersTableTableManager(_$AppDatabase db, $LocalUsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalUsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalUsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalUsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> internalUserId = const Value.absent(),
            Value<String> firebaseUid = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> photoUrl = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalUsersCompanion(
            internalUserId: internalUserId,
            firebaseUid: firebaseUid,
            email: email,
            displayName: displayName,
            photoUrl: photoUrl,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String internalUserId,
            required String firebaseUid,
            Value<String?> email = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> photoUrl = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalUsersCompanion.insert(
            internalUserId: internalUserId,
            firebaseUid: firebaseUid,
            email: email,
            displayName: displayName,
            photoUrl: photoUrl,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalUsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalUsersTable,
    LocalUser,
    $$LocalUsersTableFilterComposer,
    $$LocalUsersTableOrderingComposer,
    $$LocalUsersTableAnnotationComposer,
    $$LocalUsersTableCreateCompanionBuilder,
    $$LocalUsersTableUpdateCompanionBuilder,
    (LocalUser, BaseReferences<_$AppDatabase, $LocalUsersTable, LocalUser>),
    LocalUser,
    PrefetchHooks Function()>;
typedef $$ConversationsTableCreateCompanionBuilder = ConversationsCompanion
    Function({
  required String conversationId,
  required String kind,
  required String otherUserId,
  Value<String?> otherEmail,
  Value<String?> otherDisplayName,
  Value<String?> otherPhotoUrl,
  required int lastSeq,
  Value<DateTime?> lastMessageAt,
  Value<int> rowid,
});
typedef $$ConversationsTableUpdateCompanionBuilder = ConversationsCompanion
    Function({
  Value<String> conversationId,
  Value<String> kind,
  Value<String> otherUserId,
  Value<String?> otherEmail,
  Value<String?> otherDisplayName,
  Value<String?> otherPhotoUrl,
  Value<int> lastSeq,
  Value<DateTime?> lastMessageAt,
  Value<int> rowid,
});

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherUserId => $composableBuilder(
      column: $table.otherUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherEmail => $composableBuilder(
      column: $table.otherEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherDisplayName => $composableBuilder(
      column: $table.otherDisplayName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherPhotoUrl => $composableBuilder(
      column: $table.otherPhotoUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastSeq => $composableBuilder(
      column: $table.lastSeq, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastMessageAt => $composableBuilder(
      column: $table.lastMessageAt, builder: (column) => ColumnFilters(column));
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherUserId => $composableBuilder(
      column: $table.otherUserId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherEmail => $composableBuilder(
      column: $table.otherEmail, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherDisplayName => $composableBuilder(
      column: $table.otherDisplayName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherPhotoUrl => $composableBuilder(
      column: $table.otherPhotoUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastSeq => $composableBuilder(
      column: $table.lastSeq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastMessageAt => $composableBuilder(
      column: $table.lastMessageAt,
      builder: (column) => ColumnOrderings(column));
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get otherUserId => $composableBuilder(
      column: $table.otherUserId, builder: (column) => column);

  GeneratedColumn<String> get otherEmail => $composableBuilder(
      column: $table.otherEmail, builder: (column) => column);

  GeneratedColumn<String> get otherDisplayName => $composableBuilder(
      column: $table.otherDisplayName, builder: (column) => column);

  GeneratedColumn<String> get otherPhotoUrl => $composableBuilder(
      column: $table.otherPhotoUrl, builder: (column) => column);

  GeneratedColumn<int> get lastSeq =>
      $composableBuilder(column: $table.lastSeq, builder: (column) => column);

  GeneratedColumn<DateTime> get lastMessageAt => $composableBuilder(
      column: $table.lastMessageAt, builder: (column) => column);
}

class $$ConversationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      Conversation,
      BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>
    ),
    Conversation,
    PrefetchHooks Function()> {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> conversationId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> otherUserId = const Value.absent(),
            Value<String?> otherEmail = const Value.absent(),
            Value<String?> otherDisplayName = const Value.absent(),
            Value<String?> otherPhotoUrl = const Value.absent(),
            Value<int> lastSeq = const Value.absent(),
            Value<DateTime?> lastMessageAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationsCompanion(
            conversationId: conversationId,
            kind: kind,
            otherUserId: otherUserId,
            otherEmail: otherEmail,
            otherDisplayName: otherDisplayName,
            otherPhotoUrl: otherPhotoUrl,
            lastSeq: lastSeq,
            lastMessageAt: lastMessageAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String conversationId,
            required String kind,
            required String otherUserId,
            Value<String?> otherEmail = const Value.absent(),
            Value<String?> otherDisplayName = const Value.absent(),
            Value<String?> otherPhotoUrl = const Value.absent(),
            required int lastSeq,
            Value<DateTime?> lastMessageAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationsCompanion.insert(
            conversationId: conversationId,
            kind: kind,
            otherUserId: otherUserId,
            otherEmail: otherEmail,
            otherDisplayName: otherDisplayName,
            otherPhotoUrl: otherPhotoUrl,
            lastSeq: lastSeq,
            lastMessageAt: lastMessageAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConversationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ConversationsTable,
    Conversation,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      Conversation,
      BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>
    ),
    Conversation,
    PrefetchHooks Function()>;
typedef $$ConversationMembersTableCreateCompanionBuilder
    = ConversationMembersCompanion Function({
  required String conversationId,
  required String userId,
  required int lastReadSeq,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ConversationMembersTableUpdateCompanionBuilder
    = ConversationMembersCompanion Function({
  Value<String> conversationId,
  Value<String> userId,
  Value<int> lastReadSeq,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ConversationMembersTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationMembersTable> {
  $$ConversationMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastReadSeq => $composableBuilder(
      column: $table.lastReadSeq, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ConversationMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationMembersTable> {
  $$ConversationMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastReadSeq => $composableBuilder(
      column: $table.lastReadSeq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ConversationMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationMembersTable> {
  $$ConversationMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get lastReadSeq => $composableBuilder(
      column: $table.lastReadSeq, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConversationMembersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConversationMembersTable,
    ConversationMember,
    $$ConversationMembersTableFilterComposer,
    $$ConversationMembersTableOrderingComposer,
    $$ConversationMembersTableAnnotationComposer,
    $$ConversationMembersTableCreateCompanionBuilder,
    $$ConversationMembersTableUpdateCompanionBuilder,
    (
      ConversationMember,
      BaseReferences<_$AppDatabase, $ConversationMembersTable,
          ConversationMember>
    ),
    ConversationMember,
    PrefetchHooks Function()> {
  $$ConversationMembersTableTableManager(
      _$AppDatabase db, $ConversationMembersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationMembersTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationMembersTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> conversationId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<int> lastReadSeq = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationMembersCompanion(
            conversationId: conversationId,
            userId: userId,
            lastReadSeq: lastReadSeq,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String conversationId,
            required String userId,
            required int lastReadSeq,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationMembersCompanion.insert(
            conversationId: conversationId,
            userId: userId,
            lastReadSeq: lastReadSeq,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConversationMembersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ConversationMembersTable,
    ConversationMember,
    $$ConversationMembersTableFilterComposer,
    $$ConversationMembersTableOrderingComposer,
    $$ConversationMembersTableAnnotationComposer,
    $$ConversationMembersTableCreateCompanionBuilder,
    $$ConversationMembersTableUpdateCompanionBuilder,
    (
      ConversationMember,
      BaseReferences<_$AppDatabase, $ConversationMembersTable,
          ConversationMember>
    ),
    ConversationMember,
    PrefetchHooks Function()>;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  required String messageId,
  required String conversationId,
  required int seq,
  required String senderUserId,
  required String body,
  required DateTime createdAt,
  Value<DateTime?> deliveredAt,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<String> messageId,
  Value<String> conversationId,
  Value<int> seq,
  Value<String> senderUserId,
  Value<String> body,
  Value<DateTime> createdAt,
  Value<DateTime?> deliveredAt,
  Value<int> rowid,
});

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderUserId => $composableBuilder(
      column: $table.senderUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => ColumnFilters(column));
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderUserId => $composableBuilder(
      column: $table.senderUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get senderUserId => $composableBuilder(
      column: $table.senderUserId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => column);
}

class $$MessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()> {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> messageId = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<int> seq = const Value.absent(),
            Value<String> senderUserId = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> deliveredAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion(
            messageId: messageId,
            conversationId: conversationId,
            seq: seq,
            senderUserId: senderUserId,
            body: body,
            createdAt: createdAt,
            deliveredAt: deliveredAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String messageId,
            required String conversationId,
            required int seq,
            required String senderUserId,
            required String body,
            required DateTime createdAt,
            Value<DateTime?> deliveredAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            messageId: messageId,
            conversationId: conversationId,
            seq: seq,
            senderUserId: senderUserId,
            body: body,
            createdAt: createdAt,
            deliveredAt: deliveredAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalUsersTableTableManager get localUsers =>
      $$LocalUsersTableTableManager(_db, _db.localUsers);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$ConversationMembersTableTableManager get conversationMembers =>
      $$ConversationMembersTableTableManager(_db, _db.conversationMembers);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
}
