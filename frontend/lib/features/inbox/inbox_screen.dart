import 'package:apptest_messaging/core/providers.dart';
import 'package:apptest_messaging/core/database/app_database.dart';
import 'package:apptest_messaging/features/auth/session_notifier.dart';
import 'package:apptest_messaging/features/chat/chat_screen.dart';
import 'package:apptest_messaging/features/inbox/new_chat_screen.dart';
import 'package:apptest_messaging/core/models/me_response.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key, required this.me});

  final MeResponse me;

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(chatRepositoryProvider).syncInbox(selfUserId: widget.me.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: () => Navigator.of(context).push(
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
      body: StreamBuilder<List<Conversation>>(
        stream: (db.select(db.conversations)
              ..orderBy([
                (c) => OrderingTerm(
                      expression: c.lastMessageAt,
                      mode: OrderingMode.desc,
                      nulls: NullsOrder.last,
                    ),
                (c) => OrderingTerm(expression: c.conversationId),
              ]))
            .watch(),
        builder: (context, snap) {
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
            itemBuilder: (context, i) {
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
                      IconButton(
                        tooltip: 'Delete (local)',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Remove Conversation?'),
                              content: const Text(
                                'Removed, not deleted. It will reappear if a new message arrives.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await ref.read(chatRepositoryProvider).hideConversation(
                                  selfUserId: widget.me.userId,
                                  conversationId: c0.conversationId,
                                );
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: c0.conversationId,
                          title: c0.otherDisplayName ?? c0.otherEmail ?? 'Chat',
                          selfUserId: widget.me.userId,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
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

