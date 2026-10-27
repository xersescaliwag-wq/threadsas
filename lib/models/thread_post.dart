// lib/models/thread_post.dart
import 'package:threads/core/json.dart';
import 'package:threads/models/music_track.dart';
import 'package:threads/models/poll.dart';
import 'package:threads/models/profile.dart';

/// Who may reply to a thread. The value matches the reply_control column.
enum ReplyControl {
  everyone('everyone', 'Everyone'),
  following('following', 'Profiles you follow'),
  mentioned('mentioned', 'Profiles you mention');

  const ReplyControl(this.value, this.label);

  final String value;
  final String label;

  static ReplyControl fromValue(String? value) {
    return ReplyControl.values.firstWhere(
      (control) => control.value == value,
      orElse: () => ReplyControl.everyone,
    );
  }
}

/// A thread, reply or quote post, with its author, quoted post and poll joined
/// in.
class ThreadPost {
  const ThreadPost({
    required this.id,
    required this.author,
    required this.content,
    required this.mediaUrls,
    required this.mediaKinds,
    required this.music,
    required this.parentId,
    required this.rootId,
    required this.communityId,
    required this.quoted,
    required this.hashtags,
    required this.mentions,
    required this.replyControl,
    required this.hideLikeCount,
    required this.isPinned,
    required this.expiresAt,
    required this.likeCount,
    required this.replyCount,
    required this.repostCount,
    required this.quoteCount,
    required this.createdAt,
    required this.editedAt,
    required this.poll,
    required this.likedByMe,
    required this.repostedByMe,
  });

  final String id;
  final Profile author;
  final String content;
  final List<String> mediaUrls;

  /// Runs alongside [mediaUrls]: each entry is 'image', 'video' or 'gif'
  /// (Step 21.3). Older posts have none, so [mediaKindAt] falls back to the
  /// file extension.
  final List<String> mediaKinds;
  final MusicTrack? music;
  final String? parentId;
  final String? rootId;

  /// The community this post belongs to, or null for a normal post (Step 21.5).
  /// A community post appears only in that community's feed.
  final String? communityId;
  final ThreadPost? quoted;
  final List<String> hashtags;
  final List<String> mentions;
  final ReplyControl replyControl;
  final bool hideLikeCount;
  final bool isPinned;
  final DateTime? expiresAt;
  final int likeCount;
  final int replyCount;
  final int repostCount;
  final int quoteCount;
  final DateTime createdAt;
  final DateTime? editedAt;
  final Poll? poll;
  final bool likedByMe;
  final bool repostedByMe;

  bool get isReply => parentId != null;
  bool get isGhost => expiresAt != null;

  /// Whether item [index] of [mediaUrls] is an image, video or GIF. Stored
  /// kinds win; otherwise the URL decides, so posts made before Step 21.3 still
  /// draw correctly.
  String mediaKindAt(int index) {
    if (index >= 0 &&
        index < mediaKinds.length &&
        mediaKinds[index].isNotEmpty) {
      return mediaKinds[index];
    }
    if (index < 0 || index >= mediaUrls.length) return 'image';
    final path = mediaUrls[index].toLowerCase().split('?').first;
    if (path.endsWith('.mp4') || path.endsWith('.mov')) return 'video';
    if (path.endsWith('.gif')) return 'gif';
    return 'image';
  }

  factory ThreadPost.fromJson(
    Map<String, dynamic> json, {
    bool likedByMe = false,
    bool repostedByMe = false,
  }) {
    final quotedJson = json['quoted'];
    return ThreadPost(
      id: json['id'] as String,
      author: Profile.fromJson(json['author'] as Map<String, dynamic>),
      content: (json['content'] as String?) ?? '',
      mediaUrls: asStringList(json['media_urls']),
      mediaKinds: asStringList(json['media_kinds']),
      music: MusicTrack.fromThreadJson(json),
      parentId: json['parent_id'] as String?,
      rootId: json['root_id'] as String?,
      communityId: json['community_id'] as String?,
      quoted: quotedJson is Map<String, dynamic>
          ? ThreadPost.fromJson(quotedJson)
          : null,
      hashtags: asStringList(json['hashtags']),
      mentions: asStringList(json['mentions']),
      replyControl: ReplyControl.fromValue(json['reply_control'] as String?),
      hideLikeCount: (json['hide_like_count'] as bool?) ?? false,
      isPinned: (json['is_pinned'] as bool?) ?? false,
      expiresAt: asDate(json['expires_at']),
      likeCount: asInt(json['like_count']),
      replyCount: asInt(json['reply_count']),
      repostCount: asInt(json['repost_count']),
      quoteCount: asInt(json['quote_count']),
      createdAt: asDate(json['created_at'])!,
      editedAt: asDate(json['edited_at']),
      poll: _parsePoll(json),
      likedByMe: likedByMe,
      repostedByMe: repostedByMe,
    );
  }

  /// PostgREST returns a one-to-one join as an object or a list, so both shapes
  /// are handled.
  static Poll? _parsePoll(Map<String, dynamic> json) {
    final pollData = json['poll'];
    final pollMap = pollData is List
        ? (pollData.isEmpty ? null : pollData.first)
        : pollData;
    if (pollMap is! Map<String, dynamic>) return null;
    final rawOptions = json['poll_options'];
    final options = rawOptions is List
        ? rawOptions
              .map(
                (option) => PollOption.fromJson(option as Map<String, dynamic>),
              )
              .toList()
        : <PollOption>[];
    options.sort((a, b) => a.position.compareTo(b.position));
    return Poll(endsAt: asDate(pollMap['ends_at'])!, options: options);
  }

  /// Returns a copy with some fields changed. Used for optimistic updates
  /// before the server confirms.
  ThreadPost copyWith({
    String? content,
    ReplyControl? replyControl,
    bool? hideLikeCount,
    bool? isPinned,
    int? likeCount,
    bool? likedByMe,
    int? repostCount,
    bool? repostedByMe,
    int? replyCount,
    Poll? poll,
  }) {
    return ThreadPost(
      id: id,
      author: author,
      content: content ?? this.content,
      mediaUrls: mediaUrls,
      mediaKinds: mediaKinds,
      music: music,
      parentId: parentId,
      rootId: rootId,
      communityId: communityId,
      quoted: quoted,
      hashtags: hashtags,
      mentions: mentions,
      replyControl: replyControl ?? this.replyControl,
      hideLikeCount: hideLikeCount ?? this.hideLikeCount,
      isPinned: isPinned ?? this.isPinned,
      expiresAt: expiresAt,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      repostCount: repostCount ?? this.repostCount,
      quoteCount: quoteCount,
      createdAt: createdAt,
      editedAt: content == null ? editedAt : DateTime.now(),
      poll: poll ?? this.poll,
      likedByMe: likedByMe ?? this.likedByMe,
      repostedByMe: repostedByMe ?? this.repostedByMe,
    );
  }
}

/// A thread opened on its own page: the post, the posts above it, and every
/// reply under it.
class ThreadDetail {
  const ThreadDetail({
    required this.focus,
    required this.ancestors,
    required this.replies,
  });

  final ThreadPost focus;
  final List<ThreadPost> ancestors; // the top of the conversation first
  final List<ThreadPost> replies; // every reply under the focused post,
  // oldest first
}
