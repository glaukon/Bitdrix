import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/media_model.dart';
import '../../presentation/screens/add_torrent/add_torrent_screen.dart';
import '../../presentation/screens/discover/media_detail_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/player/player_screen.dart';
import '../../presentation/screens/torrent_detail/torrent_detail_screen.dart';

/// Application router configuration using GoRouter.
///
/// Routes:
/// - `/`               → [HomeScreen]   (tabs: Torrents, Files, Settings)
/// - `/torrents`       → redirects to `/`
/// - `/torrents/add`   → [AddTorrentScreen]
/// - `/torrents/:id`   → [TorrentDetailScreen]
/// - `/files`          → redirects to `/` (Files tab handled by HomeScreen)
/// - `/player`         → [PlayerScreen]
final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  routes: [
    // ── Shell: home with bottom navigation ──────────────────────────────────
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),

    // ── Torrent routes ───────────────────────────────────────────────────────
    GoRoute(
      path: '/torrents',
      name: 'torrents',
      redirect: (_, __) => '/',
    ),

    GoRoute(
      path: '/torrents/add',
      name: 'add-torrent',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AddTorrentScreen(),
        transitionsBuilder: _slideUpTransition,
      ),
    ),

    GoRoute(
      path: '/torrents/:id',
      name: 'torrent-detail',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return CustomTransitionPage(
          key: state.pageKey,
          child: TorrentDetailScreen(torrentId: id),
          transitionsBuilder: _slideRightTransition,
        );
      },
    ),

    // ── Media detail (Discover) ──────────────────────────────────────────────
    GoRoute(
      path: '/discover/:id',
      name: 'media-detail',
      pageBuilder: (context, state) {
        final tmdbId = int.parse(state.pathParameters['id']!);
        final media = state.extra is MediaModel ? state.extra as MediaModel : null;
        final mediaType = media?.mediaType ?? 'movie';
        return CustomTransitionPage(
          key: state.pageKey,
          child: MediaDetailScreen(
            tmdbId: tmdbId,
            mediaType: mediaType,
            initialMedia: media,
          ),
          transitionsBuilder: _slideRightTransition,
        );
      },
    ),

    // ── Files (handled within HomeScreen tabs, but route exists for deep link)
    GoRoute(
      path: '/files',
      name: 'files',
      redirect: (_, __) => '/',
    ),

    // ── Player ───────────────────────────────────────────────────────────────
    GoRoute(
      path: '/player',
      name: 'player',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final filePath = extra['filePath'] as String? ?? '';
        final title = extra['title'] as String? ?? 'Playing';
        final torrentId = extra['torrentId'] as String?;
        final selectedFileId = extra['selectedFileId'] as String?;
        return CustomTransitionPage(
          key: state.pageKey,
          child: PlayerScreen(
            filePath: filePath,
            title: title,
            torrentId: torrentId,
            selectedFileId: selectedFileId,
          ),
          transitionsBuilder: _fadeTransition,
          opaque: true,
        );
      },
    ),
  ],

  // ── Error page ──────────────────────────────────────────────────────────────
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        'Page not found: ${state.uri}',
        style: const TextStyle(color: Colors.white),
      ),
    ),
  ),
);

// ── Page transition builders ───────────────────────────────────────────────────

Widget _slideUpTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: child,
  );
}

Widget _slideRightTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: child,
  );
}

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
    child: child,
  );
}
