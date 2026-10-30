import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/providers/core_providers.dart';

class ScheduledPostsScreen extends ConsumerStatefulWidget {
  const ScheduledPostsScreen({super.key});
  @override
  ConsumerState<ScheduledPostsScreen> createState() => _ScheduledPostsScreenState();
}

class _ScheduledPostsScreenState extends ConsumerState<ScheduledPostsScreen> {
  late Future<List<Map<String, dynamic>>> _items;
  @override
  void initState() { super.initState(); _items = ref.read(scheduledPostRepositoryProvider).list(); }
  void _reload() => setState(() => _items = ref.read(scheduledPostRepositoryProvider).list());
  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: AdaptiveAppBar(title: 'Scheduled'),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: AppSpinner());
        if (snapshot.hasError) return Center(child: Text(friendlyError(snapshot.error!)));
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) return Center(child: Text('Scheduled posts will appear here.', style: TextStyle(color: context.colors.secondaryLabel)));
        return AppRefreshView(
          onRefresh: () async { _reload(); await _items; },
          slivers: [SliverList(delegate: SliverChildBuilderDelegate((context, index) => _row(rows[index]), childCount: rows.length))],
        );
      },
    ),
  );
  Widget _row(Map<String, dynamic> row) {
    final when = DateTime.tryParse(row['scheduled_for']?.toString() ?? '')?.toLocal();
    final status = row['status']?.toString() ?? 'scheduled';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row['content']?.toString().trim().isEmpty == true ? 'Media post' : row['content']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text('${when ?? ''} · $status', style: TextStyle(fontSize: 13, color: context.colors.secondaryLabel)),
        ])),
        if (status == 'scheduled') AdaptiveButton.child(
          padding: EdgeInsets.zero,
          minSize: const Size(36, 36),
          onPressed: () async { await ref.read(scheduledPostRepositoryProvider).cancel(row['id'].toString()); _reload(); },
          child: Icon(AppIcons.xmark_circle_fill, color: context.colors.systemRed),
        ),
      ]),
    );
  }
}
