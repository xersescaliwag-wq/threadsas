import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/widgets/avatar.dart';

/// A quoted post shown inside another post. Tapping it opens the quoted thread.
class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, required this.post, required this.onTap});
  final ThreadPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.separator),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(name: post.author.name, url: post.author.avatarUrl, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    post.author.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '@${post.author.username}',
                  style: TextStyle(fontSize: 14, color: context.colors.secondaryLabel),
                ),
              ],
            ),
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                post.content,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
