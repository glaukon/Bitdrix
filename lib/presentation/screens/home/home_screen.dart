import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/torrent_providers.dart';
import '../discover/catalog_screen.dart';
import '../favorites/favorites_screen.dart';
import '../tv/tv_screen.dart';
import 'start_screen.dart';

/// The app shell: Inicio, TV, Cine, Series and Favoritos. Downloads run in
/// the background and are never shown; Ajustes opens from the top bar.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  /// From this width on (desktop, tablets in landscape) the tabs move to a
  /// side rail instead of the bottom bar.
  static const _railBreakpoint = 840.0;

  static const List<_TabInfo> _tabs = [
    _TabInfo(
      label: 'Inicio',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
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
      label: 'Favoritos',
      icon: Icons.star_outline_rounded,
      activeIcon: Icons.star_rounded,
    ),
  ];

  static const List<Widget> _screens = [
    StartScreen(),
    TvScreen(),
    CatalogScreen(mediaType: 'movie'),
    CatalogScreen(mediaType: 'tv'),
    FavoritesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Watched videos are kept for a while (to resume or rewatch quickly);
    // the old ones go so the hidden cache does not fill the disk.
    Future<void>.delayed(const Duration(seconds: 20), () {
      if (mounted) {
        ref
            .read(torrentsProvider.notifier)
            .removeOlderThan(const Duration(days: 7));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _railBreakpoint;
    final body = IndexedStack(index: _currentIndex, children: _screens);

    return Scaffold(
      appBar: _buildAppBar(),
      body: wide
          ? Row(
              children: [
                _buildRail(),
                const VerticalDivider(width: 1, color: Color(0xFF222233)),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide ? null : _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 20,
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
        IconButton(
          tooltip: 'Ajustes',
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => context.push('/settings'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildRail() {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) => setState(() => _currentIndex = index),
      labelType: NavigationRailLabelType.all,
      backgroundColor: AppTheme.surface,
      destinations: [
        for (final tab in _tabs)
          NavigationRailDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.activeIcon),
            label: Text(tab.label),
          ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) =>
          setState(() => _currentIndex = index),
      destinations: [
        for (final tab in _tabs)
          NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.activeIcon),
            label: tab.label,
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
