// lib/models/profile.dart
import 'package:threads/core/json.dart';

/// One account. Matches a row in the profiles table.
class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
    required this.website,
    required this.isPrivate,
    required this.isVerified,
    required this.followersCount,
    required this.followingCount,
    required this.threadsCount,
  });

  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final String? website;
  final bool isPrivate;
  final bool isVerified;
  final int followersCount;
  final int followingCount;
  final int threadsCount;

  /// The name shown in bold. Falls back to the username when no display name is
  /// set.
  String get name => displayName.trim().isEmpty ? username : displayName;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      bio: (json['bio'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      website: json['website'] as String?,
      isPrivate: (json['is_private'] as bool?) ?? false,
      isVerified: (json['is_verified'] as bool?) ?? false,
      followersCount: asInt(json['followers_count']),
      followingCount: asInt(json['following_count']),
      threadsCount: asInt(json['threads_count']),
    );
  }
}
