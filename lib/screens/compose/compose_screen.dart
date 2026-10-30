// lib/screens/compose/compose_screen.dart
import 'dart:io';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';
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
import 'package:threads/screens/compose/drafts_screen.dart';
import 'package:threads/screens/compose/text_attachment_screen.dart';
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
    this.initialContent,
  });
  final ThreadPost? replyTo; // the post a reply belongs to
  final ThreadPost? quoting; // the post a quote shows inside it
  final ThreadPost? editing; // the post whose text and settings change
  final Community?
  community; // when posting from inside a community (Step 21.5)
  final String? initialContent;
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
  bool _uploading = false;
  double _uploadProgress = 0;
  bool _optionsVisible = false;
  bool _quickToolsVisible = false;
  Map<String, dynamic> _textFormatting = const {};

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
    _text = TextEditingController(
      text: editing?.content ?? widget.initialContent ?? '',
    );
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

  bool get _hasComposerContent =>
      _text.text.trim().isNotEmpty ||
      _media.isNotEmpty ||
      _gifs.isNotEmpty ||
      _music != null ||
      _pollOn;

  Future<void> _handleComposerClose() async {
    if (!_hasComposerContent) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final action = await showAppOverlayDialog<String>(
      context,
      barrierDismissible: true, // tap sa labas = Continue editing
      barrierColor: const Color(0x80000000),
      builder: (dialogContext) => DefaultTextStyle(
        // Ito ang ayos sa font: ang dialog route ay walang text style na
        // namamana, kaya dati nagiging ibang font / may underline. Ngayon SF
        // (system font) na ang gamit ng lahat ng text sa loob.
        style: DefaultTextStyle.of(dialogContext).style,
        child: Center(
          child: Container(
            width: 292,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.colors.systemGrey6,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Save to drafts',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.label,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.3,
                          height: 1.2,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Save to drafts to edit and post\nat a later time',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.secondaryLabel,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -.08,
                          height: 1.3,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                _closeChoice(
                  dialogContext,
                  'Save',
                  'save',
                  weight: FontWeight.w700,
                ),
                _closeChoice(
                  dialogContext,
                  "Don't save",
                  'discard',
                  color: context.colors.systemRed,
                ),
                _closeChoice(dialogContext, 'Continue editing', 'continue'),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null || action == 'continue') return;
    if (action == 'save') {
      await _saveDraft();
    } else if (action == 'discard') {
      Navigator.of(context).pop();
    }
  }

  /// One full-width row of the close dialog, with a hairline above it.
  Widget _closeChoice(
    BuildContext dialogContext,
    String label,
    String value, {
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(height: .5, color: context.colors.separator),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: AdaptiveButton.child(
          style: AdaptiveButtonStyle.plain,
          color: color ?? context.colors.label,
          minSize: const Size(0, 50),
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.zero,
          onPressed: () => Navigator.of(dialogContext).pop(value),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: weight,
              letterSpacing: -.2,
              color: color ?? context.colors.label,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    ],
  );

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
        textFormatting: _textFormatting,
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

  Future<void> _saveDraft() async {
    if (_busy ||
        (_text.text.trim().isEmpty &&
            _media.isEmpty &&
            _gifs.isEmpty &&
            _music == null)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(draftRepositoryProvider)
          .save(
            content: _text.text,
            mediaUrls: [for (final gif in _gifs) gif.fullUrl],
            mediaKinds: [for (final _ in _gifs) 'gif'],
            metadata: {
              if (_music != null) 'music_id': _music!.id,
              'reply_control': _replyControl.name,
              'hide_like_count': _hideLikes,
            },
          );
      if (mounted) {
        await showMessage(
          context,
          'Draft saved',
          'You can finish it later from your drafts.',
        );
        Navigator.of(context).pop();
      }
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
    if (mounted)
      setState(() {
        _uploading = true;
        _uploadProgress = 0;
      });
    try {
      for (var i = 0; i < _media.length; i++) {
        urls.add(await media.uploadThreadMedia(userId, _media[i], i));
        if (mounted) setState(() => _uploadProgress = (i + 1) / _media.length);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
    return urls;
  }

  Future<void> _showEmojiPicker() async {
    const emojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '😂',
      '🤣',
      '🥹',
      '😊',
      '😍',
      '🥰',
      '😘',
      '😎',
      '🤓',
      '🥳',
      '🤍',
      '🖤',
      '❤️',
      '💛',
      '💚',
      '💙',
      '💜',
      '🔥',
      '✨',
      '⭐',
      '💫',
      '🙌',
      '👏',
      '👍',
      '👎',
      '🙏',
      '💯',
      '🎉',
      '🎊',
      '🌈',
      '☀️',
      '🌙',
      '☕',
      '🍕',
      '🍔',
      '🍓',
      '🌱',
      '🚀',
      '📸',
      '🎵',
      '🎬',
      '⚡',
    ];
    final search = TextEditingController();
    await showAppModalSheet<void>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = search.text.trim().toLowerCase();
          final shown = query.isEmpty
              ? emojis
              : emojis.where((emoji) => emoji.contains(query)).toList();
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          final sheetHeight =
              (MediaQuery.sizeOf(context).height - keyboard - 24).clamp(
                260.0,
                360.0,
              );
          return Container(
            height: sheetHeight,
            color: context.colors.systemBackground,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.systemGrey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AdaptiveTextField(
                    controller: search,
                    placeholder: 'Search emoji',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: appFilledInputDecoration(
                      hintText: 'Search emoji',
                      fillColor: context.colors.systemGrey6,
                      borderColor: context.colors.separator,
                      focusedBorderColor: context.colors.activeBlue,
                      radius: 12,
                    ),
                    cupertinoDecoration: BoxDecoration(
                      color: context.colors.systemGrey6,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefix: Padding(
                      padding: EdgeInsets.only(left: 12, right: 8),
                      child: Icon(AppIcons.search, size: 18),
                    ),
                    suffix: search.text.isEmpty
                        ? null
                        : AppIconButton(
                            padding: EdgeInsets.zero,
                            minSize: const Size(36, 36),
                            icon: AppIcons.xmark_circle_fill,
                            size: 18,
                            onPressed: () {
                              search.clear();
                              setSheetState(() {});
                            },
                            semanticLabel: 'Clear emoji search',
                          ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final emoji in shown)
                            SizedBox(
                              width: 34,
                              height: 34,
                              child: GestureDetector(
                                onTap: () {
                                  final value = _text.value;
                                  final start = value.selection.isValid
                                      ? value.selection.start
                                      : value.text.length;
                                  final end = value.selection.isValid
                                      ? value.selection.end
                                      : value.text.length;
                                  final next = value.text.replaceRange(
                                    start,
                                    end,
                                    emoji,
                                  );
                                  _text.value = value.copyWith(
                                    text: next,
                                    selection: TextSelection.collapsed(
                                      offset: start + emoji.length,
                                    ),
                                  );
                                  setState(() {});
                                  Navigator.of(context).pop();
                                },
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(
                                      fontSize: 25,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    search.dispose();
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
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  _composerHeader(title),
                  Container(height: 0.5, color: context.colors.separator),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        20,
                        18,
                        120 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
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
                                            color:
                                                context.colors.secondaryLabel,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  AdaptiveTextField(
                                    controller: _text,
                                    autofocus: false,
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
                                    cupertinoDecoration: BoxDecoration(
                                      color: context.colors.systemGrey6,
                                    ),
                                    decoration:
                                        borderlessInputDecoration(
                                          hintText: _isReply
                                              ? 'Write your reply'
                                              : "What's new?",
                                          contentPadding: const EdgeInsets.only(
                                            top: 8,
                                            bottom: 14,
                                          ),
                                        ).copyWith(
                                          filled: true,
                                          fillColor: context.colors.systemGrey6,
                                        ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  if (canAddAttachments) ...[_attachmentRow()],
                                  if (!_isEditing) ...[
                                    const SizedBox(height: 12),
                                    _mediaStrip(),
                                    if (_pollOn) ...[
                                      const SizedBox(height: 16),
                                      _pollSection(),
                                    ],
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
              Positioned(
                top: 72,
                right: 16,
                child: IgnorePointer(
                  ignoring: !_quickToolsVisible,
                  child: AnimatedOpacity(
                    opacity: _quickToolsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: AnimatedScale(
                      scale: _quickToolsVisible ? 1 : .94,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topRight,
                      child: _managePostsDropdown(),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_optionsVisible,
                  child: AnimatedOpacity(
                    opacity: _optionsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: GestureDetector(
                      onTap: () => setState(() => _optionsVisible = false),
                      child: const ColoredBox(color: Color(0xB9000000)),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: IgnorePointer(
                  ignoring: !_optionsVisible,
                  child: AnimatedSlide(
                    offset: _optionsVisible ? Offset.zero : const Offset(0, 1),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: _postOptionsSheet(),
                  ),
                ),
              ),
              if (!_optionsVisible)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_uploading)
                        Container(
                          height: 4,
                          alignment: Alignment.centerLeft,
                          color: context.colors.systemGrey5,
                          child: FractionallySizedBox(
                            widthFactor: _uploadProgress.clamp(0, 1),
                            child: ColoredBox(color: context.colors.activeBlue),
                          ),
                        ),
                      _composerFooter(canPost: canPost, label: buttonLabel),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composerHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _handleComposerClose,
              child: Icon(AppIcons.xmark, size: 31),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!_isEditing && !_isReply && widget.quoting == null)
              GestureDetector(
                onTap: () =>
                    setState(() => _quickToolsVisible = !_quickToolsVisible),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    AppIcons.ellipsis,
                    color: context.colors.secondaryLabel,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _managePostsDropdown() => Container(
    width: 130,
    height: 120,
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: context.colors.systemBackground,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: context.colors.separator, width: .5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26000000),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _managePostRow(
          context,
          'Save',
          AppIcons.bookmark,
          'save',
          onTap: () {
            setState(() => _quickToolsVisible = false);
            _saveDraft();
          },
        ),
        _managePostRow(
          context,
          'Drafts',
          AppIcons.square_pencil,
          'drafts',
          onTap: () {
            setState(() => _quickToolsVisible = false);
            openScreen<void>(context, const DraftsScreen());
          },
        ),
      ],
    ),
  );

  Future<String?> _showManagePostsSheet() => showAppOverlayDialog<String>(
    context,
    builder: (sheetContext) => SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 72, right: 12),
          child: Container(
            width: 130,
            height: 120,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: context.colors.systemBackground,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: context.colors.separator, width: .5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _managePostRow(sheetContext, 'Save', AppIcons.bookmark, 'save'),
                _managePostRow(
                  sheetContext,
                  'Drafts',
                  AppIcons.square_pencil,
                  'drafts',
                ),
                _managePostRow(
                  sheetContext,
                  'Schedule',
                  AppIcons.clock,
                  'scheduled',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _managePostRow(
    BuildContext sheetContext,
    String label,
    IconData icon,
    String value, {
    VoidCallback? onTap,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap ?? () => Navigator.pop(sheetContext, value),
    child: Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 30,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: TextStyle(
                  color: context.colors.label,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 20,
            height: 20,
            child: Icon(icon, size: 18, color: context.colors.secondaryLabel),
          ),
        ],
      ),
    ),
  );

  Widget _attachmentRow() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _attachmentButton(AppIcons.photo_on_rectangle, _pickMedia),
      _attachmentButton(null, _pickGif, label: 'GIF'),
      _attachmentButton(AppIcons.music_note, _pickMusic),
    ],
  );

  Widget _quickToolsMenu() => Align(
    alignment: Alignment.topRight,
    child: SizedBox(
      width: 170,
      height: 160,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.systemGrey6,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.separator, width: .5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _quickTool('Text', AppIcons.pencil, () async {
              setState(() => _quickToolsVisible = false);
              final result = await Navigator.of(context)
                  .push<TextAttachmentResult>(
                    adaptivePageRoute<TextAttachmentResult>(
                      (_) => TextAttachmentScreen(initialText: _text.text),
                    ),
                  );
              if (result != null && mounted) {
                setState(() {
                  _text.text = result.text;
                  _textFormatting = {
                    if (result.bold) 'bold': true,
                    if (result.italic) 'italic': true,
                    if (result.underline) 'underline': true,
                    if (result.strikethrough) 'strikethrough': true,
                  };
                });
              }
            }),
            _quickTool('Quote', AppIcons.quote_bubble_fill, () {
              setState(() => _quickToolsVisible = false);
              if (widget.quoting == null) {
                showMessage(
                  context,
                  'Quote a post',
                  'Open a post and choose Quote to attach it here.',
                );
              }
            }),
            _quickTool('Poll', AppIcons.slider_horizontal_3, () {
              setState(() {
                _quickToolsVisible = false;
                _pollOn = true;
              });
            }),
            _quickTool('Location', AppIcons.pin_fill, null, disabled: true),
          ],
        ),
      ),
    ),
  );

  Widget _quickTool(
    String label,
    IconData icon,
    VoidCallback? onTap, {
    bool disabled = false,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: disabled ? null : onTap,
    child: Opacity(
      opacity: disabled ? .45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: SizedBox(
          height: 30,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (disabled)
                Text(
                  'Soon',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.secondaryLabel,
                  ),
                )
              else
                Icon(icon, size: 19, color: context.colors.label),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _attachmentButton(
    IconData? icon,
    VoidCallback onTap, {
    String? label,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      width: label != null || icon == AppIcons.music_note ? 36 : 40,
      height: label != null || icon == AppIcons.music_note ? 36 : 40,
      child: Center(
        child: icon == null
            ? Container(
                width: 24,
                height: 24,
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
            : Icon(
                icon,
                size: label != null || icon == AppIcons.music_note ? 24 : 28,
                color: context.colors.secondaryLabel,
              ),
      ),
    ),
  );

  Widget _postOptionsSheet() {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = (MediaQuery.sizeOf(context).height - keyboard - 72).clamp(
      220.0,
      560.0,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        decoration: BoxDecoration(
          color: context.colors.systemBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(
            top: BorderSide(color: context.colors.separator, width: .5),
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                'Who can reply',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: context.colors.systemGrey6,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _replyChoice('Everyone', ReplyControl.everyone),
                    _optionDivider(),
                    _replyChoice('Profiles you follow', ReplyControl.following),
                    _optionDivider(),
                    _replyChoice(
                      'Profiles that you mention',
                      ReplyControl.mentioned,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Audience',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _canCrosspost
                    ? () => setState(() => _crosspost = !_crosspost)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.systemGrey6,
                    borderRadius: BorderRadius.circular(18),
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
                              style: TextStyle(
                                color: context.colors.secondaryLabel,
                              ),
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
                    color: context.colors.label,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.systemBackground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
