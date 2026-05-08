import 'dart:async';

import 'package:apptest_messaging/core/auth_tab_sync/auth_tab_sync.dart';
import 'package:apptest_messaging/core/models/me_response.dart';
import 'package:apptest_messaging/core/providers.dart'
    show
        appDatabaseProvider,
        chatApiProvider,
        chatRepositoryProvider,
        dioProvider,
        idTokenProvider,
        localUserProvider;
import 'package:apptest_messaging/core/providers.dart' show wsClientProvider;
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// OAuth 2.0 **Web client** ID (`*.apps.googleusercontent.com`) for `google_sign_in_web`.
/// Not secret (public in the browser). Prefer `--dart-define` on web, or set
/// `<meta name="google-signin-client_id" content="..." />` in `web/index.html`.
const _kGoogleOAuthWebClientId = String.fromEnvironment(
  'GOOGLE_OAUTH_WEB_CLIENT_ID',
  defaultValue: '',
);

const _kBootstrapAuthWait = Duration(seconds: 12);
const _kIdTokenTimeout = Duration(seconds: 20);

final RegExp anonymousHandlePatternDemo = RegExp(r'^[a-z0-9_]{3,24}$');

Future<String?> _fetchIdTokenWithTimeout(User user) async {
  try {
    final t = await user.getIdToken().timeout(_kIdTokenTimeout);
    if (t == null || t.isEmpty) {
      return null;
    }
    return t;
  } on TimeoutException {
    return null;
  }
}

final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, MeResponse?>(SessionNotifier.new);

