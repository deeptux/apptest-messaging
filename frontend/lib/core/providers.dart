import 'package:apptest_messaging/core/config.dart';
import 'package:apptest_messaging/core/database/app_database.dart';
import 'package:apptest_messaging/features/chat/data/chat_api.dart';
import 'package:apptest_messaging/features/chat/data/chat_repository.dart';
import 'package:apptest_messaging/features/chat/data/ws_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory Firebase ID token for API calls (cleared on restart).
final idTokenProvider = StateProvider<String?>((ref) => null);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final dioProvider = Provider<Dio>((ref) {
  final base = requireApiBaseUrl();
  final dio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(idTokenProvider);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ),
  );
  return dio;
});

final localUserProvider = FutureProvider<LocalUser?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getMe();
});

final chatApiProvider = Provider<ChatApi>((ref) {
  return ChatApi(ref.watch(dioProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    api: ref.watch(chatApiProvider),
    db: ref.watch(appDatabaseProvider),
  );
});

final wsClientProvider = Provider<WsClient>((ref) {
  final c = WsClient();
  ref.onDispose(c.close);
  return c;
});
