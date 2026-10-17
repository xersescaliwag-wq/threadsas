// lib/data/media_repository.dart
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class MediaRepository {
  MediaRepository(this._client);
  final SupabaseClient _client;
  static const _avatarBucket = 'avatars';
  static const _threadBucket = 'thread-media';
  /// Uploads a profile photo and returns its public URL.
  Future<String> uploadAvatar(String userId, XFile file) async {
    final extension = _extension(file.name);
    final path = '$userId/avatar.$extension';
    final bytes = await file.readAsBytes();
    final bucket = _client.storage.from(_avatarBucket);
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(upsert: true, contentType: _mimeType(extension)),
    );
    // The timestamp stops image caches from showing the old photo.
    return '${bucket.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }
  /// Uploads one photo or video for a thread and returns the URL to store in media_urls.
  Future<String> uploadThreadMedia(String userId, XFile file, int index) async {
    final extension = _extension(file.name);
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}_$index.$extension';
    final bytes = await file.readAsBytes();
    final bucket = _client.storage.from(_threadBucket);
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: _mimeType(extension)),
    );
    return bucket.getPublicUrl(path);
  }
  /// Removes every file this user uploaded. Run it before the account is
  /// deleted, because the database cascade does not touch Storage.
  Future<void> deleteAllMine(String userId) async {
    for (final name in const [_avatarBucket, _threadBucket]) {
      final bucket = _client.storage.from(name);
      // A list call returns up to 100 files, so repeat until the folder is
      // empty.
      for (var round = 0; round < 50; round++) {
        final files = await bucket.list(path: userId);
        if (files.isEmpty) break;
        await bucket.remove([for (final file in files) '$userId/${file.name}']);
        if (files.length < 100) break;
      }
    }
  }
  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? 'jpg' : name.substring(dot + 1).toLowerCase();
  }
  String _mimeType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => 'image/jpeg',
    };
  }
}
