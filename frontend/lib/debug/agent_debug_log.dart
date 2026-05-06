import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Minimal debug helper retained by temporary instrumentation callsites.
void agentDebugLog({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?>? data,
}) {
  final payload = <String, Object?>{
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data ?? const <String, Object?>{},
    'timestamp': DateTime.now().toIso8601String(),
  };
  debugPrint('[agent-debug] ${jsonEncode(payload)}');
}

String agentErrorSnippet(Object err) {
  final text = err.toString();
  return text.length <= 180 ? text : text.substring(0, 180);
}
