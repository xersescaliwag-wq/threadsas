// lib/screens/messages/chat_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/models/message.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/message_providers.dart';

/// A one-to-one chat. Opened from the Message button on a profile, or from a
/// row in the inbox. Either way the conversation id comes from the idempotent
/// `start_conversation` function, so the thread is created on the first call.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.other});

  /// The person on the other side of the thread.
  final Profile other;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  /// The newest message already marked as read, so a rebuild does not repeat the
  /// write but a message that arrives while the chat is open still does.
  String? _markedRead;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Marks the thread read. Best effort: a failure must not disturb the chat.
  Future<void> _markRead(String conversationId, String newestMessageId) async {
    if (_markedRead == newestMessageId) return;
    _markedRead = newestMessageId;
    try {
      await ref.read(messageRepositoryProvider).markRead(conversationId);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      _markedRead = null; // try again on the next load
    }
  }

  Future<void> _send(String conversationId) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    if (text.length > 4000) {
      await showMessage(
        context,
        'Message too long',
        'Messages can be up to 4000 characters.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .send(conversationId: conversationId, body: text);
      _controller.clear();
      ref.invalidate(messagesProvider(conversationId));
      ref.invalidate(conversationsProvider);
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(conversationWithProvider(widget.other.id));
    final conversationId = conversation.value;

    // Realtime: the first event only reports the current state, so reloading on
    // it costs one extra request and nothing else (same approach as thread
    // detail).
    if (conversationId != null) {
      ref.listen(liveMessagesProvider(conversationId), (previous, next) {
        ref.invalidate(messagesProvider(conversationId));
      });
    }

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: widget.other.name),
      body: conversation.when<Widget>(
        loading: () => const Center(child: AppSpinner()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(friendlyError(error), textAlign: TextAlign.center),
          ),
        ),
        data: (id) => Column(
          children: [Expanded(child: _messages(id)), _composer(id)],
        ),
      ),
    );
  }

  Widget _messages(String conversationId) {
    final messages = ref.watch(messagesProvider(conversationId));
    return messages.when<Widget>(
      loading: () => const Center(child: AppSpinner()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(friendlyError(error), textAlign: TextAlign.center),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No messages yet. Say hello to @${widget.other.username}.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.secondaryLabel),
              ),
            ),
          );
        }
        _markReadSoon(conversationId, list.last.id);
        // reverse: true keeps the newest message pinned to the bottom and lets a
        // live message slide in without a manual scroll.
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: list.length,
          itemBuilder: (context, index) => _bubble(list[list.length - 1 - index]),
        );
      },
    );
  }

  /// Moves the read receipt to the newest message. Deferred out of the build so
  /// the provider write inside [_markRead] never runs mid-build; [_markRead]
  /// itself is idempotent per newest message, so rebuilding is harmless.
  void _markReadSoon(String conversationId, String newestMessageId) {
    if (_markedRead == newestMessageId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _markRead(conversationId, newestMessageId);
    });
  }

  Widget _bubble(Message message) {
    final mine = message.senderId == ref.read(currentUserIdProvider);
    final background = mine
        ? context.colors.activeBlue
        : context.colors.systemGrey5;
    final foreground = mine ? context.colors.onActiveBlue : context.colors.label;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.body,
              style: TextStyle(fontSize: 15, color: foreground),
            ),
            const SizedBox(height: 2),
            Text(
              timeAgo(message.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: mine
                    ? foreground.withValues(alpha: 0.75)
                    : context.colors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(String conversationId) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: context.colors.systemBackground,
        border: Border(
          top: BorderSide(color: context.colors.separator, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AdaptiveTextField(
              controller: _controller,
              placeholder: 'Message',
              minLines: 1,
              maxLines: 5,
            ),
          ),
          const SizedBox(width: 8),
          AdaptiveButton.child(
            padding: EdgeInsets.zero,
            onPressed: _busy ? null : () => _send(conversationId),
            child: Icon(AppIcons.paperplane, size: 32),
          ),
        ],
      ),
    ),
  );
}
