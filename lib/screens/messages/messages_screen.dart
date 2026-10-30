// lib/screens/messages/messages_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/models/conversation.dart';
import 'package:threads/providers/message_providers.dart';
import 'package:threads/screens/messages/chat_screen.dart';
import 'package:threads/widgets/avatar.dart';

/// The inbox: every conversation the signed-in user is in, newest first. Tapping
/// a row opens the chat. A new message anywhere refreshes the list.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // A new message in any of my threads updates the inbox.
    ref.listen(
      liveInboxProvider,
      (previous, next) => ref.invalidate(conversationsProvider),
    );
    final conversations = ref.watch(conversationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: AppSearchField(
            placeholder: 'Search',
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: conversations.when<Widget>(
            loading: () => const Center(child: AppSpinner()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(friendlyError(error), textAlign: TextAlign.center),
              ),
            ),
            data: (list) {
              final shown = list.where(_matches).toList();
              if (shown.isEmpty) return _empty(list.isEmpty);
              return AppRefreshView(
                onRefresh: () async {
                  ref.invalidate(conversationsProvider);
                  await ref.read(conversationsProvider.future);
                },
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _row(shown[index]),
                      childCount: shown.length,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  bool _matches(Conversation conversation) {
    if (_query.isEmpty) return true;
    return conversation.other.name.toLowerCase().contains(_query) ||
        conversation.other.username.toLowerCase().contains(_query);
  }

  Widget _row(Conversation conversation) {
    final preview = conversation.lastMessageBody ?? '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          openScreen<void>(context, ChatScreen(other: conversation.other)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Avatar(
              name: conversation.other.name,
              url: conversation.other.avatarUrl,
              size: 52,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.other.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: conversation.isUnread
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.colors.secondaryLabel,
                      fontWeight: conversation.isUnread
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  conversation.lastMessageAt == null
                      ? ''
                      : timeAgo(conversation.lastMessageAt!),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 6),
                if (conversation.isUnread)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: context.colors.activeBlue,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 9),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(bool noMessages) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: context.colors.systemGrey6,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.chat_bubble,
                size: 38,
                color: context.colors.label,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              noMessages ? 'Never miss a message' : 'No threads found',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              noMessages
                  ? 'Open a profile and tap Message to start a conversation.'
                  : 'Try a different name or username.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.colors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
