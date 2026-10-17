// lib/models/community.dart
import 'package:threads/core/json.dart';

/// A group that people join. Matches a row in the communities table.
class Community {
  const Community({
    required this.id,
    required this.ownerId,
    required this.slug,
    required this.name,
    required this.description,
    required this.isPrivate,
    required this.memberCount,
    required this.createdAt,
    required this.joinedByMe,
  });

  final String id;
  final String ownerId;
  final String slug;
  final String name;
  final String description;
  final bool isPrivate;
  final int memberCount;
  final DateTime createdAt;

  /// Whether the signed-in user belongs to this community. It is not a column:
  /// the repository fills it in from the community_members table.
  final bool joinedByMe;

  factory Community.fromJson(
    Map<String, dynamic> json, {
    bool joinedByMe = false,
  }) {
    return Community(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      isPrivate: (json['is_private'] as bool?) ?? false,
      memberCount: asInt(json['member_count']),
      createdAt: asDate(json['created_at'])!,
      joinedByMe: joinedByMe,
    );
  }

  /// Returns a copy with some fields changed, for optimistic updates.
  Community copyWith({
    bool? joinedByMe,
    int? memberCount,
    bool? isPrivate,
    String? name,
    String? description,
  }) {
    return Community(
      id: id,
      ownerId: ownerId,
      slug: slug,
      name: name ?? this.name,
      description: description ?? this.description,
      isPrivate: isPrivate ?? this.isPrivate,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt,
      joinedByMe: joinedByMe ?? this.joinedByMe,
    );
  }
}
