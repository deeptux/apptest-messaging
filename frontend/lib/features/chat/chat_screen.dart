import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:apptest_messaging/core/database/app_database.dart';
import 'package:apptest_messaging/core/providers.dart';
import 'package:apptest_messaging/features/auth/session_notifier.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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

String _formatChatTimestamp(DateTime utc) {
  final local = utc.toLocal();
  final now = DateTime.now();
  final isSameDay = local.year == now.year && local.month == now.month && local.day == now.day;

  final h24 = local.hour;
  final min = local.minute;
  final isPm = h24 >= 12;
  var h12 = h24 % 12;
  if (h12 == 0) h12 = 12;
  final mm = min.toString().padLeft(2, '0');
  final time = '$h12:$mm ${isPm ? 'PM' : 'AM'}';
  if (isSameDay) return time;

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final mon = months[(local.month - 1).clamp(0, 11)];
  return '$mon ${local.day}, ${local.year} - $time';
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

  /// False until first [syncLatestMessages] + read cursor settle; avoids a one-frame "Say hi." flash.
  bool _chatUiReady = false;

  /// Captured once built; used after dispose without touching [ref].
  ProviderContainer? _scopeContainer;

  /// Highest seq we have applied to local/API read state this visit.
  int _lastReadApplied = -1;

  Timer? _readDebounce;
  StreamSubscription<List<Message>>? _latestMsgSub;
  StreamSubscription<bool>? _wsConnSub;
  Timer? _fallbackSyncTimer;

  /// Messenger-style quoted message for the next send (cleared after send).
  Message? _replyingTo;
  bool _showQueuedHintOnce = true;

  Future<void> _jumpOrScrollToLatest() async {
    if (!_scroll.hasClients) return;
    final current = _scroll.offset;
    const animateThresholdPx = 900.0;
    if (current <= animateThresholdPx) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(0);
    }
  }

  final Map<int, GlobalKey> _messageKeys = {};

  GlobalKey _keyForSeq(int seq) => _messageKeys.putIfAbsent(seq, GlobalKey.new);

  Future<void> _scrollToMessageSeq(int targetSeq, List<Message> msgs) async {
    final idx = msgs.indexWhere((m) => m.seq == targetSeq);
    if (idx < 0) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Original message is not loaded. Scroll to load older messages.'),
          ),
        );
      }
      return;
    }

    void ensure() {
      final ctx = _keyForSeq(targetSeq).currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.22,
        );
      }
    }

    ensure();
    final key = _keyForSeq(targetSeq);
    if (key.currentContext != null) return;

    if (!_scroll.hasClients || msgs.length <= 1) return;
    final max = _scroll.position.maxScrollExtent;
    final t = idx / (msgs.length - 1);
    await _scroll.animateTo(
      (t * max).clamp(0.0, max),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    ensure();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scopeContainer ??= ProviderScope.containerOf(context, listen: false);
      _attachLatestMessageSubscription();
    });

    // WebSocket should keep the DB live via SessionNotifier. This fallback prevents
    // "one side didn't update" when a client silently drops WS events on slow/spotty networks.
    Future.microtask(() {
      final ws = ref.read(wsClientProvider);
      void armFallback() {
        _fallbackSyncTimer?.cancel();
        _fallbackSyncTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
          if (!mounted) return;
          if (ref.read(wsClientProvider).isConnected) return;
          try {
            await ref.read(chatRepositoryProvider).syncLatestMessages(
                  conversationId: widget.conversationId,
                );
          } catch (_) {}
        });
      }

      void disarmFallback() {
        _fallbackSyncTimer?.cancel();
        _fallbackSyncTimer = null;
      }

      // Initial state
      if (!ws.isConnected) {
        armFallback();
      }

      _wsConnSub = ws.connection.listen((connected) async {
        if (!mounted) return;
        if (connected) {
          disarmFallback();
          // Catch up immediately after reconnect.
          try {
            await ref.read(chatRepositoryProvider).syncLatestMessages(
                  conversationId: widget.conversationId,
                );
          } catch (_) {}
        } else {
          armFallback();
        }
      });
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
      // Let Drift streams catch up so we don't paint "Say hi." for one frame before rows arrive.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      setState(() => _chatUiReady = true);
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
    _wsConnSub?.cancel();
    _fallbackSyncTimer?.cancel();
    final container = _scopeContainer;
    _scroll.dispose();
    _composer.dispose();
    super.dispose();
    if (container != null) {
      unawaited(_flushReadAfterChatClosed(container, widget.conversationId, widget.selfUserId));
    }
  }

  void _showDemoUnavailable(BuildContext context, {required String title}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('This is not available in the demo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  String _senderShort(bool mine) => mine ? 'You' : widget.title;

  Message? _quotedFor(List<Message> msgs, Message m) {
    final r = m.replyToSeq;
    if (r == null) return null;
    for (final x in msgs) {
      if (x.seq == r) return x;
    }
    return null;
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    final replySeq = _replyingTo?.seq;
    setState(() => _replyingTo = null);
    final outbox = ref.read(outboxServiceProvider);
    await outbox.sendOptimistic(
      conversationId: widget.conversationId,
      body: text,
      replyToSeq: replySeq,
    );
    if (mounted) {
      // Keep the user's focus on the newly sent reply.
      // If they're far away in history, jump; otherwise animate.
      // ignore: unawaited_futures
      _jumpOrScrollToLatest();
    }
    final ws = ref.read(wsClientProvider);
    if (!ws.isConnected && mounted && _showQueuedHintOnce) {
      _showQueuedHintOnce = false;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No connection — message queued and will send when reconnected.')),
      );
    }
  }

  Future<void> _openMessageActions(BuildContext context, Message m, bool mine) async {
    final canDelete = mine && m.body != 'Message deleted';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                m.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  setState(() => _replyingTo = m);
                },
                icon: const Icon(Icons.reply),
                label: const Text('Reply'),
              ),
              if (canDelete) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () {
                    ref.read(wsClientProvider).sendDelete(
                          conversationId: widget.conversationId,
                          seq: m.seq,
                        );
                    Navigator.of(sheetCtx).pop();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = ref.watch(appDatabaseProvider);
    final onSurface = theme.colorScheme.onSurface;
    final session = ref.watch(sessionProvider);
    final me = session.valueOrNull;
    if (me == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FROM: ${widget.title}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call_outlined),
            onPressed: () => _showDemoUnavailable(context, title: 'Calls'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Message>>(
                  stream: (db.select(db.messages)
                        ..where((m) => m.conversationId.equals(widget.conversationId))
                        ..orderBy([(m) => drift.OrderingTerm(expression: m.seq, mode: drift.OrderingMode.desc)]))
                      .watch(),
                  builder: (context, snapMsg) {
                    final msgs = snapMsg.data ?? const [];
                    return StreamBuilder<List<OutboxMessage>>(
                      stream: db.watchOutboxForConversation(widget.conversationId),
                      builder: (context, snapOut) {
                        final outbox = snapOut.data ?? const [];
                        if (msgs.isEmpty && outbox.isEmpty) {
                          if (!_chatUiReady) return const SizedBox.shrink();
                          return const Center(child: Text('Say hi.'));
                        }

                        final items = <Object>[...outbox, ...msgs];
                        items.sort((a, b) {
                          DateTime ta;
                          DateTime tb;
                          if (a is OutboxMessage) {
                            ta = a.createdAt;
                          } else {
                            ta = (a as Message).createdAt;
                          }
                          if (b is OutboxMessage) {
                            tb = b.createdAt;
                          } else {
                            tb = (b as Message).createdAt;
                          }
                          return tb.compareTo(ta);
                        });

                        Widget buildBubble({
                          required Widget child,
                          required bool mine,
                          required Color bubbleBg,
                          required Color fg,
                        }) {
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: bubbleBg,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: IntrinsicWidth(child: child),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final it = items[i];
                            if (it is OutboxMessage) {
                              final mine = true;
                              final bubbleBg = theme.colorScheme.primary;
                              final fg = Colors.black;
                              final subFg = fg.withValues(alpha: 0.58);
                              final status = it.status;
                              final statusText = switch (status) {
                                'sending' => 'Sending…',
                                'queued' => 'Queued',
                                'failed' => 'Failed — tap to retry',
                                _ => status,
                              };
                              return GestureDetector(
                                onTap: status == 'failed'
                                    ? () => ref.read(outboxServiceProvider).retry(it.clientId)
                                    : null,
                                child: buildBubble(
                                  mine: mine,
                                  bubbleBg: bubbleBg,
                                  fg: fg,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it.body,
                                        style: TextStyle(
                                          color: fg,
                                          height: 1.3,
                                          fontSize: 17.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          _formatChatTimestamp(it.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.15,
                                            color: subFg,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            height: 1.15,
                                            color: subFg,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final m = it as Message;
                            final mine = m.senderUserId == widget.selfUserId;
                            final quoted = _quotedFor(msgs, m);
                            final barColor = mine ? theme.colorScheme.tertiary : Colors.white.withValues(alpha: 0.55);
                            final bubbleBg = mine ? theme.colorScheme.primary : const Color(0xFF101018);
                            final fg = mine ? Colors.black : Colors.white;
                            final subFg = fg.withValues(alpha: 0.58);
                            const bodySize = 17.5;
                            final isDeleted = m.body == 'Message deleted';

                            return KeyedSubtree(
                              key: _keyForSeq(m.seq),
                              child: GestureDetector(
                                onTap: () => _openMessageActions(context, m, mine),
                                behavior: HitTestBehavior.deferToChild,
                                child: buildBubble(
                                  mine: mine,
                                  bubbleBg: bubbleBg,
                                  fg: fg,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (quoted != null) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => _scrollToMessageSeq(quoted.seq, msgs),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                                decoration: BoxDecoration(
                                                  color: (mine ? Colors.black : Colors.white).withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border(left: BorderSide(color: barColor, width: 3)),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _senderShort(quoted.senderUserId == widget.selfUserId),
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: fg.withValues(alpha: 0.65),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      quoted.body,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        height: 1.25,
                                                        color: fg.withValues(alpha: 0.8),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (isDeleted)
                                        Text(
                                          'Message deleted',
                                          style: TextStyle(
                                            color: fg,
                                            height: 1.3,
                                            fontSize: bodySize,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        )
                                      else
                                        Linkify(
                                          text: m.body,
                                          style: TextStyle(
                                            color: fg,
                                            height: 1.3,
                                            fontSize: bodySize,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          linkStyle: TextStyle(
                                            color: fg,
                                            fontSize: bodySize,
                                            decoration: TextDecoration.underline,
                                            decorationColor: fg.withValues(alpha: 0.85),
                                          ),
                                          onOpen: (link) async {
                                            final uri = Uri.tryParse(link.url);
                                            if (uri == null) return;
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          },
                                        ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          _formatChatTimestamp(m.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.15,
                                            color: subFg,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingTo != null) ...[
                        Material(
                          elevation: 1,
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Replying to ${_senderShort(_replyingTo!.senderUserId == widget.selfUserId)}',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                              color: onSurface.withValues(alpha: 0.75),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _replyingTo!.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                              color: onSurface.withValues(alpha: 0.85),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Cancel reply',
                                icon: Icon(Icons.close, color: onSurface.withValues(alpha: 0.65)),
                                onPressed: () => setState(() => _replyingTo = null),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Attach',
                            icon: const Icon(Icons.attach_file_outlined),
                            onPressed: () => _showDemoUnavailable(context, title: 'Attachments'),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _composer,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: const InputDecoration(
                                hintText: 'Message…',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          FilledButton(
                            onPressed: _send,
                            child: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!_chatUiReady)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Material(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.40),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
