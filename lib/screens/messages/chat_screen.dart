// lib/screens/messages/chat_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/services.dart' show TextCapitalization, TextInputAction;
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
import 'package:threads/widgets/avatar.dart';

/// A private one-to-one conversation. Database/RLS policies remain responsible
/// for authorisation; this screen only renders and operates on chat state.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.other});

  final Profile other;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _composerFocus = FocusNode();
  final _reactionBusy = <String>{};
  bool _busy = false;
  bool _hasText = false;
  String? _markedRead;
  Message? _replyingTo;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onComposerChanged);
  }

  void _onComposerChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onComposerChanged)
      ..dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _beginReply(Message message) {
    setState(() => _replyingTo = message);
    // The reply action should leave the person ready to type as soon as the
    // horizontal action menu closes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  Future<void> _markRead(String conversationId, String newestMessageId) async {
    if (_markedRead == newestMessageId) return;
    _markedRead = newestMessageId;
    try {
      await ref.read(messageRepositoryProvider).markRead(conversationId);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      _markedRead = null;
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
          .send(
            conversationId: conversationId,
            body: text,
            replyToId: _replyingTo?.id,
          );
      _controller.clear();
      if (mounted) setState(() => _replyingTo = null);
      ref
        ..invalidate(messagesProvider(conversationId))
        ..invalidate(conversationsProvider);
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

    if (conversationId != null) {
      ref.listen(liveMessagesProvider(conversationId), (_, _) {
        ref.invalidate(messagesProvider(conversationId));
      });
      ref.listen(liveMessageReactionsProvider, (_, _) {
        ref.invalidate(messagesProvider(conversationId));
      });
    }

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        useNativeToolbar: false,
        titleWidget: _headerTitle(),
      ),
      body: ResponsiveContent(
        child: conversation.when<Widget>(
          loading: () => const _ChatSkeleton(),
          error: (error, _) => _errorState(
            friendlyError(error),
            onRetry: () =>
                ref.invalidate(conversationWithProvider(widget.other.id)),
          ),
          data: (id) => Column(
            children: [
              Expanded(child: _messages(id)),
              _composer(id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerTitle() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Avatar(name: widget.other.name, url: widget.other.avatarUrl, size: 32),
      const SizedBox(width: 9),
      Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.other.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              '@${widget.other.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _messages(String conversationId) {
    final messages = ref.watch(messagesProvider(conversationId));
    return messages.when<Widget>(
      loading: () => const _ChatSkeleton(),
      error: (error, _) => _errorState(
        friendlyError(error),
        onRetry: () => ref.invalidate(messagesProvider(conversationId)),
      ),
      data: (list) {
        if (list.isEmpty) return _emptyConversation();
        _markReadSoon(conversationId, list.last.id);
        final byId = {for (final message in list) message.id: message};
        return ListView.builder(
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final listIndex = list.length - 1 - index;
            final message = list[listIndex];
            final older = listIndex > 0 ? list[listIndex - 1] : null;
            final continuation =
                older != null &&
                older.senderId == message.senderId &&
                message.createdAt.difference(older.createdAt).inMinutes < 4;
            final newer = listIndex < list.length - 1
                ? list[listIndex + 1]
                : null;
            return _bubble(
              message,
              replyTo: message.replyToId == null
                  ? null
                  : byId[message.replyToId],
              continuation: continuation,
              showDay:
                  newer == null ||
                  !_sameDay(message.createdAt, newer.createdAt),
            );
          },
        );
      },
    );
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  void _markReadSoon(String conversationId, String newestMessageId) {
    if (_markedRead == newestMessageId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _markRead(conversationId, newestMessageId);
    });
  }

  Widget _bubble(
    Message message, {
    required Message? replyTo,
    required bool continuation,
    required bool showDay,
  }) {
    final mine = message.senderId == ref.read(currentUserIdProvider);
    final background = mine
        ? context.colors.activeBlue
        : context.colors.systemGrey5;
    final foreground = mine
        ? context.colors.onActiveBlue
        : context.colors.label;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(15),
      topRight: const Radius.circular(15),
      bottomLeft: Radius.circular(mine || continuation ? 15 : 6),
      bottomRight: Radius.circular(!mine || continuation ? 15 : 6),
    );
    final maxBubbleWidth = (MediaQuery.sizeOf(context).width * .72)
        .clamp(0.0, 440.0)
        .toDouble();
    return Column(
      children: [
        if (showDay) _dayChip(message.createdAt),
        Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: GestureDetector(
              onLongPress: message.deletedAt == null
                  ? () => _messageActions(message)
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    margin: EdgeInsets.only(
                      top: continuation ? 2 : 10,
                      bottom: message.reactions.isEmpty ? 3 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: BoxConstraints(
                      // Cap the bubble at the app’s reading column so landscape
                      // phones (where 76% of a wide screen still exceeds 600pt)
                      // don’t stretch messages across the whole screen.
                      maxWidth: MediaQuery.sizeOf(context).width * .76 > 480
                          ? 480
                          : MediaQuery.sizeOf(context).width * .76,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: radius,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (replyTo != null) _replyQuote(replyTo, mine),
                        Text(
                          message.deletedAt == null
                              ? message.body
                              : 'Message unsent',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.25,
                            color: foreground,
                            fontStyle: message.deletedAt == null
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                        if (!continuation) ...[
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              timeAgo(message.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: mine
                                    ? foreground.withValues(alpha: .72)
                                    : context.colors.secondaryLabel,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (message.reactions.isNotEmpty) _reactionRow(message),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _replyQuote(Message replyTo, bool mine) {
    final textColor = mine
        ? context.colors.onActiveBlue.withValues(alpha: .78)
        : context.colors.secondaryLabel;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: textColor, width: 2)),
      ),
      child: Text(
        replyTo.deletedAt == null ? replyTo.body : 'Message unsent',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: textColor),
      ),
    );
  }

  Widget _dayChip(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final label = day == today
        ? 'Today'
        : day == yesterday
        ? 'Yesterday'
        : '${date.month}/${date.day}/${date.year}';
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: context.colors.systemGrey6,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.colors.secondaryLabel,
          ),
        ),
      ),
    );
  }

  Widget _reactionRow(Message message) {
    final counts = <String, int>{};
    for (final reaction in message.reactions) {
      counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        children: counts.entries.map((entry) {
          final mine = message.reactions.any(
            (reaction) =>
                reaction.userId == ref.read(currentUserIdProvider) &&
                reaction.emoji == entry.key,
          );
          return GestureDetector(
            onTap: () => _toggleReaction(message, entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: mine
                    ? context.colors.activeBlue.withValues(alpha: .16)
                    : context.colors.systemGrey5,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${entry.key} ${entry.value}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyConversation() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 42),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(
            name: widget.other.name,
            url: widget.other.avatarUrl,
            size: 72,
          ),
          const SizedBox(height: 14),
          Text(
            widget.other.name,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            'Start a private conversation with @${widget.other.username}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.colors.secondaryLabel,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _errorState(String message, {required VoidCallback onRetry}) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 38),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.error_bubble,
            size: 36,
            color: context.colors.secondaryLabel,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.secondaryLabel),
          ),
          const SizedBox(height: 12),
          AdaptiveButton.child(
            style: AdaptiveButtonStyle.plain,
            minSize: const Size(0, 0),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Future<void> _toggleReaction(Message message, String emoji) async {
    final key = '${message.id}:$emoji';
    if (_reactionBusy.contains(key)) return;
    _reactionBusy.add(key);
    try {
      await ref
          .read(messageRepositoryProvider)
          .toggleReaction(messageId: message.id, emoji: emoji);
      ref.invalidate(messagesProvider(message.conversationId));
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      _reactionBusy.remove(key);
    }
  }

  Future<void> _messageActions(Message message) async {
    await showAppModalSheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: context.colors.systemBackground,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _quickReaction(
                          sheetContext,
                          message,
                          '\u{2764}\u{FE0F}',
                        ),
                        _quickReaction(sheetContext, message, '\u{1F602}'),
                        _quickReaction(sheetContext, message, '\u{1F44D}'),
                        _quickReaction(sheetContext, message, '\u{1F62E}'),
                        _quickReaction(sheetContext, message, '\u{1F622}'),
                        Container(
                          width: 1,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: context.colors.separator,
                        ),
                        AdaptiveButton.child(
                          style: AdaptiveButtonStyle.plain,
                          color: context.colors.label,
                          minSize: const Size(46, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _beginReply(message);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                AppIcons.reply,
                                size: 20,
                                color: context.colors.label,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Reply',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.colors.label,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (message.senderId ==
                            ref.read(currentUserIdProvider)) ...[
                          Container(
                            width: 1,
                            height: 34,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            color: context.colors.separator,
                          ),
                          AdaptiveButton.child(
                            style: AdaptiveButtonStyle.plain,
                            color: context.colors.systemRed,
                            minSize: const Size(46, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _confirmUnsend(message);
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  AppIcons.undo,
                                  size: 20,
                                  color: context.colors.systemRed,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Unsend',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.colors.systemRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        AdaptiveButton.child(
                          style: AdaptiveButtonStyle.plain,
                          color: context.colors.secondaryLabel,
                          minSize: const Size(36, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Icon(
                            AppIcons.xmark,
                            size: 18,
                            color: context.colors.secondaryLabel,
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
    );
  }

  Widget _quickReaction(
    BuildContext sheetContext,
    Message message,
    String emoji,
  ) => AdaptiveButton.child(
    style: AdaptiveButtonStyle.plain,
    minSize: const Size(36, 44),
    padding: const EdgeInsets.symmetric(horizontal: 7),
    onPressed: () {
      Navigator.pop(sheetContext);
      _toggleReaction(message, emoji);
    },
    child: Text(emoji, style: const TextStyle(fontSize: 24)),
  );

  Future<void> _confirmUnsend(Message message) async {
    final confirmed = await confirm(
      context,
      title: 'Unsend message?',
      message: 'This message will be removed for everyone in the chat.',
      actionLabel: 'Unsend',
      destructive: true,
    );
    if (confirmed != true) return;
    try {
      await ref.read(messageRepositoryProvider).unsend(message.id);
      ref.invalidate(messagesProvider(message.conversationId));
    } catch (error) {
      if (mounted) await showError(context, error);
    }
  }

  Widget _composer(String conversationId) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: context.colors.systemBackground,
        border: Border(
          top: BorderSide(color: context.colors.separator, width: .5),
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null) _replyComposerBar(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 46),
                    decoration: BoxDecoration(
                      color: context.colors.systemGrey6,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: AdaptiveTextField(
                      controller: _controller,
                      focusNode: _composerFocus,
                      placeholder: _replyingTo == null ? 'Message' : 'Reply',
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) {
                        _send(conversationId);
                      },
                      padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                      cupertinoDecoration: const BoxDecoration(),
                      decoration: borderlessInputDecoration(
                        hintText: _replyingTo == null ? 'Message' : 'Reply',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _hasText && !_busy
                        ? context.colors.activeBlue
                        : context.colors.systemGrey5,
                    shape: BoxShape.circle,
                  ),
                  child: AppIconButton(
                    padding: EdgeInsets.zero,
                    minSize: const Size(46, 46),
                    onPressed: !_hasText || _busy
                        ? null
                        : () => _send(conversationId),
                    icon: AppIcons.paperplane,
                    size: 20,
                    color: _hasText && !_busy
                        ? context.colors.onActiveBlue
                        : context.colors.secondaryLabel,
                    semanticLabel: 'Send reply',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _replyComposerBar() {
    final message = _replyingTo!;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
      decoration: BoxDecoration(
        color: context.colors.systemGrey6,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.separator, width: .5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Replying to ${message.senderId == ref.read(currentUserIdProvider) ? 'yourself' : widget.other.name}: ${message.deletedAt == null ? message.body : 'Message unsent'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.secondaryLabel,
              ),
            ),
          ),
          AppIconButton(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minSize: const Size(34, 30),
            onPressed: () => setState(() => _replyingTo = null),
            icon: AppIcons.xmark,
            size: 16,
            color: context.colors.secondaryLabel,
            semanticLabel: 'Cancel reply',
          ),
        ],
      ),
    );
  }
}

class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = context.colors.systemGrey6;
    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        _block(.42, color, Alignment.centerRight),
        _block(.66, color, Alignment.centerLeft),
        _block(.52, color, Alignment.centerLeft),
        _block(.36, color, Alignment.centerRight),
        _block(.58, color, Alignment.centerLeft),
      ],
    );
  }

  Widget _block(double widthFactor, Color color, Alignment alignment) => Align(
    alignment: alignment,
    child: FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 44,
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    ),
  );
}
