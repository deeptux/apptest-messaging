import 'package:apptest_messaging/core/database/app_database.dart';
import 'package:apptest_messaging/core/providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
    required this.selfUserId,
  });

  final String conversationId;
  final String title;
  final String selfUserId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  final _composer = TextEditingController();
  bool _loadingOlder = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await ref.read(chatRepositoryProvider).syncLatestMessages(conversationId: widget.conversationId);
      final db = ref.read(appDatabaseProvider);
      final latest = await db.listMessagesLatest(conversationId: widget.conversationId, limit: 1);
      final lastSeq = latest.isEmpty ? 0 : latest.first.seq;
      await ref.read(chatRepositoryProvider).markRead(conversationId: widget.conversationId, lastReadSeq: lastSeq);
      await db.upsertMember(
        conversationId: widget.conversationId,
        userId: widget.selfUserId,
        lastReadSeq: lastSeq,
      );
      ref.read(wsClientProvider).sendReadMark(conversationId: widget.conversationId, lastReadSeq: lastSeq);
    });

    _scroll.addListener(() async {
      if (_loadingOlder) return;
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (!pos.hasContentDimensions) return;
      if (pos.pixels < pos.maxScrollExtent - 240) return;

      _loadingOlder = true;
      try {
        final db = ref.read(appDatabaseProvider);
        final all = await (db.select(db.messages)
              ..where((m) => m.conversationId.equals(widget.conversationId))
              ..orderBy([(m) => drift.OrderingTerm(expression: m.seq, mode: drift.OrderingMode.asc)])
              ..limit(1))
            .get();
        final oldest = all.isEmpty ? null : all.first;
        if (oldest == null) return;
        final before = oldest.seq;
        await ref.read(chatRepositoryProvider).syncOlderMessages(
              conversationId: widget.conversationId,
              beforeSeq: before,
            );
      } finally {
        _loadingOlder = false;
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    final id = const Uuid().v4();
    ref.read(wsClientProvider).sendMessage(
          id: id,
          conversationId: widget.conversationId,
          body: text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: (db.select(db.messages)
                    ..where((m) => m.conversationId.equals(widget.conversationId))
                    ..orderBy([(m) => drift.OrderingTerm(expression: m.seq, mode: drift.OrderingMode.desc)]))
                  .watch(),
              builder: (context, snap) {
                final msgs = snap.data ?? const [];
                if (msgs.isEmpty) {
                  return const Center(child: Text('Say hi.'));
                }
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final mine = m.senderUserId == widget.selfUserId;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: mine ? Theme.of(context).colorScheme.primary : const Color(0xFF101018),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: GestureDetector(
                            onTap: () async {
                              final canDelete = mine && m.body != 'Message deleted';
                              await showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                builder: (_) => SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          m.body,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 12),
                                        if (canDelete)
                                          FilledButton.icon(
                                            onPressed: () {
                                              ref.read(wsClientProvider).sendDelete(
                                                    conversationId: widget.conversationId,
                                                    seq: m.seq,
                                                  );
                                              Navigator.of(context).pop();
                                            },
                                            icon: const Icon(Icons.delete),
                                            label: const Text('Delete'),
                                          )
                                        else
                                          const Text('No actions available.'),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Linkify(
                              text: m.body,
                              style: TextStyle(
                                color: mine ? Colors.black : Colors.white,
                                height: 1.25,
                              ),
                              linkStyle: const TextStyle(decoration: TextDecoration.underline),
                              onOpen: (link) async {
                                final uri = Uri.tryParse(link.url);
                                if (uri == null) return;
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _send,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

