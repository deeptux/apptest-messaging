import 'package:apptest_messaging/core/providers.dart';
import 'package:apptest_messaging/features/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key, required this.selfUserId});

  final String selfUserId;

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref.read(chatApiProvider).searchContacts(_controller.text);
      setState(() => _results = rows);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New chat')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Email or display name or @handle',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final u = _results[i];
                  final email = u['email'] as String?;
                  final name = u['displayName'] as String?;
                  final handle = u['anonymousUsername'] as String?;
                  final userId = u['userId'] as String;
                  final subtitleParts = <String>[];
                  if (email != null && email.isNotEmpty) subtitleParts.add(email);
                  if (handle != null && handle.isNotEmpty) {
                    subtitleParts.add('@$handle');
                  }
                  final title = () {
                    if (name != null && name.isNotEmpty) return name;
                    if (email != null && email.isNotEmpty) return email;
                    if (handle != null && handle.isNotEmpty) return '@$handle';
                    return 'Unknown';
                  }();
                  final subtitleTxt = subtitleParts.join(' · ');
                  return Card(
                    child: ListTile(
                      title: Text(title),
                      subtitle:
                          subtitleTxt.isEmpty ? const SizedBox.shrink() : Text(subtitleTxt),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final convId =
                            await ref.read(chatRepositoryProvider).openOrCreateDirect(otherUserId: userId);
                        await ref.read(chatRepositoryProvider).syncInbox(selfUserId: widget.selfUserId);
                        if (!context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: convId,
                              title: name ?? email ?? 'Chat',
                              selfUserId: widget.selfUserId,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

