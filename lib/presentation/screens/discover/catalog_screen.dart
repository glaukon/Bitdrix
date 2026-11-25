import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/media_model.dart';
import '../../../data/services/tmdb_service.dart';
import '../../providers/discover_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/horizontal_scroller.dart';
import '../../widgets/tmdb_key_dialog.dart';
import 'widgets/media_card.dart';

/// Maximum width of a poster card in the search-results grid.
const double _kCardMaxWidth = 180;

/// Width of a poster card in the horizontal rows.
const double _kRowCardWidth = 140;

/// The Cine (`mediaType: 'movie'`) or Series (`'tv'`) tab: a featured title,
/// then rows of TMDB lists; typing searches only that kind of title.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key, required this.mediaType});

  final String mediaType;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool get _isMovies => widget.mediaType == 'movie';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchQueryProvider(widget.mediaType).notifier).set(value);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    ref.read(searchQueryProvider(widget.mediaType).notifier).set('');
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider(widget.mediaType));
    final isSearching = query.trim().isNotEmpty;

    return Column(
      children: [
        _SearchBar(
          controller: _searchController,
          hint: _isMovies ? 'Buscar películas…' : 'Buscar series…',
          onChanged: _onSearchChanged,
          onClear: _clearSearch,
        ),
        Expanded(
          child: isSearching
              ? _SearchResultsView(mediaType: widget.mediaType, query: query)
              : _BrowseView(mediaType: widget.mediaType),
        ),
      ],
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: AppTheme.onBackground),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.onSurfaceVariant),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.clear_rounded, size: 20),
                color: AppTheme.onSurfaceVariant,
                onPressed: onClear,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Browse view: featured title + rows ───────────────────────────────────────

class _BrowseView extends ConsumerWidget {
  const _BrowseView({required this.mediaType});

  final String mediaType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = CatalogList.forType(mediaType);
    // The first list decides between content and an error (such as a missing
    // TMDB key); the other rows load on their own.
    final first = ref.watch(catalogListProvider(lists.first));

    Future<void> refresh() async {
      for (final list in lists) {
        ref.invalidate(catalogListProvider(list));
      }
      await ref.read(catalogListProvider(lists.first).future);
    }

    return first.when(
      loading: () => _ShimmerGrid(),
      error: (error, _) => _ErrorView(
        error: error,
        message: 'No se ha podido cargar el contenido.',
        onRetry: () => ref.invalidate(catalogListProvider(lists.first)),
      ),
      data: (items) {
        final featured = items
            .where((m) => m.backdropUrl != null)
            .firstOrNull;
        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (featured != null) _FeaturedBanner(media: featured),
              for (final list in lists) _CatalogRow(list: list),
            ],
          ),
        );
      },
    );
  }
}

/// The top trending title, large, with its backdrop and synopsis.
class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.media});

  final MediaModel media;

  @override
  Widget build(BuildContext context) {
    void open() => context.push('/discover/${media.id}', extra: media);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: AppTheme.cardColor,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    media.backdropUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xF00A0A12), Color(0x000A0A12)],
                        stops: [0.0, 0.75],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'DESTACADO HOY',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FractionallySizedBox(
                          widthFactor: 0.6,
                          child: Text(
                            media.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (media.overview?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: 0.6,
                            child: Text(
                              media.overview!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: open,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Ver fuentes'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One titled, horizontally scrolling row of posters.
class _CatalogRow extends ConsumerWidget {
  const _CatalogRow({required this.list});

  final CatalogList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(catalogListProvider(list)).value;
    // Rows that fail or come back empty are simply left out.
    if (items != null && items.isEmpty) return const SizedBox.shrink();

    const posterHeight = _kRowCardWidth * 3 / 2;
    const rowHeight = posterHeight + 44;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            list.title,
            style: const TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        items == null
            ? const SizedBox(
                height: rowHeight,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              )
            : HorizontalScroller(
                height: rowHeight,
                spacing: 12,
                itemCount: items.length,
                itemBuilder: (_, i) => SizedBox(
                  width: _kRowCardWidth,
                  child: MediaCard(media: items[i]),
                ),
              ),
      ],
    );
  }
}

// ── Search results view ───────────────────────────────────────────────────────

class _SearchResultsView extends ConsumerWidget {
  const _SearchResultsView({required this.mediaType, required this.query});

  final String mediaType;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider(mediaType));

    return resultsAsync.when(
      loading: () => _ShimmerGrid(),
      error: (error, _) => _ErrorView(
        error: error,
        message: 'La búsqueda ha fallado. Inténtalo de nuevo.',
        onRetry: () => ref.invalidate(searchResultsProvider(mediaType)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _EmptyView(message: 'No hay resultados para "$query".');
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _kCardMaxWidth,
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
      },
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _ShimmerGrid extends StatefulWidget {
  @override
  State<_ShimmerGrid> createState() => _ShimmerGridState();
}

class _ShimmerGridState extends State<_ShimmerGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) {
        final grey = Color.lerp(
          AppTheme.surfaceVariant,
          const Color(0xFF2A2A3A),
          _animation.value,
        )!;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _kCardMaxWidth,
            childAspectRatio: 0.52,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 24,
          itemBuilder: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(color: grey),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 10,
                width: 60,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: grey.withAlpha(150),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Error / empty states ──────────────────────────────────────────────────────

class _ErrorView extends ConsumerWidget {
  const _ErrorView({
    required this.error,
    required this.message,
    required this.onRetry,
  });

  final Object error;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (TmdbService.isAuthError(error)) {
      final hasKey = ref.watch(tmdbApiKeyProvider).isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.key_rounded,
                size: 56,
                color: AppTheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                hasKey
                    ? 'TMDB ha rechazado la clave de API. Revísala e inténtalo de nuevo.'
                    : 'Descubrir necesita una clave de API gratuita de TMDB para cargar películas y series.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.onSurface, fontSize: 15),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => showTmdbKeyDialog(context, ref),
                icon: const Icon(Icons.vpn_key_rounded),
                label: Text(hasKey ? 'Cambiar clave de API' : 'Añadir clave de API'),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppTheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.onSurface,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: AppTheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.onSurface,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
