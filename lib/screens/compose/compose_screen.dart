// lib/screens/compose/compose_screen.dart
import 'dart:io';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:threads/core/config.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/models/community.dart';
import 'package:threads/models/gif_result.dart';
import 'package:threads/models/poll.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/community_providers.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/feed_providers.dart';
import 'package:threads/providers/thread_providers.dart';
import 'package:threads/screens/compose/gif_search_sheet.dart';
import 'package:threads/widgets/quote_card.dart';
/// One screen for four jobs: a new post, a reply, a quote and an edit.
/// It returns the saved post, so the caller can update its card without a reload.
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, this.replyTo, this.quoting, this.editing, this.community});
  final ThreadPost? replyTo; // the post a reply belongs to
  final ThreadPost? quoting; // the post a quote shows inside it
  final ThreadPost? editing; // the post whose text and settings change
  final Community? community; // when posting from inside a community (Step 21.5)
  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}
class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  late final TextEditingController _text;
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  final List<XFile> _media = [];

  /// GIFs chosen from the picker. They are remote URLs, so unlike [_media] they
  /// are not uploaded: their full URL goes straight into media_urls.
  final List<GifResult> _gifs = [];
  ReplyControl _replyControl = ReplyControl.everyone;
  bool _hideLikes = false;
  bool _ghost = false;
  bool _pollOn = false;
  int _pollDays = 1;
  bool _busy = false;

  /// The community this post goes into, or null for a normal post. It starts
  /// from the community the composer was opened from.
  Community? _community;

  bool get _isEditing => widget.editing != null;
  bool get _isReply => widget.replyTo != null;
  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _text = TextEditingController(text: editing?.content ?? '');
    _replyControl = editing?.replyControl ?? ReplyControl.everyone;
    _hideLikes = editing?.hideLikeCount ?? false;
    _community = widget.community;
  }
  @override
  void dispose() {
    _text.dispose();
    for (final controller in _options) {
      controller.dispose();
    }
    super.dispose();
  }
  /// The first problem with the post, or null when it can be saved.
  String? _problem() {
    final text = _text.text.trim();
    final keepsMedia = widget.editing?.mediaUrls.isNotEmpty ?? false;
    if (text.isEmpty && _media.isEmpty && _gifs.isEmpty && !keepsMedia) {
      return 'Write something, or add a photo, video or GIF.';
    }
    if (_pollOn) {
      final choices = [for (final option in _options) option.text.trim()];
      if (choices.any((choice) => choice.isEmpty)) {
        return 'Every poll option needs text.';
      }
      final distinct = choices.map((choice) => choice.toLowerCase()).toSet();
      if (distinct.length != choices.length) {
        return 'Poll options must be different.';
      }
    }
    return null;
  }
  PollDraft? _pollDraft() {
    if (!_pollOn) return null;
    return PollDraft(
      options: [for (final option in _options) option.text.trim()],
      duration: Duration(days: _pollDays),
    );
  }
  Future<void> _post() async {
    if (_busy) return;
    final problem = _problem();
    if (problem != null) {
      await showMessage(context, 'Check your post', problem);
      return;
    }
    setState(() => _busy = true);
    try {
      final threads = ref.read(threadRepositoryProvider);
      final editing = widget.editing;
      if (editing != null) {
        await threads.updateThread(
          editing.id,
          content: _text.text,
          replyControl: _replyControl,
          hideLikeCount: _hideLikes,
        );
        if (mounted) {
          Navigator.of(context).pop(editing.copyWith(
            content: _text.text.trim(),
            replyControl: _replyControl,
            hideLikeCount: _hideLikes,
          ));
        }
        return;
      }
      final uploadedUrls = await _uploadMedia();
      final mediaUrls = [
        ...uploadedUrls,
        for (final gif in _gifs) gif.fullUrl,
      ];
      final mediaKinds = [
        for (var i = 0; i < uploadedUrls.length; i++)
          _isVideo(_media[i].path) ? 'video' : 'image',
        for (var i = 0; i < _gifs.length; i++) 'gif',
      ];
      final created = await threads.createThread(
        content: _text.text,
        mediaUrls: mediaUrls,
        mediaKinds: mediaKinds,
        parentId: widget.replyTo?.id,
        quoteId: widget.quoting?.id,
        communityId: _community?.id,
        replyControl: _replyControl,
        hideLikeCount: _hideLikes,
        expiresAt: _ghost ? DateTime.now().add(const Duration(hours: 24)) : null,
        poll: _pollDraft(),
      );
      _refreshAfterCreate(created);
      if (mounted) Navigator.of(context).pop(created);
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  /// Uploads the photos and videos in order. Returns their public addresses.
  Future<List<String>> _uploadMedia() async {
    if (_media.isEmpty) return const [];
    final userId = ref.read(currentUserIdProvider) ?? '';
    final media = ref.read(mediaRepositoryProvider);
    final urls = <String>[];
    for (var i = 0; i < _media.length; i++) {
      urls.add(await media.uploadThreadMedia(userId, _media[i], i));
    }
    return urls;
  }
  /// Refreshes only the screens that can show the new post.
  void _refreshAfterCreate(ThreadPost created) {
    final authorId = created.author.id;
    ref.invalidate(
      profileTabProvider((authorId, created.isReply ? 'replies' : 'threads')),
    );
    if (created.isReply) {
      ref.invalidate(threadDetailProvider(created.parentId!));
      final root = created.rootId;
      if (root != null) ref.invalidate(threadDetailProvider(root));
    } else if (created.communityId != null) {
      // A community post belongs to that community's feed alone.
      ref.invalidate(communityFeedProvider(created.communityId!));
    } else {
      ref.invalidate(forYouFeedProvider);
      ref.invalidate(followingFeedProvider);
    }
  }
  Future<void> _pickMedia() async {
    final room = maxMediaPerThread - _media.length;
    if (room <= 0) return;
    final picked = await ImagePicker().pickMultipleMedia();
    if (picked.isEmpty || !mounted) return;
    setState(() => _media.addAll(picked.take(room)));
  }
  Future<void> _pickGif() async {
    if (_media.length + _gifs.length >= maxMediaPerThread) return;
    final choice = await openScreen<GifResult>(context, const GifSearchSheet());
    if (choice == null || !mounted) return;
    setState(() => _gifs.add(choice));
  }
  Future<void> _chooseReplyControl() async {
    final choice = await showCupertinoModalPopup<ReplyControl>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Who can reply'),
        actions: [
          for (final control in ReplyControl.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop(control),
              child: Text(control.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (choice != null && mounted) setState(() => _replyControl = choice);
  }
  /// Picks the community the post goes into, or clears it. The list comes from
  /// the communities the signed-in user belongs to.
  Future<void> _chooseCommunity() async {
    final mine = ref.read(myCommunitiesProvider).value ?? const <Community>[];
    final choice = await showCupertinoModalPopup<Community?>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Post to'),
        message: mine.isEmpty
            ? const Text('Join a community first, from the Communities list.')
            : null,
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(null),
            child: const Text('None'),
          ),
          for (final community in mine)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop(community),
              child: Text(community.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(_community),
          child: const Text('Cancel'),
        ),
      ),
    );
    // The sheet's Cancel pops with null, the same as choosing None, so both
    // mean "no community". Only set a value if we picked something (including null).
    if (mounted && choice != null) setState(() => _community = choice);
  }
  static bool _isVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov');
  }
  Widget _mediaStrip() {
    if (_media.isEmpty && _gifs.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _media.length; i++)
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _isVideo(_media[i].path)
                    ? Container(
                        width: 84,
                        height: 84,
                        color: CupertinoColors.systemGrey5,
                        alignment: Alignment.center,
                        child: const Icon(CupertinoIcons.play_circle_fill, size: 34),
                      )
                    : Image.file(
                        File(_media[i].path),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => setState(() => _media.removeAt(i)),
                  child: const Icon(CupertinoIcons.xmark_circle_fill, size: 22),
                ),
              ),
            ],
          ),
        for (var i = 0; i < _gifs.length; i++)
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _gifs[i].previewUrl,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: CupertinoColors.systemGrey5),
                ),
              ),
              const Positioned(
                left: 4,
                bottom: 4,
                child: _GifTag(),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => setState(() => _gifs.removeAt(i)),
                  child: const Icon(CupertinoIcons.xmark_circle_fill, size: 22),
                ),
              ),
            ],
          ),
      ],
    );
  }
  Widget _settingRow({
    required String title,
    required Widget trailing,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
  Widget _pollSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _settingRow(
          title: 'Add a poll',
          trailing: CupertinoSwitch(
            value: _pollOn,
            onChanged: (value) => setState(() => _pollOn = value),
          ),
        ),
        if (_pollOn) ...[
          const SizedBox(height: 8),
          for (var i = 0; i < _options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CupertinoTextField(
                controller: _options[i],
                placeholder: 'Option ${i + 1}',
                maxLength: 60,
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (_options.length < maxPollOptions)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _options.add(TextEditingController())),
              child: const Text('Add an option'),
            ),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: _pollDays,
            children: const {
              1: Text('1 day'),
              3: Text('3 days'),
              7: Text('7 days'),
            },
            onValueChanged: (value) {
              if (value != null) setState(() => _pollDays = value);
            },
          ),
        ],
      ],
    );
  }
  Widget _settings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isReply && !_isEditing)
          _settingRow(
            title: 'Post to',
            subtitle: _community?.name ?? 'Your profile',
            trailing: const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: CupertinoColors.secondaryLabel,
            ),
            onTap: _chooseCommunity,
          ),
        if (!_isReply)
          _settingRow(
            title: 'Who can reply',
            subtitle: _replyControl.label,
            trailing: const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: CupertinoColors.secondaryLabel,
            ),
            onTap: _chooseReplyControl,
          ),
        _settingRow(
          title: 'Hide like count',
          subtitle: 'Only you see how many people liked this.',
          trailing: CupertinoSwitch(
            value: _hideLikes,
            onChanged: (value) => setState(() => _hideLikes = value),
          ),
        ),
        if (!_isReply && !_isEditing)
          _settingRow(
            title: 'Ghost post',
            subtitle: 'Disappears after 24 hours.',
            trailing: CupertinoSwitch(
              value: _ghost,
              onChanged: (value) => setState(() => _ghost = value),
            ),
          ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final replyTo = widget.replyTo;
    final quoting = widget.quoting;
    final title = _isEditing
        ? 'Edit thread'
        : _isReply
            ? 'Reply'
            : quoting != null
                ? 'Quote'
                : 'New thread';
    final buttonLabel = _isEditing ? 'Save' : (_isReply ? 'Reply' : 'Post');
    final problem = _problem();
    final showProblem =
        problem != null && (_text.text.isNotEmpty || _media.isNotEmpty || _pollOn);
    final canPost = !_busy && problem == null;
    final canAddMedia =
        !_isEditing && (_media.length + _gifs.length) < maxMediaPerThread;
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: title),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (replyTo != null) ...[
              Text(
                'Replying to @${replyTo.author.username}',
                style: const TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
              ),
              const SizedBox(height: 8),
            ],
            CupertinoTextField(
              controller: _text,
              placeholder: _isReply ? 'Write your reply' : 'Start a thread',
              minLines: 4,
              maxLines: null,
              maxLength: maxThreadLength,
              autofocus: true,
              padding: const EdgeInsets.all(12),
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_text.text.length}/$maxThreadLength',
                style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
              ),
            ),
            if (quoting != null) ...[
              const SizedBox(height: 8),
              QuoteCard(post: quoting, onTap: () {}),
            ],
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              _mediaStrip(),
            ],
            if (canAddMedia)
              Wrap(
                spacing: 20,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pickMedia,
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.photo_on_rectangle, size: 20),
                        SizedBox(width: 8),
                        Text('Add photos or videos'),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pickGif,
                    child: const Text('Add a GIF'),
                  ),
                ],
              ),
            if (!_isReply && !_isEditing) ...[
              const SizedBox(height: 8),
              _pollSection(),
            ],
            const SizedBox(height: 8),
            _settings(),
            const SizedBox(height: 16),
            if (showProblem)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  problem,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              ),
            CupertinoButton.filled(
              onPressed: canPost ? _post : null,
              child: _busy ? const CupertinoActivityIndicator() : Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small dark GIF label on a chosen GIF's thumbnail.
class _GifTag extends StatelessWidget {
  const _GifTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'GIF',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}
