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
import '../../providers/favorites_providers.dart';
import '../../providers/torrent_providers.dart';
import '../../widgets/horizontal_scroller.dart';
import '../../widgets/media_rows.dart';
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

  /// From this width on, poster and text sit side by side.
  static const _wideBreakpoint = 820.0;

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

    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= _wideBreakpoint;
    // Big windows get everything bigger, not just more empty space.
    final scale = wide ? (size.width / 1300).clamp(1.0, 1.35) : 1.0;
    final maxContentWidth = 1400 * scale;
    // The backdrop fills the top of the screen and fades into the page.
    final backdropHeight = wide ? size.height * 0.78 : size.width * 9 / 16 + 60;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: backdropHeight,
            child: _Backdrop(media: media, wide: wide),
          ),
          MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: ListView(
              padding: EdgeInsets.only(
                top: wide ? backdropHeight * 0.3 : backdropHeight - 90,
                bottom: 40,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 16),
                      child: wide
                          ? _WideHero(media: media, scale: scale)
                          : _NarrowHero(media: media),
                    ),
                  ),
                ),
                if (media.cast.isNotEmpty)
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 36 * scale,
                          left: wide ? 32 : 0,
                          right: wide ? 32 : 0,
                        ),
                        child: _CastRow(cast: media.cast, scale: scale),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Floating back button over the picture.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Volver',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Backdrop ──────────────────────────────────────────────────────────────────

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.media, required this.wide});

  final MediaModel media;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final url = media.backdropUrl ?? media.posterUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          Image.network(
            url,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        // Fade into the page at the bottom…
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x33000000),
                Color(0x00000000),
                Color(0xCC0D0D14),
                AppTheme.background,
              ],
              stops: [0, 0.3, 0.75, 1],
            ),
          ),
        ),
        // …and on the left, where the text sits on wide screens.
        if (wide)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xEE0D0D14), Color(0x000D0D14)],
                stops: [0, 0.65],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Hero: poster + information + actions ─────────────────────────────────────

class _WideHero extends StatelessWidget {
  const _WideHero({required this.media, required this.scale});

  final MediaModel media;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Poster(media: media, width: 280 * scale),
        SizedBox(width: 40 * scale),
        Expanded(
          child: _Info(media: media, titleSize: 44, scale: scale),
        ),
      ],
    );
  }
}

class _NarrowHero extends StatelessWidget {
  const _NarrowHero({required this.media});

