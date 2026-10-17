// lib/core/links.dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/models/thread_post.dart';

/// Replace this with your own domain when you have one.
const shareBaseUrl = 'https://threads.example.com';

/// The first https link in a post, or null. Used for link previews (Step 21.4).
/// Trailing sentence punctuation is dropped, because it is rarely part of the
/// address.
String? firstHttpsLink(String text) {
  final match = RegExp(r'https://[^\s]+').firstMatch(text);
  if (match == null) return null;
  var link = match.group(0)!;
  while (link.isNotEmpty && '.,;:!?)]}\'"'.contains(link[link.length - 1])) {
    link = link.substring(0, link.length - 1);
  }
  final uri = Uri.tryParse(link);
  if (uri == null || uri.host.isEmpty) return null;
  return link;
}

String threadLink(ThreadPost post) {
  return '$shareBaseUrl/@${post.author.username}/post/${post.id}';
}

/// Copies the link to the clipboard and confirms it to the person.
Future<void> copyThreadLink(BuildContext context, ThreadPost post) async {
  final link = threadLink(post);
  await Clipboard.setData(ClipboardData(text: link));
  if (context.mounted) {
    await showMessage(context, 'Link copied', link);
  }
}
