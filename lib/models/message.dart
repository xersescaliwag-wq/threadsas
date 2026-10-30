// lib/models/message.dart
import 'package:threads/core/json.dart';

/// One message in a conversation. Matches a row in the messages table.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.replyToId,
    this.reactions = const [],
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? replyToId;
  final List<MessageReaction> reactions;

  factory Message.fromJson(
    Map<String, dynamic> json, {
    List<MessageReaction> reactions = const [],
  }) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      body: (json['body'] as String?) ?? '',
      createdAt: asDate(json['created_at'])!,
      editedAt: asDate(json['edited_at']),
      deletedAt: asDate(json['deleted_at']),
      replyToId: json['reply_to_id'] as String?,
      reactions: reactions,
    );
  }
}

class MessageReaction {
  const MessageReaction({required this.userId, required this.emoji});

  final String userId;
  final String emoji;

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      userId: json['user_id'] as String,
      emoji: json['emoji'] as String,
    );
  }
}
