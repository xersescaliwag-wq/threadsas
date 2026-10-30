import 'package:flutter/cupertino.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/data/draft_repository.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/screens/compose/compose_screen.dart';

class DraftsScreen extends ConsumerStatefulWidget {
  const DraftsScreen({super.key});
  @override
  ConsumerState<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends ConsumerState<DraftsScreen> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _drafts;
  late final AnimationController _skeletonController;
  DraftRepository get _repository => ref.read(draftRepositoryProvider);
  @override
  void initState() {
    super.initState();
    _drafts = _repository.list();
    _skeletonController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  }
  void _reload() => setState(() => _drafts = _repository.list());
  @override
  void dispose() {
    _skeletonController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: AdaptiveAppBar(title: 'Drafts'),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _drafts,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            itemCount: 9,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, __) => _skeletonRow(),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(AppIcons.exclamationmark_triangle, size: 28, color: context.colors.secondaryLabel),
                const SizedBox(height: 12),
                Text(friendlyError(snapshot.error!), textAlign: TextAlign.center),
                const SizedBox(height: 14),
                AdaptiveButton.child(onPressed: _reload, child: const Text('Try again')),
              ]),
            ),
          );
        }
        final drafts = snapshot.data ?? const [];
        if (drafts.isEmpty) return _emptyState();
        return AppRefreshView(
          onRefresh: () async { _reload(); await _drafts; },
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) => _row(drafts[index]), childCount: drafts.length)),
            ),
          ],
        );
      },
    ),
  );
  Widget _row(Map<String, dynamic> draft) {
    final content = (draft['content'] as String? ?? '').trim();
    final media = (draft['media_urls'] as List?)?.length ?? 0;
    final updated = DateTime.tryParse(draft['updated_at']?.toString() ?? '');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openScreen<void>(context, ComposeScreen(initialContent: content), fullscreen: true),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
        decoration: BoxDecoration(
          color: context.colors.systemBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.separator, width: .5),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.colors.systemGrey5, borderRadius: BorderRadius.circular(10)),
            child: Icon(media > 0 ? AppIcons.photo_on_rectangle : AppIcons.square_pencil, size: 20, color: context.colors.secondaryLabel),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(content.isEmpty ? 'Media draft' : content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            Text(
              media > 0 ? '$media attachment${media == 1 ? '' : 's'}${updated == null ? '' : '  •  ${_dateLabel(updated)}'}' : updated == null ? 'Draft' : 'Draft  •  ${_dateLabel(updated)}',
              style: TextStyle(fontSize: 12, color: context.colors.secondaryLabel),
            ),
          ])),
          AdaptiveButton.child(padding: EdgeInsets.zero, minSize: const Size(34, 34), onPressed: () async { final id = draft['id'] as String?; if (id != null) { await _repository.delete(id); _reload(); } }, child: Icon(AppIcons.xmark_circle_fill, size: 20, color: context.colors.secondaryLabel)),
        ]),
      ),
    );
  }

  Widget _emptyState() => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(AppIcons.square_pencil, size: 38, color: context.colors.secondaryLabel),
    const SizedBox(height: 14),
    const Text('No drafts yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    Text('Save a post while composing and it will appear here.', textAlign: TextAlign.center, style: TextStyle(color: context.colors.secondaryLabel)),
  ])));

  Widget _skeletonRow() => AnimatedBuilder(
        animation: _skeletonController,
        builder: (context, _) {
          final shift = (_skeletonController.value * 2) - 1;
          return Container(
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment(shift - 1, 0),
                end: Alignment(shift + 1, 0),
                colors: [
                  context.colors.systemGrey6,
                  context.colors.systemGrey5,
                  context.colors.systemGrey6,
                ],
              ),
            ),
          );
        },
      );

  String _dateLabel(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
