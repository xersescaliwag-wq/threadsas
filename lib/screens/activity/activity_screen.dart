// lib/screens/activity/activity_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/models/app_notification.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/notification_providers.dart';
import 'package:threads/providers/social_providers.dart';
import 'package:threads/screens/profile/follow_requests_screen.dart';
import 'package:threads/screens/profile/profile_screen.dart';
import 'package:threads/screens/thread/thread_detail_screen.dart';
import 'package:threads/widgets/avatar.dart';
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key, this.isVisible = false});
  /// True while the Activity tab is the selected tab. The shell passes it.
  final bool isVisible;
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}
class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  /// Rows that were unread when the person opened the tab. They keep their
  /// highlight until the person leaves the tab.
  final Set<String> _fresh = {};
  @override
  void didUpdateWidget(ActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _markRead(ref.read(activityProvider).value ?? const []);
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _fresh.clear();
    }
  }
  /// Remembers which rows are new, then marks every row read in the database.
  void _markRead(List<AppNotification> items) {
    final unread = items.where((item) => !item.isRead).toList();
    if (unread.isEmpty) return;
    _fresh.addAll(unread.map((item) => item.id));
    _saveRead();
  }
  Future<void> _saveRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      ref.invalidate(unreadCountProvider);
    } catch (_) {
      // The badge corrects itself on the next realtime event.
    }
  }
  Future<void> _refresh() async {
    ref.invalidate(followRequestsProvider);
    ref.invalidate(activityProvider);
    await ref.read(activityProvider.future);
  }
  void _open(AppNotification item) {
    switch (item.type) {
      case NotificationType.follow:
        openScreen<void>(context, ProfileScreen(userId: item.actor.id));
      case NotificationType.followRequest:
        openScreen<void>(context, const FollowRequestsScreen());
      default:
        final threadId = item.threadId;
        if (threadId != null) {
          openScreen<void>(context, ThreadDetailScreen(threadId: threadId));
        }
    }
  }
  String _verb(NotificationType type) => switch (type) {
        NotificationType.like => 'liked your thread',
        NotificationType.reply => 'replied to your thread',
        NotificationType.repost => 'reposted your thread',
        NotificationType.quote => 'quoted your thread',
        NotificationType.mention => 'mentioned you',
        NotificationType.follow => 'started following you',
        NotificationType.followRequest => 'asked to follow you',
      };
  IconData _icon(NotificationType type) => switch (type) {
        NotificationType.like => AppIcons.heart_fill,
        NotificationType.reply => AppIcons.chat_bubble_fill,
        NotificationType.repost => AppIcons.arrow_2_squarepath,
        NotificationType.quote => AppIcons.quote_bubble_fill,
        NotificationType.mention => AppIcons.at,
        NotificationType.follow => AppIcons.person_fill,
        NotificationType.followRequest => AppIcons.person_badge_plus_fill,
      };
  Color _color(BuildContext context, NotificationType type) =>
      switch (type) {
        NotificationType.like => context.colors.systemRed,
        NotificationType.reply => context.colors.systemBlue,
        NotificationType.repost => context.colors.systemGreen,
        NotificationType.quote => context.colors.systemPurple,
        NotificationType.mention => context.colors.systemOrange,
        NotificationType.follow || NotificationType.followRequest => context.colors.systemIndigo,
      };
  @override
  Widget build(BuildContext context) {
    // A realtime event reloads the list. If the tab is open, the new rows are
    // marked read straight away.
    ref.listen(activityProvider, (previous, next) {
      ref.invalidate(followRequestsProvider);
      if (next.isLoading || !widget.isVisible) return;
      final items = next.value;
      if (items != null) setState(() => _markRead(items));
    });
    final activity = ref.watch(activityProvider);
    final requests = ref.watch(followRequestsProvider).value ?? const <Profile>[];
    // skipLoadingOnReload keeps the rows on screen while a realtime reload runs.
    return activity.when<Widget>(
      skipLoadingOnReload: true,
      loading: () => const Center(child: AppSpinner()),
      error: (error, _) => Center(child: Text(friendlyError(error))),
      data: (items) => AppRefreshView(
        onRefresh: _refresh,
        slivers: [
          if (requests.isNotEmpty) SliverToBoxAdapter(child: _requestsRow(requests.length)),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No activity yet.', style: TextStyle(color: context.colors.secondaryLabel)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Column(
                  children: [
                    _row(items[index]),
                    Container(height: 0.5, margin: const EdgeInsets.only(left: 74), color: context.colors.separator),
                  ],
                ),
                childCount: items.length,
              ),
            ),
        ],
      ),
    );
  }
  Widget _requestsRow(int count) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openScreen<void>(context, const FollowRequestsScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.separator, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(AppIcons.person_2_fill, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Follow requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Text('$count', style: TextStyle(color: context.colors.secondaryLabel)),
            const SizedBox(width: 6),
            Icon(AppIcons.chevron_forward, size: 16, color: context.colors.secondaryLabel),
          ],
        ),
      ),
    );
  }
  Widget _badge(NotificationType type) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: _color(context, type),
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.systemBackground, width: 2),
      ),
      child: Icon(_icon(type), size: 11, color: context.colors.white),
    );
  }
  Widget _row(AppNotification item) {
    final isFresh = _fresh.contains(item.id);
    final preview = item.threadPreview;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(item),
      child: Container(
        color: isFresh ? context.colors.systemGrey6 : null,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(name: item.actor.name, url: item.actor.avatarUrl, size: 44),
                Positioned(right: -4, bottom: -4, child: _badge(item.type)),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.actor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeAgo(item.createdAt),
                        style: TextStyle(fontSize: 14, color: context.colors.secondaryLabel),
                      ),
                    ],
                  ),
                  Text(_verb(item.type), style: const TextStyle(fontSize: 15)),
                  if (preview != null && preview.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: context.colors.secondaryLabel),
                      ),
                    ),
                ],
              ),
            ),
            if (isFresh)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 6),
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: context.colors.activeBlue, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
