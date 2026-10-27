// lib/screens/compose/compose_screen.dart
import 'dart:io';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/config.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/data/instagram_repository.dart';
import 'package:threads/models/community.dart';
import 'package:threads/models/gif_result.dart';
import 'package:threads/models/music_track.dart';
import 'package:threads/models/poll.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/community_providers.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/feed_providers.dart';
import 'package:threads/providers/instagram_providers.dart';
import 'package:threads/providers/thread_providers.dart';
import 'package:threads/screens/compose/gif_search_sheet.dart';
import 'package:threads/screens/compose/music_search_screen.dart';
import 'package:threads/widgets/avatar.dart';
import 'package:threads/widgets/music_sticker.dart';
import 'package:threads/widgets/quote_card.dart';

/// One screen for four jobs: a new post, a reply, a quote and an edit.
/// It returns the saved post, so the caller can update its card without a reload.
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({
    super.key,
    this.replyTo,
    this.quoting,
    this.editing,
    this.community,
  });
  final ThreadPost? replyTo; // the post a reply belongs to
  final ThreadPost? quoting; // the post a quote shows inside it
  final ThreadPost? editing; // the post whose text and settings change
  final Community?
  community; // when posting from inside a community (Step 21.5)
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
  MusicTrack? _music;
  ReplyControl _replyControl = ReplyControl.everyone;
  bool _hideLikes = false;
  bool _ghost = false;
  bool _pollOn = false;
  int _pollDays = 1;

  /// The poll durations offered, in the order the segmented control shows them.
  static const List<int> _pollDayValues = [1, 3, 7];
  bool _busy = false;
  bool _optionsVisible = false;
  bool _reviewReplies = false;

  /// Whether the post should also be shared to Instagram (Step 21.6). It is
  /// only offered when an Instagram account is connected and there is a photo
  /// or video to share.
  bool _crosspost = false;

  /// The community this post goes into, or null for a normal post. It starts
  /// from the community the composer was opened from.
  Community? _community;

  bool get _isEditing => widget.editing != null;
  bool get _isReply => widget.replyTo != null;

  /// Instagram cross-posting is offered only for a new, top-level post that has
  /// a real photo or video to share, and only when an account is connected.
  bool get _canCrosspost =>
      _media.isNotEmpty && ref.watch(instagramAccountProvider).value != null;
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
    if (text.isEmpty &&
        _media.isEmpty &&
        _gifs.isEmpty &&
        _music == null &&
        !keepsMedia) {
      return 'Write something, or add a photo, video, GIF or song.';
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
          Navigator.of(context).pop(
            editing.copyWith(
              content: _text.text.trim(),
              replyControl: _replyControl,
              hideLikeCount: _hideLikes,
            ),
          );
        }
        return;
      }
      final uploadedUrls = await _uploadMedia();
      final mediaUrls = [...uploadedUrls, for (final gif in _gifs) gif.fullUrl];
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
        expiresAt: _ghost
            ? DateTime.now().add(const Duration(hours: 24))
            : null,
        poll: _pollDraft(),
        music: _music,
      );
      _refreshAfterCreate(created);
      // A failed Instagram copy must not block the thread, so the post is
      // already saved; the user is told which copy failed before they leave.
      if (_crosspost && mediaUrls.isNotEmpty) {
        try {
          await ref.read(instagramRepositoryProvider).publish(created.id);
        } catch (error) {
          if (mounted) {
            await showMessage(
              context,
              'Posted to Threads',
              'The Instagram copy failed: '
                  '${error is InstagramException ? error.message : friendlyError(error)}',
            );
          }
        }
      }
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
    final room = maxMediaPerThread - _media.length - _gifs.length;
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

  Future<void> _pickMusic() async {
    final choice = await openScreen<MusicTrack>(
      context,
      const MusicSearchScreen(),
    );
    if (choice == null || !mounted) return;
    setState(() => _music = choice);
  }

  Future<void> _chooseReplyControl() async {
    final choice = await showAppActionSheet<ReplyControl>(
      context,
      title: 'Who can reply',
      items: [
        for (final control in ReplyControl.values)
          AppActionSheetItem(value: control, label: control.label),
      ],
    );
    if (choice != null && mounted) setState(() => _replyControl = choice);
  }

  /// Picks the community the post goes into, or clears it. The list comes from
  /// the communities the signed-in user belongs to.
  Future<void> _chooseCommunity() async {
    final mine = ref.read(myCommunitiesProvider).value ?? const <Community>[];
    final choice = await showAppActionSheet<Community?>(
      context,
      title: 'Post to',
      message: mine.isEmpty
          ? 'Join a community first, from the Communities list.'
          : null,
      items: [
        const AppActionSheetItem(value: null, label: 'None'),
        for (final community in mine)
          AppActionSheetItem(value: community, label: community.name),
      ],
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
    if (_media.isEmpty && _gifs.isEmpty && _music == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_media.isNotEmpty || _gifs.isNotEmpty)
          Wrap(
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
                              color: context.colors.systemGrey5,
                              alignment: Alignment.center,
                              child: Icon(AppIcons.play_circle_fill, size: 34),
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
                        child: Icon(AppIcons.xmark_circle_fill, size: 22),
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
                            ColoredBox(color: context.colors.systemGrey5),
                      ),
                    ),
                    const Positioned(left: 4, bottom: 4, child: _GifTag()),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => setState(() => _gifs.removeAt(i)),
                        child: Icon(AppIcons.xmark_circle_fill, size: 22),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        if (_music != null) ...[
          if (_media.isNotEmpty || _gifs.isNotEmpty) const SizedBox(height: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              MusicSticker(track: _music!),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => setState(() => _music = null),
                  child: Icon(AppIcons.xmark_circle_fill, size: 22),
                ),
              ),
            ],
          ),
        ],
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
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.secondaryLabel,
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

  // Retained for the extended composer controls that will be surfaced in a
  // later options pass; the reference bottom sheet intentionally stays lean.
  // ignore: unused_element
  Widget _pollSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _settingRow(
          title: 'Add a poll',
          trailing: AdaptiveSwitch(
            value: _pollOn,
            onChanged: (value) => setState(() => _pollOn = value),
          ),
        ),
        if (_pollOn) ...[
          const SizedBox(height: 8),
          for (var i = 0; i < _options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AdaptiveTextField(
                controller: _options[i],
                placeholder: 'Option ${i + 1}',
                maxLength: 60,
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (_options.length < maxPollOptions)
            AdaptiveButton.child(
              padding: EdgeInsets.zero,
              onPressed: () =>
                  setState(() => _options.add(TextEditingController())),
              child: const Text('Add an option'),
            ),
          const SizedBox(height: 8),
          AdaptiveSegmentedControl(
            labels: const ['1 day', '3 days', '7 days'],
            selectedIndex: _pollDayValues.indexOf(_pollDays),
            onValueChanged: (index) =>
                setState(() => _pollDays = _pollDayValues[index]),
          ),
        ],
      ],
    );
  }

  // ignore: unused_element
  Widget _settings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isReply && !_isEditing)
          _settingRow(
            title: 'Post to',
            subtitle: _community?.name ?? 'Your profile',
            trailing: Icon(
              AppIcons.chevron_right,
              size: 18,
              color: context.colors.secondaryLabel,
            ),
            onTap: _chooseCommunity,
          ),
        if (!_isReply && !_isEditing && widget.quoting == null && _canCrosspost)
          _settingRow(
            title: 'Also post to Instagram',
            subtitle: 'Shares the photo or video to your Instagram account.',
            trailing: AdaptiveSwitch(
              value: _crosspost,
              onChanged: (value) => setState(() => _crosspost = value),
            ),
          ),
        if (!_isReply)
          _settingRow(
            title: 'Who can reply',
            subtitle: _replyControl.label,
            trailing: Icon(
              AppIcons.chevron_right,
              size: 18,
              color: context.colors.secondaryLabel,
            ),
            onTap: _chooseReplyControl,
          ),
        _settingRow(
          title: 'Hide like count',
          subtitle: 'Only you see how many people liked this.',
          trailing: AdaptiveSwitch(
            value: _hideLikes,
            onChanged: (value) => setState(() => _hideLikes = value),
          ),
        ),
        if (!_isReply && !_isEditing)
          _settingRow(
            title: 'Ghost post',
            subtitle: 'Disappears after 24 hours.',
            trailing: AdaptiveSwitch(
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
    final canPost = !_busy && problem == null;
    final canAddAttachments = !_isEditing;
    final userId = ref.watch(currentUserIdProvider);
    final profile = userId == null
        ? null
        : ref.watch(profileByIdProvider(userId)).value;
    return AdaptiveScaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _composerHeader(title),
                Container(height: 0.5, color: context.colors.separator),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
                    children: [
                      if (replyTo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Replying to @${replyTo.author.username}',
                            style: TextStyle(
                              color: context.colors.secondaryLabel,
                            ),
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Avatar(
                            name: profile?.name ?? 'You',
                            url: profile?.avatarUrl,
                            size: 58,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      profile?.username ?? 'you',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '›',
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: context.colors.secondaryLabel,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        _community?.name ??
                                            'Community or topic',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: context.colors.secondaryLabel,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                AdaptiveTextField(
                                  controller: _text,
                                  autofocus: true,
                                  minLines: 2,
                                  maxLines: null,
                                  maxLength: maxThreadLength,
                                  placeholder: _isReply
                                      ? 'Write your reply'
                                      : "What's new?",
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 14,
                                  ),
                                  cupertinoDecoration: const BoxDecoration(),
                                  decoration: borderlessInputDecoration(
                                    hintText: _isReply
                                        ? 'Write your reply'
                                        : "What's new?",
                                    contentPadding: const EdgeInsets.only(
                                      top: 8,
                                      bottom: 14,
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                if (canAddAttachments) _attachmentRow(),
                                if (!_isEditing) ...[
                                  const SizedBox(height: 12),
                                  _mediaStrip(),
                                ],
                                if (quoting != null) ...[
                                  const SizedBox(height: 12),
                                  QuoteCard(post: quoting, onTap: () {}),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Opacity(
                            opacity: .38,
                            child: Avatar(name: 'Add', size: 30),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Add to thread',
                            style: TextStyle(
                              color: context.colors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_optionsVisible) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _optionsVisible = false),
                  child: const ColoredBox(color: Color(0xB9000000)),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _postOptionsSheet(),
              ),
            ],
            if (!_optionsVisible)
              Align(
                alignment: Alignment.bottomCenter,
                child: _composerFooter(canPost: canPost, label: buttonLabel),
              ),
          ],
        ),
      ),
    );
  }

  Widget _composerHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Icon(AppIcons.xmark, size: 31),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _attachmentRow() => Row(
    children: [
      _attachmentButton(AppIcons.photo_on_rectangle, _pickMedia),
      _attachmentButton(null, _pickGif, label: 'GIF'),
      _attachmentButton(AppIcons.music_note, _pickMusic),
      _attachmentButton(AppIcons.smiley, () {}),
      _attachmentButton(
        AppIcons.ellipsis,
        () => setState(() => _optionsVisible = true),
      ),
    ],
  );

  Widget _attachmentButton(
    IconData? icon,
    VoidCallback onTap, {
    String? label,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      width: 48,
      height: 44,
      child: Center(
        child: icon == null
            ? Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: context.colors.secondaryLabel,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                ),
              )
            : Icon(icon, size: 28, color: context.colors.secondaryLabel),
      ),
    ),
  );

  Widget _postOptionsSheet() => Container(
    padding: const EdgeInsets.fromLTRB(28, 9, 28, 18),
    decoration: BoxDecoration(
      color: const Color(0xFF292929),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.secondaryLabel,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Post options',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 26),
        Text(
          'Who can reply and quote',
          style: TextStyle(fontSize: 13, color: context.colors.secondaryLabel),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF343434),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              _replyChoice('Your followers', ReplyControl.everyone),
              _optionDivider(),
              _replyChoice('Profiles you follow', ReplyControl.following),
              _optionDivider(),
              _replyChoice('Profiles that you mention', ReplyControl.mentioned),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF343434),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Review and approve replies',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              AdaptiveSwitch(
                value: _reviewReplies,
                onChanged: (value) => setState(() => _reviewReplies = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Audience',
          style: TextStyle(fontSize: 13, color: context.colors.secondaryLabel),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _canCrosspost
              ? () => setState(() => _crosspost = !_crosspost)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF343434),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Also share on',
                        style: TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _crosspost ? 'Instagram' : 'Off',
                        style: TextStyle(color: context.colors.secondaryLabel),
                      ),
                    ],
                  ),
                ),
                Icon(
                  AppIcons.chevron_right,
                  color: context.colors.secondaryLabel,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () => setState(() => _optionsVisible = false),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Done',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.black,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _optionDivider() => Container(
    height: .5,
    margin: const EdgeInsets.only(left: 15),
    color: context.colors.separator,
  );

  Widget _replyChoice(String label, ReplyControl value) => GestureDetector(
    onTap: () => setState(() => _replyControl = value),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _replyControl == value
                    ? context.colors.white
                    : context.colors.systemGrey,
                width: 2.5,
              ),
            ),
            child: _replyControl == value
                ? Center(
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: context.colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    ),
  );

  Widget _composerFooter({required bool canPost, required String label}) =>
      Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        decoration: BoxDecoration(
          color: context.colors.systemBackground,
          border: Border(
            top: BorderSide(color: context.colors.separator, width: .5),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _optionsVisible = !_optionsVisible),
              child: Row(
                children: [
                  Icon(
                    AppIcons.slider_horizontal_3,
                    color: context.colors.secondaryLabel,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Post options',
                    style: TextStyle(color: context.colors.secondaryLabel),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: canPost ? _post : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 23,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: canPost
                      ? context.colors.white
                      : context.colors.systemGrey6,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _busy
                    ? const AppSpinner(radius: 8)
                    : Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: canPost
                              ? context.colors.black
                              : context.colors.secondaryLabel,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
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
      child: Text(
        'GIF',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: context.colors.white,
        ),
      ),
    );
  }
}
