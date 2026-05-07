import 'package:apptest_messaging/core/models/me_response.dart';
import 'package:apptest_messaging/core/providers.dart' show appDatabaseProvider, dioProvider, idTokenProvider, localUserProvider;
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

      return me;
    });
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
