import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/torrent_providers.dart';
import '../discover/discover_screen.dart';
import '../files/files_screen.dart';
import '../torrent_list/torrent_list_screen.dart';
import 'settings_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  static const List<_TabInfo> _tabs = [
    _TabInfo(
      label: 'Torrents',
      icon: Icons.download_rounded,
      activeIcon: Icons.download_rounded,
    ),
    _TabInfo(
      label: 'Discover',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
    ),
    _TabInfo(
      label: 'Files',
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder_rounded,
    ),
    _TabInfo(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
    ),
  ];

  static const List<Widget> _screens = [
    TorrentListScreen(),
    DiscoverScreen(),
    FilesScreen(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final activeCount = ref.watch(activeCountProvider);

    return Scaffold(
      appBar: _buildAppBar(activeCount),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar(int activeCount) {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.downloading_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            AppConstants.appName,
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        if (activeCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.accent.withAlpha(77),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.downloading_rounded,
                      color: AppTheme.accent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$activeCount',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) =>
          setState(() => _currentIndex = index),
      destinations: _tabs
          .map(
            (tab) => NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.activeIcon),
              label: tab.label,
            ),
          )
          .toList(),
    );
  }
}

class _TabInfo {
  const _TabInfo({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
  final String label;
  final IconData icon;
  final IconData activeIcon;
}
