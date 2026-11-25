import 'package:material_ui/material_ui.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/audio_language.dart';
import '../../../data/models/media_model.dart';
import '../../../data/models/stream_source_model.dart';
import '../../providers/settings_providers.dart';
import '../../providers/discover_providers.dart';
import '../../providers/torrent_providers.dart';
import '../../widgets/horizontal_scroller.dart';
import '../../widgets/selectable_chip.dart';

class MediaDetailScreen extends ConsumerWidget {
  const MediaDetailScreen({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    this.initialMedia,
  });

  final int tmdbId;
  final String mediaType;
  final MediaModel? initialMedia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(mediaDetailProvider((tmdbId, mediaType)));
    final media = detailAsync.value ?? initialMedia;

    if (media == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(backgroundColor: AppTheme.background),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, media),
          SliverToBoxAdapter(
            child: _DetailContent(
              media: media,
              tmdbId: tmdbId,
              detailLoaded: detailAsync.hasValue,
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, MediaModel media) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppTheme.background,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: InkWell(
          onTap: () => context.pop(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _BackdropImage(media: media),
      ),
    );
  }
}

// ── Backdrop ──────────────────────────────────────────────────────────────────

class _BackdropImage extends StatelessWidget {
  const _BackdropImage({required this.media});
  final MediaModel media;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (media.backdropUrl != null)
          Image.network(
            media.backdropUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppTheme.surface),
          )
        else
          Container(color: AppTheme.surface),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppTheme.background.withAlpha(204),
                  AppTheme.background,
                ],
                stops: const [0.4, 0.8, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Main content ──────────────────────────────────────────────────────────────

class _DetailContent extends ConsumerWidget {
  const _DetailContent({
    required this.media,
    required this.tmdbId,
    required this.detailLoaded,
  });

  final MediaModel media;
  final int tmdbId;
  final bool detailLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(media: media),
          const SizedBox(height: 16),
          if (media.genres.isNotEmpty) ...[
            _GenreChips(genres: media.genres),
            const SizedBox(height: 16),
          ],
          if (media.mediaType == 'tv' && detailLoaded) ...[
            _TvInfoRow(media: media),
            const SizedBox(height: 16),
          ],
          if (media.overview != null && media.overview!.isNotEmpty) ...[
            const Text(
              'Sinopsis',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              media.overview!,
              style: const TextStyle(
                color: AppTheme.onSurface,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
          ],
          _GetSourcesButton(media: media),
        ],
      ),
    );
  }
}

