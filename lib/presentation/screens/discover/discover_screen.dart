import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/tmdb_service.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/tmdb_key_dialog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/media_model.dart';
import '../../providers/discover_providers.dart';
import 'widgets/media_card.dart';

/// Maximum width of a poster card in the Discover grids.
const double _kCardMaxWidth = 180;

/// The Discover tab — browse trending content or search TMDB.
///
/// - Empty search: shows a 2-column trending grid.
/// - Active search: shows search results in the same 2-column grid.
/// - Debounces user input by 500 ms before updating the provider.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final isSearching = query.trim().isNotEmpty;

    return Column(
      children: [
        _SearchBar(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onClear: _clearSearch,
        ),
        Expanded(
          child:
              isSearching ? _SearchResultsView(query: query) : _TrendingView(),
        ),
      ],
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
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
          hintText: 'Buscar películas y series…',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.onSurfaceVariant),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
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

// ── Trending view ─────────────────────────────────────────────────────────────

class _TrendingView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingProvider);
    final nowPlayingMoviesAsync = ref.watch(nowPlayingMoviesProvider);
    final upcomingMoviesAsync = ref.watch(upcomingMoviesProvider);
    final onTheAirTvAsync = ref.watch(onTheAirTvProvider);

    Future<void> refreshDiscover() async {
      ref.invalidate(trendingProvider);
      ref.invalidate(nowPlayingMoviesProvider);
      ref.invalidate(upcomingMoviesProvider);
      ref.invalidate(onTheAirTvProvider);
      await Future.wait([
        ref.read(trendingProvider.future),
        ref.read(nowPlayingMoviesProvider.future),
        ref.read(upcomingMoviesProvider.future),
        ref.read(onTheAirTvProvider.future),
      ]);
    }

    return trendingAsync.when(
      loading: () => _ShimmerGrid(),
      error: (error, _) => _ErrorView(
        error: error,
        message: 'No se ha podido cargar el contenido.',
        onRetry: () => ref.invalidate(trendingProvider),
      ),
      data: (items) {
        final sections = [
          _MediaSection(title: 'Tendencias de hoy', items: items),
          nowPlayingMoviesAsync.maybeWhen(
            data: (movies) => _MediaSection(
              title: 'En cines en España',
              items: movies,
            ),
            orElse: () => null,
          ),
          upcomingMoviesAsync.maybeWhen(
            data: (movies) => _MediaSection(
              title: 'Próximos estrenos',
              items: movies,
            ),
            orElse: () => null,
          ),
          onTheAirTvAsync.maybeWhen(
            data: (shows) => _MediaSection(
              title: 'En emisión',
              items: shows,
            ),
            orElse: () => null,
          ),
        ]
            .whereType<_MediaSection>()
            .where((section) => section.items.isNotEmpty)
            .toList();

        if (sections.isEmpty) {
          return const _EmptyView(message: 'No se ha encontrado contenido.');
        }
        return _MediaGrid(
          sections: sections,
          onRefresh: refreshDiscover,
        );
      },
    );
  }
}

// ── Search results view ───────────────────────────────────────────────────────

class _SearchResultsView extends ConsumerWidget {
  const _SearchResultsView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider);

    return resultsAsync.when(
      loading: () => _ShimmerGrid(),
      error: (error, _) => _ErrorView(
        error: error,
        message: 'La búsqueda ha fallado. Inténtalo de nuevo.',
        onRetry: () => ref.invalidate(searchResultsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _EmptyView(message: 'No hay resultados para "$query".');
        }
        return _MediaGrid(
          sections: [
            _MediaSection(
              title: 'Resultados para "$query"',
              items: items,
            ),
          ],
        );
      },
    );
  }
}

// ── Shared grid ───────────────────────────────────────────────────────────────

class _MediaSection {
  const _MediaSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<MediaModel> items;
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({
    required this.sections,
    this.onRefresh,
  });

  final List<_MediaSection> sections;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        for (final section in sections) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                section.title,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: MediaCard(media: section.items[index]),
                ),
                childCount: section.items.length,
              ),
              // Fixed max card width: 2 columns on phones, many on desktop.
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _kCardMaxWidth,
                childAspectRatio: 0.52,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );

    if (onRefresh == null) return scrollView;

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: onRefresh!,
      child: scrollView,
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
      builder: (_, __) {
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
          itemBuilder: (_, __) => Column(
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
