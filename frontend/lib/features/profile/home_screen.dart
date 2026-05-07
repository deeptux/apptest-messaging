import 'package:apptest_messaging/core/providers.dart' show localUserProvider;
import 'package:apptest_messaging/features/auth/session_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return session.when(
      data: (me) {
        if (me == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Messaging MVP')),
            body: Center(
              child: FilledButton.icon(
                onPressed: () =>
                    ref.read(sessionProvider.notifier).signInWithGoogle(),
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              ),
            ),
          );
        }
        final local = ref.watch(localUserProvider);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Signed in'),
            actions: [
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                Text('Server profile', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('userId: ${me.userId}'),
                Text('firebaseUid: ${me.firebaseUid}'),
                Text('email: ${me.email ?? '—'}'),
                Text('displayName: ${me.displayName ?? '—'}'),
                Text('photoUrl: ${me.photoUrl ?? '—'}'),
                const Divider(height: 32),
                Text('Drift cache', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                local.when(
                  data: (row) {
                    if (row == null) {
                      return const Text('No local row (unexpected).');
                    }
                    return Text(
                      'internalUserId: ${row.internalUserId}\n'
                      'firebaseUid: ${row.firebaseUid}\n'
                      'email: ${row.email ?? '—'}\n'
                      'displayName: ${row.displayName ?? '—'}\n'
                      'updatedAt: ${row.updatedAt.toIso8601String()}',
                    );
                  },
                  loading: () => const Text('Loading local row…'),
                  error: (e, _) => Text('Local error: $e'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) {
        final formatted = ref.read(sessionProvider.notifier).formatDioError(e);
        return Scaffold(
        appBar: AppBar(title: const Text('Sign-in error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    formatted,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(sessionProvider.notifier).signInWithGoogle(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Google sign-in'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(sessionProvider),
                    child: const Text('Back to welcome'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
  }
}