// ── Header: poster + title/year/rating/type ───────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.media});
  final MediaModel media;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 100,
            height: 150,
            child: media.posterUrl != null
                ? Image.network(media.posterUrl!, fit: BoxFit.cover)
                : Container(
                    color: AppTheme.surfaceVariant,
                    child: const Icon(
                      Icons.movie_outlined,
                      color: AppTheme.onSurfaceVariant,
                      size: 40,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                media.displayTitle,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (media.displayYear != null) ...[
                    Text(
                      media.displayYear!,
                      style: const TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (media.voteAverage > 0) ...[
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      media.voteAverage.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppTheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: media.mediaType == 'tv'
                      ? AppTheme.accent.withAlpha(38)
                      : AppTheme.primary.withAlpha(38),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: media.mediaType == 'tv'
                        ? AppTheme.accent.withAlpha(153)
                        : AppTheme.primary.withAlpha(153),
                  ),
                ),
                child: Text(
                  media.mediaType == 'tv' ? 'Serie' : 'Película',
                  style: TextStyle(
                    color: media.mediaType == 'tv'
                        ? AppTheme.accent
                        : AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Genre chips ───────────────────────────────────────────────────────────────

class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.genres});
  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: genres.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            genres[i],
            style: const TextStyle(
              color: AppTheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── TV info: status + seasons ─────────────────────────────────────────────────

class _TvInfoRow extends StatelessWidget {
  const _TvInfoRow({required this.media});
  final MediaModel media;

  Color get _statusColor {
    switch (media.status) {
      case 'En emisión':
        return Colors.green;
      case 'Finalizada':
        return Colors.grey;
      case 'Cancelada':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String get _statusLabel {
    switch (media.status) {
      case 'En emisión':
        return 'En emisión';
      case 'Cancelada':
        return 'Cancelada';
      default:
        return media.status ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (media.status != null && media.status!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor.withAlpha(38),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _statusColor.withAlpha(153)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (media.numberOfSeasons != null)
          Text(
            '${media.numberOfSeasons} temporada${media.numberOfSeasons != 1 ? 's' : ''}',
            style:
                const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14),
          ),
      ],
    );
  }
}

// ── Get Sources button ────────────────────────────────────────────────────────

class _GetSourcesButton extends StatelessWidget {
  const _GetSourcesButton({required this.media});
  final MediaModel media;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _onPressed(context),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Buscar fuentes'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _onPressed(BuildContext context) {
    if (media.mediaType == 'tv') {
      _showEpisodePicker(context);
    } else {
      _showSourcesSheet(context);
    }
  }

  void _showEpisodePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EpisodePickerSheet(
        media: media,
        onConfirm: (season, episode) {
          Navigator.pop(ctx);
          _showSourcesSheet(context, season: season, episode: episode);
        },
      ),
    );
  }

  void _showSourcesSheet(BuildContext context, {int? season, int? episode}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _SourcesSheet(media: media, season: season, episode: episode),
    );
  }
}

// ── Episode picker (TV only) ──────────────────────────────────────────────────

class _EpisodePickerSheet extends StatefulWidget {
  const _EpisodePickerSheet({required this.media, required this.onConfirm});
  final MediaModel media;
  final void Function(int season, int episode) onConfirm;

  @override
  State<_EpisodePickerSheet> createState() => _EpisodePickerSheetState();
}

class _EpisodePickerSheetState extends State<_EpisodePickerSheet> {
  int _season = 1;
  int _episode = 1;

  @override
  Widget build(BuildContext context) {
    final maxSeason = widget.media.numberOfSeasons ?? 50;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Elegir episodio',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Temporada',
                        style: TextStyle(
                            color: AppTheme.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 8),
                    _NumberPicker(
                      value: _season,
                      min: 1,
                      max: maxSeason,
                      onChanged: (v) => setState(() => _season = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Episodio',
                        style: TextStyle(
                            color: AppTheme.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 8),
                    _NumberPicker(
                      value: _episode,
                      min: 1,
                      max: 99,
                      onChanged: (v) => setState(() => _episode = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onConfirm(_season, _episode),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Buscar fuentes — T${_season.toString().padLeft(2, '0')}E${_episode.toString().padLeft(2, '0')}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberPicker extends StatelessWidget {
  const _NumberPicker({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded, color: AppTheme.onSurface),
          ),
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded, color: AppTheme.onSurface),
          ),
        ],
      ),
    );
  }
}

// ── Sources bottom sheet ──────────────────────────────────────────────────────

class _SourcesSheet extends ConsumerWidget {
  const _SourcesSheet({required this.media, this.season, this.episode});
  final MediaModel media;
  final int? season;
  final int? episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tvArgs = (media.id, media.mediaType, season ?? 1, episode ?? 1);
    final sourcesAsync = (season != null && episode != null)
        ? ref.watch(tvEpisodeSourcesProvider(tvArgs))
        : ref.watch(streamSourcesProvider(media));

    void retry() {
      if (season != null && episode != null) {
        ref.invalidate(tvEpisodeSourcesProvider(tvArgs));
      } else {
        ref.invalidate(streamSourcesProvider(media));
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.onSurfaceVariant.withAlpha(102),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                season != null
                    ? '${media.displayTitle} — S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}'
                    : media.displayTitle,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: sourcesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
                error: (_, _) => _SourcesError(onRetry: retry),
                data: (sources) {
                  if (sources.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 48, color: AppTheme.onSurfaceVariant),
                          SizedBox(height: 12),
                          Text(
                            'No se han encontrado fuentes',
                            style: TextStyle(color: AppTheme.onSurface),
                          ),
                        ],
                      ),
                    );
                  }
                  final selected = ref.watch(sourceLanguagesProvider);
                  final languages = {
                    for (final s in sources) s: s.audioLanguageCodes,
                  };
                  final shown = selected.isEmpty
                      ? sources
                      : sources
                          .where((s) => languages[s]!.any(selected.contains))
                          .toList();
                  return Column(
                    children: [
                      _LanguageFilterBar(
                        languages: languages.values,
                        total: sources.length,
                        selected: selected,
                      ),
                      Expanded(
                        child: shown.isEmpty
                            ? _NoSourcesInLanguages(
                                total: sources.length,
                                onShowAll: () => ref
                                    .read(sourceLanguagesProvider.notifier)
                                    .clear(),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: shown.length,
                                separatorBuilder: (_, _) => const Divider(
                                    height: 1, indent: 16, endIndent: 16),
                                itemBuilder: (_, i) => _SourceTile(
                                  source: shown[i],
                                  languages: languages[shown[i]]!,
                                  media: media,
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Audio-language filter ─────────────────────────────────────────────────────

/// A row of chips, one per audio language found in the sources, with its
/// flag and how many sources have it. Tapping chips picks the languages to
/// show; "Todos" clears the filter.
class _LanguageFilterBar extends ConsumerWidget {
  const _LanguageFilterBar({
    required this.languages,
    required this.total,
    required this.selected,
  });

  final Iterable<List<String>> languages;
  final int total;
  final Set<String> selected;

  /// Languages that always go first, in this order, when present.
  static const _pinned = ['ES', 'MX', 'GB'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = <String, int>{};
    for (final codes in languages) {
      for (final c in codes) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    // Keep chosen languages visible even when this title has none of them,
    // so they can still be turned off.
    for (final c in selected) {
      counts.putIfAbsent(c, () => 0);
    }

    int rank(String c) {
      final pinned = _pinned.indexOf(c);
      if (pinned >= 0) return pinned;
      if (c == AudioLanguage.unknownCode) return 1 << 20;
      return _pinned.length;
    }

    final codes = counts.keys.toList()
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        return counts[b]!.compareTo(counts[a]!);
      });
    final notifier = ref.read(sourceLanguagesProvider.notifier);

    return HorizontalScroller(
      height: 60,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      wheelScrollsSideways: true,
      scrollbarAlwaysVisible: true,
      itemCount: codes.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return SelectableChip(
            selected: selected.isEmpty,
            onSelected: (_) => notifier.clear(),
            avatar: const Icon(Icons.public_rounded, size: 18),
            label: 'Todos ($total)',
          );
        }
        final code = codes[i - 1];
        return SelectableChip(
          selected: selected.contains(code),
          onSelected: (_) => notifier.toggle(code),
          avatar: LanguageFlag(code: code, height: 14),
          label: '${AudioLanguage.byCode(code).name} (${counts[code]})',
        );
      },
    );
  }
}

/// The flag of an audio language, drawn as an image so it also shows on
/// Windows, whose emoji font has no flags.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({super.key, required this.code, this.height = 12});

  final String code;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height * 4 / 3;
    if (code == AudioLanguage.unknownCode ||
        FlagCode.fromCountryCode(code) == null) {
      return SizedBox(
        width: width,
        height: height,
        child: Icon(
          Icons.help_outline_rounded,
          size: height,
          color: AppTheme.onSurfaceVariant,
        ),
      );
    }
    return Tooltip(
      message: AudioLanguage.byCode(code).name,
      child: CountryFlag.fromCountryCode(
        code,
        theme: ImageTheme(
          width: width,
          height: height,
          shape: const RoundedRectangle(2),
        ),
      ),
    );
  }
}

class _NoSourcesInLanguages extends StatelessWidget {
  const _NoSourcesInLanguages({required this.total, required this.onShowAll});

  final int total;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volume_off_rounded,
                size: 48, color: AppTheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text(
              'No hay fuentes con audio en los idiomas elegidos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.onSurface),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onShowAll,
              child: Text('Ver todas las fuentes ($total)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourcesError extends StatelessWidget {
  const _SourcesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppTheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text(
              'No se han podido cargar las fuentes',
              style: TextStyle(
                color: AppTheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
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

// ── Source tile ───────────────────────────────────────────────────────────────

class _SourceTile extends ConsumerWidget {
  const _SourceTile({
    required this.source,
    required this.languages,
    required this.media,
  });
  final StreamSourceModel source;
  final List<String> languages;
  final MediaModel media;

  Color get _qualityColor {
    switch (source.quality) {
      case '4K':
        return Colors.purple;
      case '1080p':
        return Colors.blue;
      case '720p':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: () => _addTorrent(context, ref),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _qualityColor.withAlpha(38),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _qualityColor.withAlpha(153)),
        ),
        child: Text(
          source.quality,
          style: TextStyle(
            color: _qualityColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        source.name,
        style: const TextStyle(
          color: AppTheme.onBackground,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _SourceMeta(source: source, languages: languages),
      trailing: const Icon(Icons.download_rounded, color: AppTheme.primary),
    );
  }

  Future<void> _addTorrent(BuildContext context, WidgetRef ref) async {
    final magnet = source.resolvedMagnetUrl;
    if (magnet == null) return;

    final torrentId =
        await ref.read(torrentsProvider.notifier).addMagnet(magnet);
    if (!context.mounted) return;

    Navigator.of(context).pop();
    // Go straight to the pre-load screen; it opens the player when ready.
    GoRouter.of(context).push('/prepare', extra: {
      'torrentId': torrentId,
      'title': media.displayTitle,
      'backdropUrl': media.backdropUrl,
      'posterUrl': media.posterUrl,
      'fileName': source.behaviorHintsFilename,
    });
  }
}

class _SourceMeta extends StatelessWidget {
  const _SourceMeta({required this.source, required this.languages});

  final StreamSourceModel source;
  final List<String> languages;

  /// Flags shown before collapsing the rest into "+N".
  static const _maxFlags = 8;

  @override
  Widget build(BuildContext context) {
    final seeders = source.seeders;
    final flags =
        languages.where((c) => c != AudioLanguage.unknownCode).toList();
    final extra = flags.length - _maxFlags;
    final subtitles = source.subtitleLanguageCodes;
    final extraSubtitles = subtitles.length - _maxFlags;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (seeders != null)
            Text(
              '$seeders semillas',
              style: const TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          if (source.hasMultiAudioTag) const _SourceBadge(label: 'MULTi'),
          ...flags.take(_maxFlags).map((c) => LanguageFlag(code: c)),
          if (extra > 0)
            Text(
              '+$extra',
              style: const TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          if (subtitles.isNotEmpty)
            Tooltip(
              message: 'Subtítulos (probablemente): '
                  '${subtitles.map((c) => AudioLanguage.byCode(c).name).join(', ')}',
              child: Opacity(
                opacity: 0.55,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.closed_caption_outlined,
                      size: 16,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    for (final c in subtitles.take(_maxFlags)) ...[
                      const SizedBox(width: 4),
                      LanguageFlag(code: c, height: 10),
                    ],
                    if (extraSubtitles > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '+$extraSubtitles',
                        style: const TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
