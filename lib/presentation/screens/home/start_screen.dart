import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/tmdb_service.dart';
import '../../providers/discover_providers.dart';
import '../../providers/favorites_providers.dart';
import '../../widgets/media_rows.dart';
import '../../widgets/tmdb_key_dialog.dart';
import '../favorites/favorites_screen.dart';

/// Inicio: today's featured title, the user's favourites, and what is
/// popular in cinema and TV.
class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  static const _rows = [
    (CatalogList.trendingMovies, 'Tendencias en cine'),
    (CatalogList.trendingTv, 'Series del momento'),
    (CatalogList.nowPlaying, 'En cines en España'),
    (CatalogList.topRatedMovies, 'Películas mejor valoradas'),
    (CatalogList.topRatedTv, 'Series mejor valoradas'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(catalogListProvider(CatalogList.trendingMovies));
    final favorites = ref.watch(favoriteMediaProvider);
    final featured =
        trending.value?.where((m) => m.backdropUrl != null).firstOrNull;

    Future<void> refresh() async {
      for (final (list, _) in _rows) {
        ref.invalidate(catalogListProvider(list));
      }
      await ref.read(catalogListProvider(CatalogList.trendingMovies).future);
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          if (trending.hasError && TmdbService.isAuthError(trending.error!))
            const _MissingTmdbKey(),
          if (featured != null) FeaturedBanner(media: featured),
          const FavoriteChannelsRow(title: 'Tus canales'),
          if (favorites.isNotEmpty)
            MediaRow(title: 'Tus favoritos', items: favorites),
          for (final (list, title) in _rows)
            CatalogListRow(list: list, title: title),
        ],
      ),
    );
  }
}

/// Cine and Series need a TMDB key; say so on Inicio instead of showing an
/// empty page.
class _MissingTmdbKey extends ConsumerWidget {
  const _MissingTmdbKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.key_rounded,
              size: 48, color: AppTheme.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text(
            'Para ver películas y series hace falta una clave de API '
            'gratuita de TMDB.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.onSurface, fontSize: 15),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showTmdbKeyDialog(context, ref),
            icon: const Icon(Icons.vpn_key_rounded),
            label: const Text('Añadir clave de API'),
          ),
        ],
      ),
    );
  }
}