class SessionNotifier extends AsyncNotifier<MeResponse?> {
  StreamSubscription<User?>? _firebaseAuthUidSub;
  String? _trackedAuthUid;
  StreamSubscription? _wsSub;

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb && _kGoogleOAuthWebClientId.isNotEmpty
        ? _kGoogleOAuthWebClientId
        : null,
    scopes: const ['email', 'openid'],
  );

  @override
  Future<MeResponse?> build() async {
    try {
      // Web: persistence restore is async; reading currentUser too early yields a
      // false "signed out" snapshot. Wait once for the restored authState first.
      await _awaitInitialAuthStateBroadcast();

      _attachFirebaseUidListenerIfNeeded();
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return null;
      }
      final token = await _fetchIdTokenWithTimeout(user);
      if (token == null || token.isEmpty) {
        ref.read(idTokenProvider.notifier).state = null;
        return null;
      }
      ref.read(idTokenProvider.notifier).state = token;

      final dio = ref.read(dioProvider);
      final res = await dio.get<Map<String, dynamic>>('/api/v1/me');
      final data = res.data;
      if (data == null) {
        return null;
      }
      final me = MeResponse.fromJson(data);

      await _clearChatIfDifferentUser(me);

      await ref.read(appDatabaseProvider).upsertMe(
            internalUserId: me.userId,
            firebaseUid: me.firebaseUid,
            email: me.email,
            displayName: me.displayName,
            photoUrl: me.photoUrl,
          );
      ref.invalidate(localUserProvider);

      // Never block rendering the shell on inbox network/Drift; Inbox syncs itself.
      // ignore: unawaited_futures
      ref
          .read(chatRepositoryProvider)
          .syncInbox(selfUserId: me.userId)
          .catchError((_) {});

      // Don't block app startup on WS connect; failures should not blank the UI.
      final ws = ref.read(wsClientProvider);
      // ignore: unawaited_futures
      ws.connect(idToken: token);

      await _wsSub?.cancel();
      _wsSub = ws.events.listen((env) async {
        final t = env['t'] as String?;
        final data = (env['data'] as Map?)?.cast<String, dynamic>();
        if (t == 'msg.new' && data != null) {
          final conversationId = data['conversationId'] as String?;
          final messageId = data['messageId'] as String?;
          final seq = (data['seq'] as num?)?.toInt();
          final senderUserId = data['senderUserId'] as String?;
          final body = data['body'] as String?;
          final createdAt =
              DateTime.tryParse((data['createdAt'] as String?) ?? '')?.toUtc();
          if (conversationId == null ||
              messageId == null ||
              seq == null ||
              senderUserId == null ||
              body == null ||
              createdAt == null) {
            return;
          }
          final db = ref.read(appDatabaseProvider);
          await db.upsertMessage(
            messageId: messageId,
            conversationId: conversationId,
            seq: seq,
            senderUserId: senderUserId,
            body: body,
            createdAt: createdAt,
            deliveredAt: DateTime.tryParse((data['deliveredAt'] as String?) ?? '')
                ?.toUtc(),
            deletedAt: DateTime.tryParse((data['deletedAt'] as String?) ?? '')
                ?.toUtc(),
          );
          await db.updateConversationLast(
            conversationId: conversationId,
            lastSeq: seq,
            lastMessageAt: createdAt,
          );

          final existingConv = await db.getConversationById(conversationId);
          if (existingConv == null) {
            await ref.read(chatRepositoryProvider).syncInbox(selfUserId: me.userId);
          }

          if (senderUserId != me.userId) {
            ws.sendDelivered(conversationId: conversationId, seq: seq);
          }
        } else if (t == 'msg.delivered' && data != null) {
          final conversationId = data['conversationId'] as String?;
          final seq = (data['seq'] as num?)?.toInt();
          final deliveredAt =
              DateTime.tryParse((data['deliveredAt'] as String?) ?? '')?.toUtc();
          if (conversationId == null || seq == null || deliveredAt == null) return;
          await ref.read(appDatabaseProvider).updateMessageDeliveredAt(
                conversationId: conversationId,
                seq: seq,
                deliveredAt: deliveredAt,
              );
        } else if (t == 'msg.deleted' && data != null) {
          final conversationId = data['conversationId'] as String?;
          final seq = (data['seq'] as num?)?.toInt();
          final deletedAt =
              DateTime.tryParse((data['deletedAt'] as String?) ?? '')?.toUtc();
          if (conversationId == null || seq == null || deletedAt == null) return;
          await ref.read(appDatabaseProvider).markMessageDeleted(
                conversationId: conversationId,
                seq: seq,
                deletedAt: deletedAt,
              );
        }
      });

      return me;
    } catch (_) {
      // If anything goes wrong during bootstrap (network/auth/WS), fall back to logged-out state.
      ref.read(idTokenProvider.notifier).state = null;
      return null;
    }
  }

  void _attachFirebaseUidListenerIfNeeded() {
    if (_firebaseAuthUidSub != null) {
      return;
    }
    _trackedAuthUid = FirebaseAuth.instance.currentUser?.uid;
    _firebaseAuthUidSub =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      final nextUid = user?.uid;
      if (nextUid == _trackedAuthUid) {
        return;
      }
      _trackedAuthUid = nextUid;
      Future.microtask(() {
        try {
          ref.invalidate(sessionProvider);
        } catch (_) {}
      });
    });

    ref.onDispose(() {
      _firebaseAuthUidSub?.cancel();
      _firebaseAuthUidSub = null;
      _trackedAuthUid = null;
    });
  }

  Future<void> _awaitInitialAuthStateBroadcast() async {
    try {
      await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(_kBootstrapAuthWait);
    } on TimeoutException {
      // Proceed with whatever currentUser is; avoids infinite spinner on web quirks.
    } catch (_) {}
  }

  Future<void> _clearChatIfDifferentUser(MeResponse me) async {
    final db = ref.read(appDatabaseProvider);
    final prev = await db.getMe();
    if (prev != null && prev.internalUserId != me.userId) {
      await db.clearAllLocalChatData();
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw StateError('Google sign-in cancelled');
      }
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
        throw StateError('Firebase user missing after Google sign-in');
      }
      final token = await _fetchIdTokenWithTimeout(user);
      if (token == null || token.isEmpty) {
        throw StateError('Firebase ID token missing');
      }
      ref.read(idTokenProvider.notifier).state = token;

      final dio = ref.read(dioProvider);
      final res = await dio.get<Map<String, dynamic>>('/api/v1/me');
      final data = res.data;
      if (data == null) {
        throw StateError('Empty /api/v1/me body');
      }
      final me = MeResponse.fromJson(data);

      await _clearChatIfDifferentUser(me);

      await ref.read(appDatabaseProvider).upsertMe(
            internalUserId: me.userId,
            firebaseUid: me.firebaseUid,
            email: me.email,
            displayName: me.displayName,
            photoUrl: me.photoUrl,
          );
      ref.invalidate(localUserProvider);

      await ref.read(chatRepositoryProvider).syncInbox(selfUserId: me.userId);

      final ws = ref.read(wsClientProvider);
      await ws.connect(idToken: token);
      await _wsSub?.cancel();
      _wsSub = ws.events.listen((env) async {
        final t = env['t'] as String?;
        final data = (env['data'] as Map?)?.cast<String, dynamic>();
        if (t == 'msg.new' && data != null) {
          final conversationId = data['conversationId'] as String?;
          final messageId = data['messageId'] as String?;
          final seq = (data['seq'] as num?)?.toInt();
          final senderUserId = data['senderUserId'] as String?;
          final body = data['body'] as String?;
          final createdAt = DateTime.tryParse((data['createdAt'] as String?) ?? '')?.toUtc();
          if (conversationId == null ||
              messageId == null ||
              seq == null ||
              senderUserId == null ||
              body == null ||
              createdAt == null) {
            return;
          }
          final db = ref.read(appDatabaseProvider);
          await db.upsertMessage(
            messageId: messageId,
            conversationId: conversationId,
            seq: seq,
            senderUserId: senderUserId,
            body: body,
            createdAt: createdAt,
            deliveredAt: DateTime.tryParse((data['deliveredAt'] as String?) ?? '')?.toUtc(),
            deletedAt: DateTime.tryParse((data['deletedAt'] as String?) ?? '')?.toUtc(),
          );
          await db.updateConversationLast(
            conversationId: conversationId,
            lastSeq: seq,
            lastMessageAt: createdAt,
          );

          final existingConv = await db.getConversationById(conversationId);
          if (existingConv == null) {
            await ref.read(chatRepositoryProvider).syncInbox(selfUserId: me.userId);
          }

          if (senderUserId != me.userId) {
            ws.sendDelivered(conversationId: conversationId, seq: seq);
          }
        } else if (t == 'msg.delivered' && data != null) {
          final conversationId = data['conversationId'] as String?;
          final seq = (data['seq'] as num?)?.toInt();
          final deliveredAt =
              DateTime.tryParse((data['deliveredAt'] as String?) ?? '')?.toUtc();
          if (conversationId == null || seq == null || deliveredAt == null) return;
          await ref.read(appDatabaseProvider).updateMessageDeliveredAt(
                conversationId: conversationId,
                seq: seq,
                deliveredAt: deliveredAt,
              );
        } else if (t == 'msg.deleted' && data != null) {
          final conversationId = data['conversationId'] as String?;
          final seq = (data['seq'] as num?)?.toInt();
          final deletedAt =
              DateTime.tryParse((data['deletedAt'] as String?) ?? '')?.toUtc();
          if (conversationId == null || seq == null || deletedAt == null) return;
          await ref.read(appDatabaseProvider).markMessageDeleted(
                conversationId: conversationId,
                seq: seq,
                deletedAt: deletedAt,
              );
        }
      });

      broadcastAuthTabSync('login');
      return me;
    });
  }

  /// Demo anonymous account: POST /auth/anonymous → Firebase custom token.
  Future<void> signInWithAnonymousDemo(String rawUsername) async {
    final normalized = rawUsername.trim().toLowerCase();
    if (!anonymousHandlePatternDemo.hasMatch(normalized)) {
      state = AsyncError(
        StateError(
          'Use 3–24 characters: lowercase a–z, digits, underscores only.',
        ),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      ref.read(idTokenProvider.notifier).state = null;
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      final ct = await ref.read(chatApiProvider).anonymousSignInDemo(username: normalized);
      final cred = await FirebaseAuth.instance.signInWithCustomToken(ct);
      final user = cred.user;
      if (user == null) {
        throw StateError('Firebase user missing after anonymous sign-in');
      }
      final token = await _fetchIdTokenWithTimeout(user);
      if (token == null || token.isEmpty) {
        throw StateError('Firebase ID token missing');
      }
      ref.read(idTokenProvider.notifier).state = token;

      final dio = ref.read(dioProvider);
      final res = await dio.get<Map<String, dynamic>>('/api/v1/me');
      final data = res.data;
      if (data == null) {
        throw StateError('Empty /api/v1/me body');
      }
      final me = MeResponse.fromJson(data);

      await _clearChatIfDifferentUser(me);

      await ref.read(appDatabaseProvider).upsertMe(
            internalUserId: me.userId,
            firebaseUid: me.firebaseUid,
            email: me.email,
            displayName: me.displayName,
            photoUrl: me.photoUrl,
          );
      ref.invalidate(localUserProvider);

      await ref.read(chatRepositoryProvider).syncInbox(selfUserId: me.userId);

      final ws = ref.read(wsClientProvider);
      await ws.connect(idToken: token);
      await _wsSub?.cancel();
      _wsSub = ws.events.listen((env) async {
        final t = env['t'] as String?;
        final data = (env['data'] as Map?)?.cast<String, dynamic>();
        if (t == 'msg.new' && data != null) {
          final conversationId = data['conversationId'] as String?;
          final messageId = data['messageId'] as String?;
          final seq = (data['seq'] as num?)?.toInt();
          final senderUserId = data['senderUserId'] as String?;
          final body = data['body'] as String?;
          final createdAt = DateTime.tryParse((data['createdAt'] as String?) ?? '')?.toUtc();
          if (conversationId == null ||
              messageId == null ||
              seq == null ||
              senderUserId == null ||
              body == null ||
              createdAt == null) {
            return;
          }
          final db = ref.read(appDatabaseProvider);
          await db.upsertMessage(
            messageId: messageId,
            conversationId: conversationId,
            seq: seq,
            senderUserId: senderUserId,
            body: body,
            createdAt: createdAt,
            deliveredAt: DateTime.tryParse((data['deliveredAt'] as String?) ?? '')?.toUtc(),
            deletedAt: DateTime.tryParse((data['deletedAt'] as String?) ?? '')?.toUtc(),
          );
          await db.updateConversationLast(
            conversationId: conversationId,
            lastSeq: seq,
            lastMessageAt: createdAt,
          );

          final existingConv = await db.getConversationById(conversationId);
          if (existingConv == null) {
            await ref.read(chatRepositoryProvider).syncInbox(selfUserId: me.userId);
          }

          if (senderUserId != me.userId) {
            ws.sendDelivered(conversationId: conversationId, seq: seq);
          }
        } else if (t == 'msg.delivered' && data != null) {
          final conversationId = data['conversationId'] as String?;
          final seq = (data['seq'] as num?)?.toInt();
          final deliveredAt =
              DateTime.tryParse((data['deliveredAt'] as String?) ?? '')?.toUtc();
          if (conversationId == null || seq == null || deliveredAt == null) return;
          await ref.read(appDatabaseProvider).updateMessageDeliveredAt(
                conversationId: conversationId,
                seq: seq,
                deliveredAt: deliveredAt,
              );
        } else if (t == 'msg.deleted' && data != null) {
          final conversationId = data['conversationId'] as String?;
          final seq = (data['seq'] as num?)?.toInt();
          final deletedAt =
              DateTime.tryParse((data['deletedAt'] as String?) ?? '')?.toUtc();
          if (conversationId == null || seq == null || deletedAt == null) return;
          await ref.read(appDatabaseProvider).markMessageDeleted(
                conversationId: conversationId,
                seq: seq,
                deletedAt: deletedAt,
              );
        }
      });

      broadcastAuthTabSync('login');
      return me;
    });
  }

  Future<void> signOut() async {
    await _wsSub?.cancel();
    _wsSub = null;
    await ref.read(wsClientProvider).close();

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Still try to propagate sign-out UX to other tabs.
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Web can throw if google_sign_in was not used this session; ignore.
    }

    ref.read(idTokenProvider.notifier).state = null;
    ref.invalidate(localUserProvider);
    try {
      await ref.read(appDatabaseProvider).clearAllLocalChatData();
    } catch (_) {}
    state = const AsyncData(null);
    broadcastAuthTabSync('logout');
  }

  String formatDioError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final body = e.response?.data;
      return 'HTTP $code ${body ?? e.message}';
    }
    return e.toString();
  }
}
