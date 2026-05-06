import 'package:apptest_messaging/core/models/me_response.dart';
import 'package:apptest_messaging/core/providers.dart' show appDatabaseProvider, dioProvider, idTokenProvider, localUserProvider;
import 'package:apptest_messaging/debug/agent_debug_log.dart';
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

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // #region agent log
      agentDebugLog(
        hypothesisId: 'H1',
        location: 'session_notifier.dart:signInWithGoogle',
        message: 'before GoogleSignIn.signIn',
      );
      // #endregion
      final account = await _googleSignIn.signIn();
      // #region agent log
      agentDebugLog(
        hypothesisId: 'H1',
        location: 'session_notifier.dart:signInWithGoogle',
        message: 'after GoogleSignIn.signIn',
        data: {'hasAccount': account != null},
      );
      // #endregion
      if (account == null) {
        throw StateError('Google sign-in cancelled');
      }
      final auth = await account.authentication;
      // #region agent log
      agentDebugLog(
        hypothesisId: 'H2',
        location: 'session_notifier.dart:signInWithGoogle',
        message: 'after account.authentication',
        data: {
          'hasAccessToken':
              auth.accessToken != null && auth.accessToken!.isNotEmpty,
          'hasIdToken': auth.idToken != null && auth.idToken!.isNotEmpty,
        },
      );
      // #endregion
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      // #region agent log
      agentDebugLog(
        hypothesisId: 'H3',
        location: 'session_notifier.dart:signInWithGoogle',
        message: 'after FirebaseAuth.signInWithCredential',
        data: {'hasUser': userCred.user != null},
      );
      // #endregion
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

      return me;
    });
    // #region agent log
    final err = state.error;
    if (err != null) {
      final text = err.toString();
      agentDebugLog(
        hypothesisId: 'H1',
        location: 'session_notifier.dart:signInWithGoogle:result',
        message: 'signInWithGoogle ended with error',
        data: {
          'errorType': err.runtimeType.toString(),
          'snippet': agentErrorSnippet(err),
          'mentionsPeopleApi': text.contains('people.googleapis.com'),
          'mentions403': text.contains('403'),
        },
      );
    } else {
      agentDebugLog(
        hypothesisId: 'H3',
        location: 'session_notifier.dart:signInWithGoogle:result',
        message: 'signInWithGoogle completed without error',
      );
    }
    // #endregion
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
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
