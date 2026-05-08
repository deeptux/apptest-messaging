import 'dart:async';

import 'package:apptest_messaging/core/auth_tab_sync/auth_tab_sync.dart';
import 'package:apptest_messaging/features/auth/session_notifier.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
/// Listens for auth changes in other tabs (localStorage + BroadcastChannel on web).
/// Shows a modal and reloads so Firebase + Riverpod match the shared session.
class CrossTabAuthSync extends ConsumerStatefulWidget {
  const CrossTabAuthSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CrossTabAuthSync> createState() => _CrossTabAuthSyncState();
}

class _CrossTabAuthSyncState extends ConsumerState<CrossTabAuthSync> {
  StreamSubscription<void>? _sub;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _sub = listenAuthTabSyncEvents(_onOtherTabAuthChange);
  }

  void _onOtherTabAuthChange(String kind) {
    if (!mounted) return;
    final me = ref.read(sessionProvider).valueOrNull;

    if (kind == 'logout') {
      // Another tab signed out: always prompt + reload. Do not gate on
      // Firebase/Riverpod here — those often sync *before* this handler runs,
      // which made the old guard skip the dialog entirely.
      // ignore: unawaited_futures
      _showSyncDialog(kind);
      return;
    }

    if (kind == 'login') {
      if (me != null) return;
      // ignore: unawaited_futures
      _showSyncDialog(kind);
    }
  }

  Future<void> _showSyncDialog(String kind) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    try {
      final title = kind == 'logout'
          ? 'Signed out from another tab'
          : 'Signed in from another tab';
      final body = kind == 'logout'
          ? 'Your account was signed out in another window or tab for this site. Refresh this page so this tab loads the updated session.'
          : 'Someone signed in to this site in another window or tab. Refresh this page to load the signed-in session here.';
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        reloadAppPage();
      }
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
