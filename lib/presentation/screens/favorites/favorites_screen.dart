import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/media_model.dart';
import '../../../data/models/stremio_addon.dart';
import '../../providers/addon_providers.dart';
import '../../providers/favorites_providers.dart';
import '../../widgets/channel_widgets.dart';
import '../../widgets/horizontal_scroller.dart';
import '../../widgets/media_rows.dart';
import '../../widgets/selectable_chip.dart';
import '../discover/widgets/media_card.dart';

enum _FavoritesFilter { all, tv, movies, series }

/// Everything the user starred: channels, movies and shows, with quick
/// filters by kind.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  _FavoritesFilter _filter = _FavoritesFilter.all;

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(favoriteMetasProvider);
    final media = ref.watch(favoriteMediaProvider);
    final movies = media.where((m) => m.mediaType == 'movie').toList();
    final series = media.where((m) => m.mediaType == 'tv').toList();

    final chips = [
      (_FavoritesFilter.all, 'Todos', Icons.star_rounded,
          channels.length + media.length),
      (_FavoritesFilter.tv, 'TV', Icons.live_tv_rounded, channels.length),
      (_FavoritesFilter.movies, 'Cine', Icons.movie_rounded, movies.length),
      (_FavoritesFilter.series, 'Series', Icons.tv_rounded, series.length),
    ];

    return Column(
      children: [
        HorizontalScroller(
          height: 64,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          wheelScrollsSideways: true,
          showScrollbar: false,
          itemCount: chips.length,
          itemBuilder: (_, i) {
            final (filter, label, icon, count) = chips[i];
            return SelectableChip(
              selected: _filter == filter,
              onSelected: (_) => setState(() => _filter = filter),
              avatar: Icon(icon, size: 18),
              label: '$label ($count)',
            );
          },
        ),
        Expanded(
          child: switch (_filter) {
            _FavoritesFilter.all => channels.isEmpty && media.isEmpty
                ? const _EmptyFavorites(
                    text: 'Aún no tienes favoritos.\nMarca con la estrella los '
                        'canales, películas y series que más te gusten.',
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (channels.isNotEmpty) _ChannelRow(channels: channels),
                      if (movies.isNotEmpty)
                        MediaRow(title: 'Películas', items: movies),
                      if (series.isNotEmpty)
                        MediaRow(title: 'Series', items: series),
                    ],
                  ),
            _FavoritesFilter.tv => channels.isEmpty
                ? const _EmptyFavorites(
                    text: 'Marca canales con la estrella en la pestaña TV.',
                  )
                : _ChannelGrid(channels: channels),
            _FavoritesFilter.movies => movies.isEmpty
                ? const _EmptyFavorites(
                    text: 'Abre una película y pulsa la estrella para '
                        'guardarla aquí.',
                  )
                : _PosterGrid(items: movies),
            _FavoritesFilter.series => series.isEmpty
                ? const _EmptyFavorites(
                    text: 'Abre una serie y pulsa la estrella para '
                        'guardarla aquí.',
                  )
                : _PosterGrid(items: series),
          },
        ),
      ],
    );
  }
}

/// Favourite channels as a horizontal row (on the "Todos" view and Inicio).
class FavoriteChannelsRow extends ConsumerWidget {
  const FavoriteChannelsRow({super.key, this.title = 'Canales'});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(favoriteMetasProvider);
    if (channels.isEmpty) return const SizedBox.shrink();
    return _ChannelRow(channels: channels, title: title);
  }
}

class _ChannelRow extends ConsumerWidget {
  const _ChannelRow({required this.channels, this.title = 'Canales'});

  final List<StremioMeta> channels;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.read(favoriteMetasProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RowTitle(title),
        HorizontalScroller(
          height: 150,
          spacing: 12,
          itemCount: channels.length,
          itemBuilder: (_, i) => SizedBox(
            width: 150,
            child: ChannelCard(
              meta: channels[i],
              favorite: true,
              onTap: () => openChannel(context, channels[i]),
              onToggleFavorite: () => favorites.toggle(channels[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChannelGrid extends ConsumerWidget {
  const _ChannelGrid({required this.channels});

  final List<StremioMeta> channels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.read(favoriteMetasProvider.notifier);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        childAspectRatio: 0.95,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: channels.length,
      itemBuilder: (_, i) => ChannelCard(
        meta: channels[i],
        favorite: true,
        onTap: () => openChannel(context, channels[i]),
        onToggleFavorite: () => favorites.toggle(channels[i]),
      ),
    );
  }
}

class _PosterGrid extends StatelessWidget {
  const _PosterGrid({required this.items});

  final List<MediaModel> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.52,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.all(4),
        child: MediaCard(media: items[i]),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_outline_rounded,
                size: 56, color: AppTheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.onSurface, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
