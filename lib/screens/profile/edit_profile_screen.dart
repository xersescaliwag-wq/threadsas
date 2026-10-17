// lib/screens/profile/edit_profile_screen.dart
import 'dart:typed_data';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/config.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/feed_providers.dart';
import 'package:threads/providers/social_providers.dart';
import 'package:threads/widgets/avatar.dart';
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.profile});
  final Profile profile;
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}
class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _website;
  late bool _isPrivate;
  XFile? _newPhoto;
  Uint8List? _photoPreview;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _name = TextEditingController(text: profile.displayName);
    _username = TextEditingController(text: profile.username);
    _bio = TextEditingController(text: profile.bio);
    _website = TextEditingController(text: profile.website ?? '');
    _isPrivate = profile.isPrivate;
  }
  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _website.dispose();
    super.dispose();
  }
  Future<void> _pickPhoto() async {
    try {
      // Resizing keeps the upload small and well under the 5 MB bucket limit.
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newPhoto = file;
        _photoPreview = bytes;
      });
    } catch (error) {
      if (mounted) await showError(context, error);
    }
  }
  /// Going public leaves old follow requests pending, because no trigger
  /// accepts them. Accept them here. A failure is not fatal: the person can
  /// still accept them later from Follow requests.
  Future<void> _acceptPendingRequests() async {
    try {
      final social = ref.read(socialRepositoryProvider);
      for (final request in await social.followRequests()) {
        await social.acceptRequest(request.id);
      }
      ref.invalidate(followRequestsProvider);
    } catch (_) {}
  }
  Future<void> _save() async {
    if (_busy) return;
    final username = _username.text.trim().toLowerCase();
    final problem = validateUsername(username);
    if (problem != null) {
      await showMessage(context, 'Check your username', problem);
      return;
    }
    setState(() => _busy = true);
    try {
      final changedName = username != widget.profile.username;
      if (changedName && !await ref.read(authRepositoryProvider).isUsernameAvailable(username)) {
        if (mounted) await showMessage(context, 'Username taken', 'Choose another username.');
        return;
      }
      final userId = widget.profile.id;
      final photo = _newPhoto;
      final avatarUrl = photo == null
          ? null
          : await ref.read(mediaRepositoryProvider).uploadAvatar(userId, photo);
      await ref.read(profileRepositoryProvider).updateProfile(
            userId: userId,
            username: username,
            displayName: _name.text,
            bio: _bio.text,
            website: _website.text,
            isPrivate: _isPrivate,
            avatarUrl: avatarUrl,
          );
      if (widget.profile.isPrivate && !_isPrivate) await _acceptPendingRequests();
      ref.invalidate(myProfileProvider);
      ref.invalidate(profileByIdProvider(userId));
      // Posts on screen carry the old name and photo, so reload both feeds.
      ref.invalidate(forYouFeedProvider);
      ref.invalidate(followingFeedProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colors.secondaryLabel,
        ),
      ),
    );
  }
  Widget _photo() {
    final preview = _photoPreview;
    if (preview != null) {
      return ClipOval(
        child: Image.memory(preview, width: 96, height: 96, fit: BoxFit.cover),
      );
    }
    return Avatar(name: widget.profile.name, url: widget.profile.avatarUrl, size: 96);
  }
  @override
  Widget build(BuildContext context) {
    // Leaving while the save runs would use a screen that no longer exists.
    return PopScope(
      canPop: !_busy,
      child: AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: 'Edit profile'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _busy ? null : _pickPhoto,
                  child: Column(
                    children: [
                      _photo(),
                      const SizedBox(height: 8),
                      Text(
                        'Change photo',
                        style: TextStyle(color: context.colors.activeBlue),
                      ),
                    ],
                  ),
                ),
              ),
              _label('Name'),
              AdaptiveTextField(
                controller: _name,
                placeholder: 'Your name',
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              _label('Username'),
              AdaptiveTextField(
                controller: _username,
                placeholder: 'username',
                autocorrect: false,
                textInputAction: TextInputAction.next,
              ),
              _label('Bio'),
              AdaptiveTextField(
                controller: _bio,
                placeholder: 'Tell people about yourself',
                minLines: 3,
                maxLines: 4,
                maxLength: maxBioLength,
                onChanged: (_) => setState(() {}),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_bio.text.length}/$maxBioLength',
                  style: TextStyle(fontSize: 13, color: context.colors.secondaryLabel),
                ),
              ),
              _label('Website'),
              AdaptiveTextField(
                controller: _website,
                placeholder: 'example.com',
                keyboardType: TextInputType.url,
                autocorrect: false,
                maxLength: 200,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Private account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(
                          'New followers need your approval. People who already follow you stay.',
                          style: TextStyle(fontSize: 13, color: context.colors.secondaryLabel),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AdaptiveSwitch(
                    value: _isPrivate,
                    onChanged: _busy ? null : (value) => setState(() => _isPrivate = value),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AdaptiveButton.child(
                onPressed: _busy ? null : _save,
                child: _busy ? const AppSpinner() : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
