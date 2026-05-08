import 'dart:async';

import 'package:apptest_messaging/core/database/app_database.dart';
import 'package:apptest_messaging/core/providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

/// Persists read cursor after [ChatScreen] is torn down (e.g. before debounce fires).
Future<void> _flushReadAfterChatClosed(
  ProviderContainer container,
  String conversationId,
  String selfUserId,
) async {
  try {
    final db = container.read(appDatabaseProvider);
    final latest = await db.listMessagesLatest(conversationId: conversationId, limit: 1);
    if (latest.isEmpty) return;
    final tip = latest.first.seq;
    await container.read(chatRepositoryProvider).markRead(
          conversationId: conversationId,
          lastReadSeq: tip,
        );
    await db.upsertMember(
      conversationId: conversationId,
      userId: selfUserId,
      lastReadSeq: tip,
    );
    container.read(wsClientProvider).sendReadMark(
          conversationId: conversationId,
          lastReadSeq: tip,
        );
  } catch (_) {
    // Best-effort; inbox already uses local lastRead for badge.
  }
}

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

  /// Captured once built; used after dispose without touching [ref].
  ProviderContainer? _scopeContainer;

  /// Highest seq we have applied to local/API read state this visit.
  int _lastReadApplied = -1;

  Timer? _readDebounce;
  StreamSubscription<List<Message>>? _latestMsgSub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scopeContainer ??= ProviderScope.containerOf(context, listen: false);
      _attachLatestMessageSubscription();
    });

    Future.microtask(() async {
      if (!mounted) return;
      await ref.read(chatRepositoryProvider).syncLatestMessages(conversationId: widget.conversationId);
      if (!mounted) return;
      final db = ref.read(appDatabaseProvider);
      final latest = await db.listMessagesLatest(conversationId: widget.conversationId, limit: 1);
      if (!mounted) return;
      final lastSeq = latest.isEmpty ? 0 : latest.first.seq;
      await _applyReadSeq(lastSeq);
    });

    _scroll.addListener(() async {
      if (_loadingOlder) return;
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (!pos.hasContentDimensions) return;
      if (pos.pixels < pos.maxScrollExtent - 240) return;

      _loadingOlder = true;
      try {
        if (!mounted) return;
        final db = ref.read(appDatabaseProvider);
        final all = await (db.select(db.messages)
              ..where((m) => m.conversationId.equals(widget.conversationId))
              ..orderBy([(m) => drift.OrderingTerm(expression: m.seq, mode: drift.OrderingMode.asc)])
              ..limit(1))
            .get();
        if (!mounted) return;
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

  void _attachLatestMessageSubscription() {
    if (_latestMsgSub != null) return;
    final db = ref.read(appDatabaseProvider);
    final stream = (db.select(db.messages)
          ..where((m) => m.conversationId.equals(widget.conversationId))
          ..orderBy([(m) => drift.OrderingTerm(expression: m.seq, mode: drift.OrderingMode.desc)])
          ..limit(1))
        .watch();
    _latestMsgSub = stream.listen((rows) {
      if (!mounted || rows.isEmpty) return;
      final tipSeq = rows.first.seq;
      _scheduleApplyRead(tipSeq);
    });
  }

  void _scheduleApplyRead(int seq) {
    if (seq <= 0) return;
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      unawaited(_applyReadSeq(seq));
    });
  }

  Future<void> _applyReadSeq(int seq) async {
    if (!mounted || seq <= 0 || seq <= _lastReadApplied) return;
    _lastReadApplied = seq;
    await ref.read(chatRepositoryProvider).markRead(conversationId: widget.conversationId, lastReadSeq: seq);
    if (!mounted) return;
    final db = ref.read(appDatabaseProvider);
    await db.upsertMember(
      conversationId: widget.conversationId,
      userId: widget.selfUserId,
      lastReadSeq: seq,
    );
    if (!mounted) return;
    ref.read(wsClientProvider).sendReadMark(conversationId: widget.conversationId, lastReadSeq: seq);
  }

  @override
  void dispose() {
    _readDebounce?.cancel();
    _latestMsgSub?.cancel();
    final container = _scopeContainer;
    _scroll.dispose();
    _composer.dispose();
    super.dispose();
    if (container != null) {
      unawaited(_flushReadAfterChatClosed(container, widget.conversationId, widget.selfUserId));
    }
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

