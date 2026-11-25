/// TMDB API constants.
///
/// The credential itself is configured by the user in Settings (or with
/// `--dart-define=TMDB_API_KEY=...`); get one at
/// https://www.themoviedb.org/settings/api
class TmdbConstants {
  TmdbConstants._();

  static const String apiSettingsUrl = 'https://www.themoviedb.org/settings/api';

  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p';
  static const String posterSize = 'w342';
  static const String backdropSize = 'w780';
  static const String profileSize = 'w185';
}
