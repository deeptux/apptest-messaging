import 'dart:async';

import 'package:apptest_messaging/core/models/me_response.dart';
import 'package:apptest_messaging/core/providers.dart'
    show
        appDatabaseProvider,
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

final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, MeResponse?>(SessionNotifier.new);

class SessionNotifier extends AsyncNotifier<MeResponse?> {
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb && _kGoogleOAuthWebClientId.isNotEmpty
        ? _kGoogleOAuthWebClientId
        : null,
    scopes: const ['email', 'openid'],
  );

  @override
  Future<MeResponse?> build() async {
    return null;
  }

  StreamSubscription? _wsSub;

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
      final token = await user.getIdToken();
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
          );
          await db.updateConversationLast(
            conversationId: conversationId,
            lastSeq: seq,
            lastMessageAt: createdAt,
          );

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
        }
      });

      return me;
    });
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
    await _wsSub?.cancel();
    _wsSub = null;
    await ref.read(wsClientProvider).close();
    ref.read(idTokenProvider.notifier).state = null;
    ref.invalidate(localUserProvider);
    state = const AsyncData(null);
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
