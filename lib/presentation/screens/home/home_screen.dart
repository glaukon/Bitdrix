import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/torrent_providers.dart';
import '../discover/catalog_screen.dart';
import '../tv/tv_screen.dart';
import 'downloads_screen.dart';
import 'settings_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Opens on Cine, the main use of the app.
  int _currentIndex = 1;

  /// From this width on (desktop, tablets in landscape) the tabs move to a
  /// side rail instead of the bottom bar.
  static const _railBreakpoint = 840.0;

  static const _downloadsIndex = 3;

  static const List<_TabInfo> _tabs = [
    _TabInfo(
      label: 'TV',
      icon: Icons.live_tv_outlined,
      activeIcon: Icons.live_tv_rounded,
    ),
    _TabInfo(
      label: 'Cine',
      icon: Icons.movie_outlined,
      activeIcon: Icons.movie_rounded,
    ),
    _TabInfo(
      label: 'Series',
      icon: Icons.tv_outlined,
      activeIcon: Icons.tv_rounded,
    ),
    _TabInfo(
      label: 'Descargas',
      icon: Icons.download_outlined,
      activeIcon: Icons.download_rounded,
    ),
    _TabInfo(
      label: 'Ajustes',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
    ),
  ];

  static const List<Widget> _screens = [
    TvScreen(),
    CatalogScreen(mediaType: 'movie'),
    CatalogScreen(mediaType: 'tv'),
    DownloadsScreen(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final activeCount = ref.watch(activeCountProvider);
    final wide = MediaQuery.sizeOf(context).width >= _railBreakpoint;
    final body = IndexedStack(index: _currentIndex, children: _screens);

    return Scaffold(
      appBar: _buildAppBar(activeCount),
      body: wide
          ? Row(
              children: [
                _buildRail(activeCount),
                const VerticalDivider(width: 1, color: Color(0xFF222233)),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide ? null : _buildBottomNav(activeCount),
    );
  }

  /// The tab icon, with a counter of active downloads on Descargas.
  Widget _tabIcon(int index, {required bool selected, required int active}) {
    final tab = _tabs[index];
    final icon = Icon(selected ? tab.activeIcon : tab.icon);
    if (index != _downloadsIndex || active == 0) return icon;
    return Badge(
      label: Text('$active'),
      backgroundColor: AppTheme.accent,
      child: icon,
    );
  }

  Widget _buildRail(int activeCount) {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) => setState(() => _currentIndex = index),
      labelType: NavigationRailLabelType.all,
      backgroundColor: AppTheme.surface,
      destinations: [
        for (var i = 0; i < _tabs.length; i++)
          NavigationRailDestination(
            icon: _tabIcon(i, selected: false, active: activeCount),
            selectedIcon: _tabIcon(i, selected: true, active: activeCount),
            label: Text(_tabs[i].label),
          ),
      ],
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

  Widget _buildBottomNav(int activeCount) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) =>
          setState(() => _currentIndex = index),
      destinations: [
        for (var i = 0; i < _tabs.length; i++)
          NavigationDestination(
            icon: _tabIcon(i, selected: false, active: activeCount),
            selectedIcon: _tabIcon(i, selected: true, active: activeCount),
            label: _tabs[i].label,
          ),
      ],
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
