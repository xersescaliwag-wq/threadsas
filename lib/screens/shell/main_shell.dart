// lib/screens/shell/main_shell.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/providers/notification_providers.dart';
import 'package:threads/screens/activity/activity_screen.dart';
import 'package:threads/screens/community/community_list_screen.dart';
import 'package:threads/screens/compose/compose_screen.dart';
import 'package:threads/screens/home/feeds_drawer.dart';
import 'package:threads/screens/home/home_screen.dart';
import 'package:threads/screens/messages/messages_screen.dart';
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
  static const _titles = ['Threads', 'Messages', '', 'Activity', 'Profile'];

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
          iosSymbol: 'magnifyingglass',
          icon: AppIcons.search,
          onPressed: () => openScreen<void>(context, const _SearchPage()),
        ),
        AdaptiveAppBarAction(
          iosSymbol: 'person.2.fill',
          icon: AppIcons.person_2_fill,
          onPressed: () =>
              openScreen<void>(context, const CommunityListScreen()),
        ),
      ];
    }
    if (_tab != _profileTab) return const [];
    return [
      AdaptiveAppBarAction(
        iosSymbol: 'gearshape',
        icon: AppIcons.settings,
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
    // The tab icon must match the bar that will draw it. The iOS 26+ native tab
    // bar reads an SF Symbol *string*; the older Cupertino bar and the Android
    // Material bar need an IconData (a string there becomes a plain circle, and
    // the string is only mapped for a few symbols). So use the SF Symbol name
    // only where the native bar consumes it.
    final sfSymbols = PlatformInfo.isIOS26OrHigher();
    return AdaptiveScaffold(
      // iOS 26's native tab bar shrinks to a pill while the feed scrolls. The
      // app is a full-screen feed reader, so keep the bar at full size instead
      // of letting it duck away mid-scroll.
      minimizeBehavior: TabBarMinimizeBehavior.never,
      appBar: _tab == _homeTab
          ? null
          : AdaptiveAppBar(title: _titles[_tab], actions: _actions()),
      drawer: const FeedsDrawer(),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: _tab,
        onTap: _onTap,
        items: [
          AdaptiveNavigationDestination(
            icon: sfSymbols ? 'house.fill' : AppIcons.house_fill,
            label: 'Home',
          ),
          AdaptiveNavigationDestination(
            icon: sfSymbols ? 'paperplane' : AppIcons.paperplane,
            label: 'Messages',
          ),
          AdaptiveNavigationDestination(
            icon: sfSymbols ? 'square.and.pencil' : AppIcons.square_pencil,
            label: 'Post',
          ),
          AdaptiveNavigationDestination(
            icon: sfSymbols ? 'heart.fill' : AppIcons.heart_fill,
            label: 'Activity',
            badgeCount: unread > 0 ? unread : null,
          ),
          AdaptiveNavigationDestination(
            icon: sfSymbols ? 'person.fill' : AppIcons.person_fill,
            label: 'Profile',
          ),
        ],
      ),
      body: ResponsiveContent(
        child: IndexedStack(
          index: _tab,
          children: [
            const HomeScreen(),
            const MessagesScreen(),
            const SizedBox.shrink(),
            ActivityScreen(isVisible: _tab == 3),
            ProfileScreen(userId: me, showAppBar: false),
          ],
        ),
      ),
    );
  }
}

class _SearchPage extends StatelessWidget {
  const _SearchPage();

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: AdaptiveAppBar(title: 'Search'),
    body: const ResponsiveContent(child: SearchScreen()),
  );
}
