// lib/widgets/profile_row.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/screens/profile/profile_screen.dart';
import 'package:threads/widgets/avatar.dart';
/// One person in a list. Tapping opens the profile unless onTap is given.
class ProfileRow extends StatelessWidget {
  const ProfileRow({super.key, required this.profile, this.trailing, this.onTap});
  final Profile profile;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => openScreen<void>(context, ProfileScreen(userId: profile.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Avatar(name: profile.name, url: profile.avatarUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (profile.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: CupertinoColors.activeBlue),
                      ],
                    ],
                  ),
                  Text(
                    '@${profile.username}',
                    style: const TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
                  ),
                  if (profile.bio.isNotEmpty)
                    Text(profile.bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
