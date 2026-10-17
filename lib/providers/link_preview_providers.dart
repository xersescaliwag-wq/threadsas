// lib/providers/link_preview_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/models/link_preview.dart';
import 'package:threads/providers/core_providers.dart';

/// The preview for one URL. The server reads each page once and caches it in
/// public.link_previews, and Riverpod keeps the result for the session, so
/// watching this from every card is cheap. A URL with no preview resolves to
/// null.
final linkPreviewProvider = FutureProvider.family<LinkPreview?, String>(
  (ref, url) => ref.watch(linkPreviewRepositoryProvider).fetch(url),
);
