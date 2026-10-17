// lib/data/message_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/models/conversation.dart';
import 'package:threads/models/message.dart';

class MessageRepository {
  MessageRepository(this._client);

  final SupabaseClient _client;

  String get _me => _client.auth.currentUser!.id;

  static const _profileColumns =
      'id, username, display_name, bio, website, avatar_url, is_private, '
      'is_verified, followers_count, following_count, threads_count';

  /// The inbox: every conversation I am in, newest first, with the other person
  /// and a copy of the newest message. Conversations with no messages yet are
  /// left out so the list only shows real threads.
  Future<List<Conversation>> conversations({int limit = 60}) async {
    final rows = await _client
        .from('conversations')
        .select(
          'id, last_message_body, last_message_at, last_sender_id, '
          'participants:conversation_participants(user_id, last_read_at, '
          'profile:profiles!conversation_participants_user_id_fkey($_profileColumns))',
        )
        .order('last_message_at', ascending: false, nullsFirst: false)
        .limit(limit);
    final conversations = <Conversation>[];
    for (final row in rows) {
      final conversation = Conversation.fromJson(row, meId: _me);
      if (conversation != null && conversation.lastMessageAt != null) {
        conversations.add(conversation);
      }
    }
    return conversations;
  }

  /// Opens the conversation with [otherId], creating it the first time. The
  /// function is idempotent and returns the same id on every later call, so the
  /// Message button can call it unconditionally.
  Future<String> startConversation(String otherId) async {
    final id = await _client.rpc(
      'start_conversation',
      params: {'p_other': otherId},
    );
    return id as String;
  }

  /// The newest [limit] messages, oldest first - the order the chat shows them.
  Future<List<Message>> messages(String conversationId, {int limit = 200}) async {
    final rows = await _client
        .from('messages')
        .select('id, conversation_id, sender_id, body, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(limit);
    final newestFirst = rows.map((row) => Message.fromJson(row)).toList();
    return newestFirst.reversed.toList();
  }

  Future<void> send({
    required String conversationId,
    required String body,
  }) async {
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _me,
      'body': body.trim(),
    });
  }

  /// Moves my read receipt on this conversation to now.
  Future<void> markRead(String conversationId) async {
    await _client
        .from('conversation_participants')
        .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', _me);
  }

  /// Emits again whenever a message in this conversation arrives. The
  /// conversation id is part of the topic filter, so no other thread's messages
  /// are delivered.
  Stream<List<Map<String, dynamic>>> liveMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .limit(200);
  }

  /// Emits again whenever one of my conversations changes - a new message in
  /// the inbox. Rows are narrowed to mine by the caller.
  Stream<List<Map<String, dynamic>>> liveConversations() {
    return _client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .limit(60);
  }
}
