// lib/screens/settings/instagram_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/errors.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/data/instagram_repository.dart';
import 'package:threads/models/instagram_account.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/instagram_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Connects or disconnects one Instagram professional account (Step 21.6).
///
/// Connecting opens Meta's consent page in the browser, because the app must
/// never see Meta's app secret. When the person comes back, this screen re-reads
/// the connection, so no deep link is needed.
class InstagramScreen extends ConsumerStatefulWidget {
  const InstagramScreen({super.key});

  @override
  ConsumerState<InstagramScreen> createState() => _InstagramScreenState();
}

class _InstagramScreenState extends ConsumerState<InstagramScreen>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the browser after consent: re-read the connection.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(instagramAccountProvider);
    }
  }

  String _reason(Object error) =>
      error is InstagramException ? error.message : friendlyError(error);

  Future<void> _connect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await ref.read(instagramRepositoryProvider).beginConnect();
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        await showMessage(
          context,
          'Could not open Instagram',
          'Check that a browser is available, then try again.',
        );
      }
    } catch (error) {
      if (mounted) await showMessage(context, 'Instagram', _reason(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final sure = await confirm(
      context,
      title: 'Disconnect Instagram?',
      message: 'Threads you post after this will not be shared to Instagram.',
      actionLabel: 'Disconnect',
      destructive: true,
    );
    if (!sure || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(instagramRepositoryProvider).disconnect();
      ref.invalidate(instagramAccountProvider);
    } catch (error) {
      if (mounted) await showMessage(context, 'Instagram', _reason(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(InstagramAccount? account) {
    return AppListSection(
      header: const Text('Cross-posting'),
      footer: const Text(
        'Sharing to Instagram needs an Instagram professional account linked to a '
        'Facebook Page you manage. Instagram accepts JPEG photos and MP4 or MOV '
        'videos only, and it reviews the publish permission before this works for '
        'people other than you.',
      ),
      children: [
        if (account == null)
          AdaptiveListTile(
            title: const Text('Connect Instagram'),
            subtitle: const Text('Share your threads to Instagram as well'),
            trailing: const AppListChevron(),
            onTap: _connect,
          )
        else ...[
          AdaptiveListTile(
            title: Text(
              account.username == null ? 'Connected' : '@${account.username}',
            ),
            subtitle: const Text('Instagram account'),
            leading: Icon(
              AppIcons.checkmark_seal_fill,
              color: context.colors.activeBlue,
            ),
          ),
          AdaptiveListTile(
            title: Text(
              'Disconnect',
              style: TextStyle(color: context.colors.systemRed),
            ),
            onTap: _disconnect,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(instagramAccountProvider);
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Instagram'),
      body: ResponsiveContent(
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: _busy,
              child: Opacity(
                opacity: _busy ? 0.5 : 1,
                child: ListView(
                  children: [
                    account.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: AppSpinner()),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(friendlyError(error)),
                      ),
                      data: (connected) => _section(connected),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy) const Center(child: AppSpinner(radius: 14)),
          ],
        ),
      ),
    );
  }
}
