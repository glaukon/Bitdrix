import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_language.dart';
import '../../data/models/media_model.dart';
import '../../data/models/stream_source_model.dart';
import '../../data/services/tmdb_service.dart';
import '../../data/services/torrentio_service.dart';
import 'settings_providers.dart';

// ── Service providers ─────────────────────────────────────────────────────────

final tmdbServiceProvider = Provider<TmdbService>((ref) => TmdbService());

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
final searchQueryProvider = StateProvider<String>((ref) => '');

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

/// Scores sources so likely Spanish / multi-audio files appear first while
/// keeping seeders as the tie-breaker.
List<StreamSourceModel> _rankSources(
  List<StreamSourceModel> sources,
  AppLanguage lang,
) {
  return [...sources]..sort((a, b) {
      final scoreDiff = _sourceScore(b, lang).compareTo(_sourceScore(a, lang));
      if (scoreDiff != 0) return scoreDiff;

      final sa = a.seeders;
      final sb = b.seeders;
      if (sa == null && sb == null) return 0;
      if (sa == null) return 1;
      if (sb == null) return -1;
      return sb.compareTo(sa);
    });
}

int _sourceScore(StreamSourceModel source, AppLanguage lang) {
  var score = 0;

  if (source.hasCastilianAudioTag) score += 1400;
  if (source.hasGenericSpanishAudioTag) score += 850;
  if (source.hasLatinSpanishAudioTag) score += 300;
  if (source.hasMultiAudioTag) score += 650;

  if (!lang.isAny) {
    final text = source.searchableText;
    if (lang.keywords.any((kw) => text.contains(kw))) score += 500;
  }

  switch (source.quality) {
    case '4K':
      score += 80;
      break;
    case '1080p':
      score += 60;
      break;
    case '720p':
      score += 35;
      break;
  }

  score += (source.seeders ?? 0).clamp(0, 500);
  return score;
}

/// Fetches and sorts available torrent sources for the given [MediaModel].
///
/// Steps:
/// 1. Resolves the IMDB ID from TMDB (needed by Torrentio).
/// 2. Fetches the stream list from Torrentio.
/// 3. Sorts by seeder count descending (null seeders go last).
/// 4. Moves sources that match the user's preferred language to the top.
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
