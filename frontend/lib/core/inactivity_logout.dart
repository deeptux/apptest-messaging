import 'dart:async';

import 'package:apptest_messaging/features/auth/session_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InactivityLogout extends ConsumerStatefulWidget {
  const InactivityLogout({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 5),
  });

  final Widget child;
  final Duration timeout;

  @override
  ConsumerState<InactivityLogout> createState() => _InactivityLogoutState();
}

class _InactivityLogoutState extends ConsumerState<InactivityLogout> {
  Timer? _timer;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _onTimeout);
  }

  void _onUserActivity() {
    final session = ref.read(sessionProvider);
    if (session.valueOrNull == null) return;
    _arm();
  }

  Future<void> _onTimeout() async {
    final session = ref.read(sessionProvider);
    if (session.valueOrNull == null) return;
    if (_dialogOpen) return;

    _dialogOpen = true;
    try {
      final ctx = context;
      final ok = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Signed out'),
          content: const Text('You were signed out due to inactivity.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(sessionProvider.notifier).signOut();
      }
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserActivity(),
      onPointerMove: (_) => _onUserActivity(),
      onPointerSignal: (_) => _onUserActivity(),
      child: widget.child,
    );
  }
}

