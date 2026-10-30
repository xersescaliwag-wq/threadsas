import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/providers/core_providers.dart';

class FeedPreferencesScreen extends ConsumerStatefulWidget {
  const FeedPreferencesScreen({super.key});
  @override
  ConsumerState<FeedPreferencesScreen> createState() => _FeedPreferencesScreenState();
}

class _FeedPreferencesScreenState extends ConsumerState<FeedPreferencesScreen> {
  final _interest = TextEditingController();
  final _muted = TextEditingController();
  late Future<(List<String>, List<String>)> _data;
  @override
  void initState() { super.initState(); _data = _load(); }
  Future<(List<String>, List<String>)> _load() async => (
    await ref.read(personalizationRepositoryProvider).interests(),
    await ref.read(personalizationRepositoryProvider).mutedTopics(),
  );
  void _reload() => setState(() => _data = _load());
  Future<void> _toggle(String topic, bool interest, bool enabled) async {
    try {
      if (interest) await ref.read(personalizationRepositoryProvider).setInterest(topic, enabled);
      else await ref.read(personalizationRepositoryProvider).setMutedTopic(topic, enabled);
      _reload();
    } catch (error) { if (mounted) await showError(context, error); }
  }
  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: AdaptiveAppBar(title: 'Feed preferences'),
    body: FutureBuilder<(List<String>, List<String>)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: AppSpinner());
        if (snapshot.hasError) return Center(child: Text(friendlyError(snapshot.error!)));
        final interests = snapshot.data!.$1;
        final muted = snapshot.data!.$2;
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Interests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Tell us what you want more of in For You.', style: TextStyle(color: context.colors.secondaryLabel)),
          _addField(_interest, 'Add an interest', true),
          _chips(interests, true),
          const SizedBox(height: 28),
          const Text('Muted topics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Posts containing these topics will be deprioritized.', style: TextStyle(color: context.colors.secondaryLabel)),
          _addField(_muted, 'Mute a topic', false),
          _chips(muted, false),
        ]);
      },
    ),
  );
  Widget _addField(TextEditingController controller, String placeholder, bool interest) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(children: [
      Expanded(child: AdaptiveTextField(controller: controller, placeholder: placeholder, onSubmitted: (value) { _toggle(value, interest, true); controller.clear(); })),
      AdaptiveButton.child(padding: EdgeInsets.zero, minSize: const Size(44, 44), onPressed: () { _toggle(controller.text, interest, true); controller.clear(); }, child: const Text('Add')),
    ]),
  );
  Widget _chips(List<String> values, bool interest) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(spacing: 8, runSpacing: 8, children: [for (final value in values) GestureDetector(
      onTap: () => _toggle(value, interest, false),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8), decoration: BoxDecoration(color: context.colors.systemGrey6, borderRadius: BorderRadius.circular(18)), child: Text('#$value  ×')),
    )]),
  );
}
