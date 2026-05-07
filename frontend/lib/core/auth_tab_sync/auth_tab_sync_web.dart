import 'dart:async';
import 'dart:html' as html;
import 'dart:math';

const String _storageKey = 'apptest_messaging_auth_tab_v1';

final String _broadcastName = 'apptest_messaging_auth_tab_v1';
final String _tabId = List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

final html.BroadcastChannel _channel = html.BroadcastChannel(_broadcastName);

(String kind, int ts)? _parsePayload(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split('|');
  if (parts.length < 2) return null;
  final ts = int.tryParse(parts[0]);
  if (ts == null) return null;
  final kind = parts[1];
  if (kind != 'login' && kind != 'logout') return null;
  return (kind, ts);
}

/// Other tabs receive StorageEvents; BroadcastChannel is immediate. Sender tab
/// ignores its own BroadcastChannel messages via `_tabId`.
StreamSubscription<void> listenAuthTabSyncEvents(
  void Function(String kind) onEvent,
) {
  int? lastTs;
  String? lastKind;

  void dispatch(String raw, {required bool filterOwnTabEcho}) {
    final parsed = _parsePayload(raw);
    if (parsed == null) return;
    final (kind, ts) = parsed;

    if (filterOwnTabEcho) {
      final parts = raw.split('|');
      if (parts.length >= 3 && parts[2] == _tabId) {
        return;
      }
    }

    if (lastTs == ts && lastKind == kind) return;
    lastTs = ts;
    lastKind = kind;
    onEvent(kind);
  }

  StreamSubscription<html.Event>? subStorage;
  StreamSubscription<html.MessageEvent>? subBc;

  final controller = StreamController<void>(
    sync: true,
    onCancel: () {
      subStorage?.cancel();
      subBc?.cancel();
      subStorage = null;
      subBc = null;
    },
  );

  subStorage = html.window.onStorage.listen((html.StorageEvent e) {
    if (e.key != _storageKey) return;
    final nv = e.newValue;
    if (nv == null || nv.isEmpty) return;
    dispatch(nv, filterOwnTabEcho: false);
  });

  subBc = _channel.onMessage.listen((html.MessageEvent e) {
    final raw = '${e.data}';
    if (raw.isEmpty) return;
    dispatch(raw, filterOwnTabEcho: true);
  });

  return controller.stream.listen((_) {});
}

void broadcastAuthTabSync(String kind) {
  assert(kind == 'login' || kind == 'logout');
  final ts = DateTime.now().millisecondsSinceEpoch;
  final payload = '$ts|$kind|$_tabId';
  html.window.localStorage[_storageKey] = payload;
  _channel.postMessage(payload);
}

void reloadAppPage() {
  html.window.location.reload();
}
