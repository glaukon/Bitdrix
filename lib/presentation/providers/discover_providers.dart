import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_language.dart';
import '../../data/models/media_model.dart';
import '../../data/models/stream_source_model.dart';
import '../../data/services/tmdb_service.dart';
import '../../data/services/torrentio_service.dart';
import 'settings_providers.dart';

// ── Service providers ─────────────────────────────────────────────────────────

final tmdbServiceProvider = Provider<TmdbService>(
  (ref) => TmdbService(ref.watch(tmdbApiKeyProvider)),
);

final torrentioServiceProvider =
    Provider<TorrentioService>((ref) => TorrentioService());

// ── Content providers ─────────────────────────────────────────────────────────

/// Daily trending movies and TV shows from TMDB.
final trendingProvider =
    FutureProvider.autoDispose<List<MediaModel>>((ref) async {
  return ref.watch(tmdbServiceProvider).getTrending(timeWindow: 'day');
});

/// Movies currently in theaters from TMDB.
final nowPlayingMoviesProvider =
    FutureProvider.autoDispose<List<MediaModel>>((ref) async {
  return ref.watch(tmdbServiceProvider).getNowPlayingMovies();
});

/// Upcoming movies from TMDB.
final upcomingMoviesProvider =
    FutureProvider.autoDispose<List<MediaModel>>((ref) async {
  return ref.watch(tmdbServiceProvider).getUpcomingMovies();
});

/// TV shows currently airing from TMDB.
final onTheAirTvProvider =
    FutureProvider.autoDispose<List<MediaModel>>((ref) async {
  return ref.watch(tmdbServiceProvider).getOnTheAirTvShows();
});

// ── Search ────────────────────────────────────────────────────────────────────

/// Holds the current search query string.
final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

/// Search results derived from [searchQueryProvider].
///
/// Returns an empty list immediately when the query is blank so the UI can
/// fall back to the trending grid without a loading flicker.
final searchResultsProvider = FutureProvider<List<MediaModel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  return ref.watch(tmdbServiceProvider).search(query);
});

// ── Detail ────────────────────────────────────────────────────────────────────

/// Full TMDB details for a single title (includes genres, status, seasons).
final mediaDetailProvider =
    FutureProvider.family<MediaModel, (int, String)>((ref, args) async {
  final (tmdbId, mediaType) = args;
  return ref.watch(tmdbServiceProvider).getDetails(tmdbId, mediaType);
});

// ── Stream sources ────────────────────────────────────────────────────────────

const _qualityRank = {'4K': 4, '1080p': 3, '720p': 2, '480p': 1};

/// Default order for movies and series: highest quality first (4K → 1080p →
/// 720p → 480p → unknown) and, within the same quality, most seeders first.
/// The preferred-language setting only breaks exact ties.
List<StreamSourceModel> _rankSources(
  List<StreamSourceModel> sources,
  AppLanguage lang,
) {
  bool matchesLanguage(StreamSourceModel s) =>
      !lang.isAny && lang.keywords.any((kw) => s.searchableText.contains(kw));

  return [...sources]..sort((a, b) {
      final quality = (_qualityRank[b.quality] ?? 0)
          .compareTo(_qualityRank[a.quality] ?? 0);
      if (quality != 0) return quality;

      final seeders = (b.seeders ?? -1).compareTo(a.seeders ?? -1);
      if (seeders != 0) return seeders;

      return (matchesLanguage(b) ? 1 : 0).compareTo(matchesLanguage(a) ? 1 : 0);
    });
}

/// Fetches and sorts available torrent sources for the given [MediaModel].
///
/// Steps:
/// 1. Resolves the IMDB ID from TMDB (needed by Torrentio).
/// 2. Fetches the stream list from Torrentio.
/// 3. Sorts by quality, then seeders (see [_rankSources]).
final streamSourcesProvider =
    FutureProvider.family<List<StreamSourceModel>, MediaModel>(
        (ref, media) async {
  final tmdb = ref.watch(tmdbServiceProvider);
  final torrentio = ref.watch(torrentioServiceProvider);
  final lang = ref.watch(languagePreferenceProvider);

  final imdbId = await tmdb.getImdbId(media.id, media.mediaType);
  if (imdbId == null || imdbId.isEmpty) return [];

  final sources = await torrentio.getSources(imdbId, media.mediaType);
  return _rankSources(sources, lang);
});

/// Torrent sources for a specific TV episode (season + episode required).
final tvEpisodeSourcesProvider =
    FutureProvider.family<List<StreamSourceModel>, (int, String, int, int)>(
        (ref, args) async {
  final (tmdbId, mediaType, season, episode) = args;
  final tmdb = ref.watch(tmdbServiceProvider);
  final torrentio = ref.watch(torrentioServiceProvider);
  final lang = ref.watch(languagePreferenceProvider);

  final imdbId = await tmdb.getImdbId(tmdbId, mediaType);
  if (imdbId == null || imdbId.isEmpty) return [];

  final sources = await torrentio.getSources(
    imdbId,
    mediaType,
    season: season,
    episode: episode,
  );

  return _rankSources(sources, lang);
});
