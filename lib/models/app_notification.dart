// lib/models/app_notification.dart
import 'package:threads/core/json.dart';
import 'package:threads/models/profile.dart';

/// The values match the type column in the notifications table.
enum NotificationType {
  like('like'),
  reply('reply'),
  repost('repost'),
  quote('quote'),
  mention('mention'),
  follow('follow'),
  followRequest('follow_request');

  const NotificationType(this.value);

  final String value;

  static NotificationType fromValue(String value) {
    return NotificationType.values.firstWhere((type) => type.value == value);
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.actor,
    required this.threadId,
    required this.threadPreview,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final NotificationType type;
  final Profile actor;
  final String? threadId;
  final String? threadPreview;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final thread = json['thread'];
    final threadMap = thread is Map<String, dynamic> ? thread : null;
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.fromValue(json['type'] as String),
      actor: Profile.fromJson(json['actor'] as Map<String, dynamic>),
      threadId: threadMap?['id'] as String?,
      threadPreview: threadMap?['content'] as String?,
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: asDate(json['created_at'])!,
    );
  }
}
