import 'package:apptest_messaging/features/inbox/inbox_screen.dart';
import 'package:apptest_messaging/features/auth/session_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _showAnonymousDemoDialog(BuildContext context, WidgetRef ref) async {
    final ctl = TextEditingController();
    String? validation;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSt) {
            return AlertDialog(
              title: const Text('Anonymous demo login'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pick a unique handle for this demo. Lowercase letters, digits '
                      'and underscores (3–24). New handles get a cheerful random '
                      'name others see and can search.',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: ctl,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'e.g. guest_avery',
                      ),
                      onSubmitted: (_) {
                        setSt(() {});
                      },
                    ),
                    if (validation != null && validation!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        validation!,
                        style: TextStyle(color: Theme.of(ctx2).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final raw = ctl.text.trim();
                    setSt(() => validation = null);
                    await ref.read(sessionProvider.notifier).signInWithAnonymousDemo(raw);
                    if (!ctx.mounted) return;
                    final st = ref.read(sessionProvider);
                    if (st.hasError) {
                      setSt(() {
                        final e = st.error!;
                        validation = e is StateError
                            ? e.message
                            : ref
                                .read(sessionProvider.notifier)
                                .formatDioError(e);
                      });
                      return;
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
    ctl.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return session.when(
      data: (me) {
        if (me == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Messaging MVP')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(sessionProvider.notifier).signInWithGoogle(),
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in with Google'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showAnonymousDemoDialog(context, ref),
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Anonymous demo sign-in'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return InboxScreen(me: me);
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
                    OutlinedButton.icon(
                      onPressed: () => _showAnonymousDemoDialog(context, ref),
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Try anonymous demo'),
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
