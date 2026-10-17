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
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      body: (json['body'] as String?) ?? '',
      createdAt: asDate(json['created_at'])!,
    );
  }
}
