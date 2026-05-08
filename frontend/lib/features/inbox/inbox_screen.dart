import 'dart:ui' show ImageFilter;

import 'package:apptest_messaging/core/providers.dart';
import 'package:apptest_messaging/core/database/app_database.dart';
import 'package:apptest_messaging/features/auth/session_notifier.dart';
import 'package:apptest_messaging/features/chat/chat_screen.dart';
import 'package:apptest_messaging/features/inbox/new_chat_screen.dart';
import 'package:apptest_messaging/core/models/me_response.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key, required this.me});

  final MeResponse me;

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  /// While non-null, that row shows a remove spinner; other rows' remove control is disabled.
  String? _hidingConversationId;

  /// Full-screen glass overlay + bar while pushing [ChatScreen].
  bool _navigatingToChat = false;

  bool get _blockingInboxPointer =>
      _navigatingToChat || _hidingConversationId != null;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(chatRepositoryProvider).syncInbox(selfUserId: widget.me.userId);
    });
  }

  @override
  void didUpdateWidget(covariant InboxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.me.userId != widget.me.userId) {
      Future.microtask(() async {
        await ref.read(chatRepositoryProvider).syncInbox(selfUserId: widget.me.userId);
      });
    }
  }

  String _inboxTitle() {
    final anon = widget.me.anonymousUsername?.trim();
    if (anon != null && anon.isNotEmpty) {
      final friendly = widget.me.displayName?.trim();
      final name =
          (friendly != null && friendly.isNotEmpty) ? friendly : anon;
      return 'Inbox | Hi $name!';
    }
    final dn = widget.me.displayName?.trim();
    if (dn != null && dn.isNotEmpty) {
      return 'Inbox | Hi $dn!';
    }
    final em = widget.me.email?.trim();
    if (em != null && em.isNotEmpty) {
      return 'Inbox | Hi $em!';
    }
    return 'Inbox';
  }

  @override
  Widget build(BuildContext inboxContext) {
    final db = ref.watch(appDatabaseProvider);
    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(
        title: Text(
          _inboxTitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: () => Navigator.of(inboxContext).push(
              MaterialPageRoute(builder: (_) => NewChatScreen(selfUserId: widget.me.userId)),
            ),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _blockingInboxPointer,
        child: StreamBuilder<List<Conversation>>(
        stream: (db.select(db.conversations)
              ..orderBy([
                (c) => drift.OrderingTerm(
                      expression: c.lastMessageAt,
                      mode: drift.OrderingMode.desc,
                      nulls: drift.NullsOrder.last,
                    ),
                (c) => drift.OrderingTerm(expression: c.conversationId),
              ]))
            .watch(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load inbox: ${snap.error}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        Future<void>.microtask(
                          () => ref.invalidate(appDatabaseProvider),
                        );
                      },
                      child: const Text('Retry local database'),
                    ),
                  ],
                ),
              ),
            );
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No conversations yet. Tap + to start a chat.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (tileContext, i) {
              final c0 = rows[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  title: Text(
                    c0.otherDisplayName ?? c0.otherEmail ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    c0.otherEmail ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _UnreadBadge(
                        conversationId: c0.conversationId,
                        selfUserId: widget.me.userId,
                        lastSeq: c0.lastSeq,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: _hidingConversationId == c0.conversationId
                            ? Padding(
                                padding: const EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Theme.of(tileContext).colorScheme.primary,
                                ),
                              )
                            : IconButton(
                                tooltip: 'Remove (local)',
                                icon: const Icon(Icons.archive_outlined),
                                onPressed: _hidingConversationId != null
                                    ? null
                                    : () async {
                                        final ok = await showDialog<bool>(
                                          context: tileContext,
                                          builder: (dialogContext) => AlertDialog(
                                            title: const Text('Remove Conversation?'),
                                            content: const Text(
                                              'Removed, not deleted. It will reappear if a new message arrives.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogContext).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogContext).pop(true),
                                                child: const Text('Remove'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok != true) return;
                                        if (!mounted) return;
                                        if (!inboxContext.mounted) return;
                                        setState(() => _hidingConversationId = c0.conversationId);
                                        final container =
                                            ProviderScope.containerOf(inboxContext, listen: false);
                                        try {
                                          await container.read(chatRepositoryProvider).hideConversation(
                                                selfUserId: widget.me.userId,
                                                conversationId: c0.conversationId,
                                              );
                                        } catch (_) {
                                          if (!mounted || !inboxContext.mounted) return;
                                          ScaffoldMessenger.of(inboxContext).showSnackBar(
                                            const SnackBar(
                                                content: Text('Could not remove conversation')),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() => _hidingConversationId = null);
                                          }
                                        }
                                      },
                              ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (_navigatingToChat || _hidingConversationId != null) return;
                    setState(() => _navigatingToChat = true);
                    try {
                      await Navigator.of(tileContext).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            conversationId: c0.conversationId,
                            title: c0.otherDisplayName ?? c0.otherEmail ?? 'Chat',
                            selfUserId: widget.me.userId,
                          ),
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _navigatingToChat = false);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      ),
        ),
        if (_navigatingToChat)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Material(
                    color: Theme.of(inboxContext)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LinearProgressIndicator(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Opening chat…',
                                textAlign: TextAlign.center,
                                style: Theme.of(inboxContext).textTheme.titleSmall?.copyWith(
                                      color:
                                          Theme.of(inboxContext).colorScheme.onSurface.withValues(alpha: 0.85),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UnreadBadge extends ConsumerWidget {
  const _UnreadBadge({required this.conversationId, required this.selfUserId, required this.lastSeq});

  final String conversationId;
  final String selfUserId;
  final int lastSeq;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    return StreamBuilder<int>(
      stream: (db.select(db.conversationMembers)
            ..where((m) => m.conversationId.equals(conversationId) & m.userId.equals(selfUserId)))
          .watchSingleOrNull()
          .map((row) => row?.lastReadSeq ?? 0),
      builder: (context, snap) {
        if (snap.hasError) {
          return const SizedBox.shrink();
        }
        final lastRead = snap.data ?? 0;
        final unread = (lastSeq - lastRead).clamp(0, 999);
        if (unread <= 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            unread.toString(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}

