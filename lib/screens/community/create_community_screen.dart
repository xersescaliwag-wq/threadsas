// lib/screens/community/create_community_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/messages.dart';

import 'package:threads/providers/core_providers.dart';

/// The form for a new community. It returns the created community, which is
/// already joined, because creating one makes you its owner member.
class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() =>
      _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  bool _private = false;
  bool _slugEdited = false;
  bool _busy = false;

  static final _slugPattern = RegExp(r'^[a-z0-9_]{3,30}$');

  @override
  void initState() {
    super.initState();
    // While the slug is untouched it follows the name.
    _name.addListener(_followName);
  }

  @override
  void dispose() {
    _name.removeListener(_followName);
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    super.dispose();
  }

  void _followName() {
    if (_slugEdited) return;
    final slug = _name.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    _slug.text = slug.length > 30 ? slug.substring(0, 30) : slug;
  }

  /// The first problem with the form, or null when it can be saved.
  String? _problem() {
    final name = _name.text.trim();
    final slug = _slug.text.trim().toLowerCase();
    if (name.length < 3)
      return 'Give the community a name of 3 letters or more.';
    if (name.length > 60) return 'Keep the name to 60 letters or fewer.';
    if (!_slugPattern.hasMatch(slug)) {
      return 'The link can use 3 to 30 lowercase letters, numbers or underscores.';
    }
    if (_description.text.trim().length > 300) {
      return 'Keep the description to 300 letters or fewer.';
    }
    return null;
  }

  Future<void> _create() async {
    if (_busy) return;
    final problem = _problem();
    if (problem != null) {
      await showMessage(context, 'Check the community', problem);
      return;
    }
    setState(() => _busy = true);
    try {
      final created = await ref
          .read(communityRepositoryProvider)
          .create(
            name: _name.text,
            slug: _slug.text,
            description: _description.text,
            isPrivate: _private,
          );
      if (mounted) Navigator.of(context).pop(created);
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'New community'),
      body: ResponsiveContent(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                'Name',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 6),
              AdaptiveTextField(
                controller: _name,
                placeholder: 'Photography',
                maxLength: 60,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                'Link',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 6),
              AdaptiveTextField(
                controller: _slug,
                placeholder: 'photography',
                maxLength: 30,
                prefix: Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Text(
                    'threads/',
                    style: TextStyle(color: context.colors.secondaryLabel),
                  ),
                ),
                onChanged: (value) {
                  _slugEdited = value.trim().isNotEmpty;
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 6),
              AdaptiveTextField(
                controller: _description,
                placeholder: 'What is this community about?',
                minLines: 3,
                maxLines: 5,
                maxLength: 300,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Private community',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Only members can see the community and its posts.',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AdaptiveSwitch(
                    value: _private,
                    onChanged: (value) => setState(() => _private = value),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AdaptiveButton.child(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const AppSpinner()
                    : const Text(
                        'Create community',
                        style: TextStyle(
                          color: CupertinoColors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
