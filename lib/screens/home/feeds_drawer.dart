// lib/screens/home/feeds_drawer.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/providers/feed_providers.dart';

/// The side panel opened by Home's ☰ button — the feed switcher.
///
/// It is handed to `AdaptiveScaffold.drawer`, so the panel, its scrim, the
/// slide-in animation and the drag gestures are the platform scaffold's own
/// rather than a hand-rolled overlay.
class FeedsDrawer extends ConsumerWidget {
  const FeedsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedFeedProvider);
    return AppDrawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Feeds',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.separator),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _feedRow(context, ref, 'For you', 0, selected),
                    _divider(context),
                    _feedRow(context, ref, 'Following', 1, selected),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedRow(
    BuildContext context,
    WidgetRef ref,
    String label,
    int value,
    int selected,
  ) {
    final isSelected = value == selected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(selectedFeedProvider.notifier).select(value);
        closeAppDrawer(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                AppIcons.checkmark,
                size: 22,
                color: context.colors.secondaryLabel,
              ),
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) => Container(
    height: 0.5,
    margin: const EdgeInsets.only(left: 16),
    color: context.colors.separator,
  );
}
