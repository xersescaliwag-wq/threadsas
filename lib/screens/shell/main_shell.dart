// lib/screens/shell/main_shell.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/notification_providers.dart';
import 'package:threads/screens/activity/activity_screen.dart';
import 'package:threads/screens/community/community_list_screen.dart';
import 'package:threads/screens/compose/compose_screen.dart';
import 'package:threads/screens/home/home_screen.dart';
import 'package:threads/screens/profile/profile_screen.dart';
import 'package:threads/screens/search/search_screen.dart';
import 'package:threads/screens/settings/settings_screen.dart';

const _homeTab = 0;
const _composeTab = 2;
const _profileTab = 4;

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _tab = _homeTab;
  static const _titles = ['Threads', 'Search', '', 'Activity', 'Profile'];

  void _onTap(int index) {
    if (index == _composeTab) {
      openScreen<void>(context, const ComposeScreen(), fullscreen: true);
      return;
    }
    setState(() => _tab = index);
  }

  List<AdaptiveAppBarAction> _actions() {
    if (_tab == _homeTab) {
      return [
        AdaptiveAppBarAction(
          iosSymbol: 'person.2.fill',
          icon: CupertinoIcons.person_2_fill,
          onPressed: () =>
              openScreen<void>(context, const CommunityListScreen()),
        ),
      ];
    }
    if (_tab != _profileTab) return const [];
    return [
      AdaptiveAppBarAction(
        iosSymbol: 'gearshape',
        icon: CupertinoIcons.settings,
        onPressed: () => openScreen<void>(context, const SettingsScreen()),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Each realtime event may mean a new notification. Reload the list and the badge.
    ref.listen(notificationLiveProvider, (previous, next) {
      ref.invalidate(activityProvider);
      ref.invalidate(unreadCountProvider);
    });
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final me = ref.watch(currentUserIdProvider) ?? '';
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: _titles[_tab],
        actions: _actions(),
      ),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: _tab,
        onTap: _onTap,
        items: [
          const AdaptiveNavigationDestination(icon: 'house.fill', label: 'Home'),
          const AdaptiveNavigationDestination(icon: 'magnifyingglass', label: 'Search'),
          const AdaptiveNavigationDestination(icon: 'square.and.pencil', label: 'Post'),
          AdaptiveNavigationDestination(
            icon: 'heart.fill',
            label: 'Activity',
            badgeCount: unread > 0 ? unread : null,
          ),
          const AdaptiveNavigationDestination(icon: 'person.fill', label: 'Profile'),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          const HomeScreen(),
          const SearchScreen(),
          const SizedBox.shrink(),
          const ActivityScreen(),
          ProfileScreen(userId: me, showAppBar: false),
        ],
      ),
    );
  }
}
