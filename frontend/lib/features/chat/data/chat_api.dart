import 'package:dio/dio.dart';

class ChatApi {
  ChatApi(this._dio);

  final Dio _dio;

  /// Search by email prefix, anonymous handle prefix, or display name substring (`q`).
  Future<List<Map<String, dynamic>>> searchContacts(String needle) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/users/search',
      queryParameters: {'q': needle},
    );
    final data = res.data;
    final users = (data?['users'] as List?)?.cast<Map>() ?? const [];
    return users.map((u) => u.cast<String, dynamic>()).toList();
  }

  /// Demo anonymous signup/login via backend-minted Firebase custom token (no Bearer).
  Future<String> anonymousSignInDemo({required String username}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/anonymous',
      data: {'username': username.trim().toLowerCase()},
    );
    final data = res.data;
    final ct = data?['customToken'] as String?;
    if (ct == null || ct.isEmpty) {
      throw StateError('Missing customToken from /auth/anonymous');
    }
    return ct;
  }

  Future<Map<String, dynamic>> openOrCreateDirect({required String otherUserId}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/conversations/direct',
      data: {'otherUserId': otherUserId},
    );
    return (res.data ?? const <String, dynamic>{});
  }

  Future<List<Map<String, dynamic>>> fetchInbox({int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/inbox',
      queryParameters: {'limit': limit},
    );
    final data = res.data;
    final convs = (data?['conversations'] as List?)?.cast<Map>() ?? const [];
    return convs.map((c) => c.cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMessages({
    required String conversationId,
    int limit = 50,
    int? beforeSeq,
  }) async {
    final qp = <String, dynamic>{'limit': limit};
    if (beforeSeq != null) qp['beforeSeq'] = beforeSeq;
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/conversations/$conversationId/messages',
      queryParameters: qp,
    );
    final data = res.data;
    final msgs = (data?['messages'] as List?)?.cast<Map>() ?? const [];
    return msgs.map((m) => m.cast<String, dynamic>()).toList();
  }

  Future<void> markRead({
    required String conversationId,
    required int lastReadSeq,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/conversations/$conversationId/read',
      data: {'lastReadSeq': lastReadSeq},
    );
  }

  Future<void> hideConversation({required String conversationId}) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/conversations/$conversationId/hide',
      data: const {},
    );
  }
}

