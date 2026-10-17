// lib/models/conversation.dart
import 'package:threads/core/json.dart';
import 'package:threads/models/profile.dart';

/// One direct-message thread, as shown in the inbox. Matches a row in the
/// `conversations` table with its `conversation_participants` embedded.
class Conversation {
  const Conversation({
    required this.id,
    required this.other,
    required this.lastMessageBody,
    required this.lastMessageAt,
    required this.isUnread,
  });

  final String id;

  /// The other person in the thread.
  final Profile other;

  final String? lastMessageBody;
  final DateTime? lastMessageAt;

  /// True when the newest message is theirs and arrived after my last read.
  final bool isUnread;

  /// Reads a conversations row (participants embedded), or null when the other
  /// person is not in it.
  static Conversation? fromJson(
    Map<String, dynamic> json, {
    required String meId,
  }) {
    final participants = json['participants'];
    if (participants is! List) return null;

    Profile? other;
    DateTime? myLastReadAt;
    for (final entry in participants) {
      if (entry is! Map<String, dynamic>) continue;
      final profile = entry['profile'];
      if (profile is! Map<String, dynamic>) continue;
      if (entry['user_id'] == meId) {
        myLastReadAt = asDate(entry['last_read_at']);
      } else {
        other = Profile.fromJson(profile);
      }
    }
    if (other == null) return null;

    final sentAt = asDate(json['last_message_at']);
    return Conversation(
      id: json['id'] as String,
      other: other,
      lastMessageBody: json['last_message_body'] as String?,
      lastMessageAt: sentAt,
      isUnread:
          sentAt != null &&
          json['last_sender_id'] != meId &&
          (myLastReadAt == null || sentAt.isAfter(myLastReadAt)),
    );
  }
}
