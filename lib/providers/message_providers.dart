// lib/providers/message_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/models/conversation.dart';
import 'package:threads/models/message.dart';
import 'package:threads/providers/core_providers.dart';

/// The inbox: every conversation the signed-in user is in, newest first.
final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(messageRepositoryProvider).conversations();
});

/// The id of the conversation with one person. Opening a chat from a profile
/// calls the idempotent `start_conversation` function, so this both creates the
/// thread on first use and returns it unchanged afterwards.
final conversationWithProvider = FutureProvider.family<String, String>((
  ref,
  otherId,
) {
  ref.watch(currentUserIdProvider);
  return ref.watch(messageRepositoryProvider).startConversation(otherId);
});

/// One conversation's messages, oldest first.
final messagesProvider = FutureProvider.family<List<Message>, String>((
  ref,
  conversationId,
) {
  ref.watch(currentUserIdProvider);
  return ref.watch(messageRepositoryProvider).messages(conversationId);
});

/// Live changes to one conversation. The chat screen reloads its messages on
/// each event.
final liveMessagesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      conversationId,
    ) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return Stream.empty();
      return ref.watch(messageRepositoryProvider).liveMessages(conversationId);
    });

final liveMessageReactionsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(messageRepositoryProvider).liveReactions();
});

/// Live changes to the inbox. Rows are narrowed to conversations I am in, so a
/// stray event can never add somebody else's thread to the list.
final liveInboxProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.empty();
  return ref
      .watch(messageRepositoryProvider)
      .liveConversations()
      .map(
        (rows) => rows
            .where((row) => row['user_a'] == userId || row['user_b'] == userId)
            .toList(),
      );
});