  final MediaModel media;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Poster(media: media, width: 120),
            const SizedBox(width: 16),
            Expanded(child: _Title(media: media, size: 24)),
          ],
        ),
        const SizedBox(height: 16),
        _Info(media: media, titleSize: 0),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.media, required this.width});

  final MediaModel media;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 1.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: media.posterUrl == null
          ? const ColoredBox(
              color: AppTheme.surfaceVariant,
              child: Icon(
                Icons.movie_rounded,
                size: 48,
                color: AppTheme.onSurfaceVariant,
              ),
            )
          : Image.network(
              media.posterUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppTheme.surfaceVariant),
            ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.media, required this.size});

  final MediaModel media;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          media.displayTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        if (media.tagline != null) ...[
          const SizedBox(height: 8),
          Text(
            media.tagline!,
            style: TextStyle(
              color: Colors.white70,
              fontSize: size * 0.42,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

/// Title (on wide screens), facts, genres, synopsis, people and buttons.
class _Info extends StatelessWidget {
  const _Info({required this.media, required this.titleSize, this.scale = 1});

  final MediaModel media;
  final double scale;

  /// 0 when the title is shown elsewhere (next to the poster on phones).
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final seasons = media.numberOfSeasons;
    final facts = <Widget>[
      if (media.displayYear != null) _Fact(media.displayYear!),
      if (media.displayRuntime != null) _Fact(media.displayRuntime!),
      if (media.voteAverage > 0)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            _Fact(media.voteAverage.toStringAsFixed(1)),
          ],
        ),
      if (seasons != null)
        _Fact('$seasons temporada${seasons == 1 ? '' : 's'}'),
      if (media.mediaType == 'tv' && media.displayStatus != null)
        _StatusBadge(status: media.displayStatus!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titleSize > 0) ...[
          _Title(media: media, size: titleSize),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: facts,
        ),
        if (media.genres.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in media.genres)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    g,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
            ],
          ),
        ],
        if (media.overview?.isNotEmpty ?? false) ...[
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 820 * scale),
            child: Text(
              media.overview!,
              style: const TextStyle(
                color: Color(0xE6FFFFFF),
                fontSize: 15,
                height: 1.55,
              ),
            ),
          ),
        ],
        if (media.directors.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: media.mediaType == 'tv'
                      ? 'Creada por  '
                      : 'Dirección  ',
                  style: const TextStyle(color: AppTheme.onSurfaceVariant),
                ),
                TextSpan(
                  text: media.directors.take(3).join(', '),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
        SizedBox(height: 26 * scale),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _GetSourcesButton(media: media, scale: scale),
            _FavoriteButton(media: media, scale: scale),
          ],
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'En emisión' => AppTheme.success,
      'Cancelada' => AppTheme.error,
      'Finalizada' => AppTheme.onSurfaceVariant,
      _ => AppTheme.accent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(153)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Adds the title to Favoritos, or takes it out.
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.media, this.scale = 1});

  final MediaModel media;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(favoriteMediaProvider);
    final favorites = ref.read(favoriteMediaProvider.notifier);
    final favorite = favorites.isFavorite(media);
    return OutlinedButton.icon(
      onPressed: () => favorites.toggle(media),
      icon: Icon(
        favorite ? Icons.star_rounded : Icons.star_outline_rounded,
        color: favorite ? Colors.amber : Colors.white,
        size: 24 * scale,
      ),
      label: Text(favorite ? 'En favoritos' : 'Favorito'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white38),
        padding: EdgeInsets.symmetric(
          horizontal: 24 * scale,
          vertical: 18 * scale,
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Cast ──────────────────────────────────────────────────────────────────────

class _CastRow extends StatelessWidget {
  const _CastRow({required this.cast, this.scale = 1});

  final List<CastMember> cast;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RowTitle('Reparto'),
        HorizontalScroller(
          height: 190 * scale,
          spacing: 18 * scale,
          itemCount: cast.length,
          itemBuilder: (_, i) {
            final c = cast[i];
            return SizedBox(
              width: 110 * scale,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50 * scale,
                    backgroundColor: AppTheme.surfaceVariant,
                    foregroundImage: c.photoUrl == null
                        ? null
                        : NetworkImage(c.photoUrl!),
                    child: Text(
                      c.name.isEmpty ? '?' : c.name[0],
                      style: const TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (c.character?.isNotEmpty ?? false)
                    Text(
                      c.character!,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Get Sources button ────────────────────────────────────────────────────────

class _GetSourcesButton extends StatelessWidget {
  const _GetSourcesButton({required this.media, this.scale = 1});
  final MediaModel media;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isTv = media.mediaType == 'tv';
    return FilledButton.icon(
      onPressed: () => _onPressed(context),
      icon: Icon(
        isTv ? Icons.playlist_play_rounded : Icons.play_arrow_rounded,
        size: 28 * scale,
      ),
      label: Text(isTv ? 'Elegir episodio' : 'Ver ahora'),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: 30 * scale,
          vertical: 18 * scale,
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
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
                    const Text(
                      'Temporada',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
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
                    const Text(
                      'Episodio',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Buscar fuentes — T${_season.toString().padLeft(2, '0')}E${_episode.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
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
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: AppTheme.onSurfaceVariant,
                          ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: shown.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
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
            const Icon(
              Icons.volume_off_rounded,
              size: 48,
              color: AppTheme.onSurfaceVariant,
            ),
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

    final torrentId = await ref
        .read(torrentsProvider.notifier)
        .addMagnet(magnet);
    if (!context.mounted) return;

    Navigator.of(context).pop();
    // Go straight to the pre-load screen; it opens the player when ready.
    GoRouter.of(context).push(
      '/prepare',
      extra: {
        'torrentId': torrentId,
        'title': media.displayTitle,
        'backdropUrl': media.backdropUrl,
        'posterUrl': media.posterUrl,
        'fileName': source.behaviorHintsFilename,
      },
    );
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
    final flags = languages
        .where((c) => c != AudioLanguage.unknownCode)
        .toList();
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
              message:
                  'Subtítulos (probablemente): '
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
