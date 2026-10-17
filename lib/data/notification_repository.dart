// lib/data/notification_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/models/app_notification.dart';
class NotificationRepository {
  NotificationRepository(this._client);
  final SupabaseClient _client;
  String get _me => _client.auth.currentUser!.id;
  Future<List<AppNotification>> list({int limit = 60}) async {
    final rows = await _client
        .from('notifications')
        .select(
          'id, type, is_read, created_at, '
          'actor:profiles!notifications_actor_id_fkey(id, username, display_name, avatar_url, is_private, is_verified), '
          'thread:threads!notifications_thread_id_fkey(id, content)',
        )
        .eq('recipient_id', _me)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((row) => AppNotification.fromJson(row)).toList();
  }
  /// Counts unread rows, capped at 100. The badge shows 99+ anyway.
  Future<int> unreadCount() async {
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('recipient_id', _me)
        .eq('is_read', false)
        .limit(100);
    return rows.length;
  }
  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', _me)
        .eq('is_read', false);
  }
  /// Emits the rows again whenever one of them changes.
  Stream<List<Map<String, dynamic>>> liveChanges() {
    return _client.from('notifications').stream(primaryKey: ['id']).eq('recipient_id', _me);
  }
}
