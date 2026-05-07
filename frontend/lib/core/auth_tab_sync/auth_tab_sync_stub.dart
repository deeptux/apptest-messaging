import 'dart:async';

StreamSubscription<void> listenAuthTabSyncEvents(
  void Function(String kind) onEvent,
) {
  return const Stream<void>.empty().listen((_) {});
}

void broadcastAuthTabSync(String kind) {}

void reloadAppPage() {}
