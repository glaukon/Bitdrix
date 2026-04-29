/// TMDB API constants.
///
/// Replace [apiReadAccessToken] with your own token from
/// https://www.themoviedb.org/settings/api
class TmdbConstants {
  TmdbConstants._();

  static const String apiKey = 'apiKey';
  static const String apiReadAccessToken = 'apiReadAccessToken';

  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p';
  static const String posterSize = 'w342';
  static const String backdropSize = 'w780';
  static const String profileSize = 'w185';
}
