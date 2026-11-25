import 'package:dio/dio.dart';

import '../../core/constants/tmdb_constants.dart';
import '../models/media_model.dart';

/// Thrown when Discover is used before a TMDB credential is configured.
class TmdbMissingKeyException implements Exception {
  const TmdbMissingKeyException();

  @override
  String toString() => 'No TMDB API key configured.';
}

/// Service for fetching data from the TMDB REST API (v3).
///
/// [credential] may be a v3 API key (sent as the `api_key` query parameter) or
/// a v4 Read Access Token (a JWT, sent as a Bearer `Authorization` header).
class TmdbService {
  TmdbService(String credential) {
    final key = credential.trim();
    final isToken = key.startsWith('eyJ');
    _dio = Dio(
      BaseOptions(
        baseUrl: TmdbConstants.baseUrl,
        queryParameters: {if (key.isNotEmpty && !isToken) 'api_key': key},
        headers: {if (isToken) 'Authorization': 'Bearer $key'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    if (key.isEmpty) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(DioException(
          requestOptions: options,
          error: const TmdbMissingKeyException(),
        )),
      ));
    }
  }

  late final Dio _dio;

  /// True when TMDB rejected the credential or none is configured.
  static bool isAuthError(Object error) {
    if (error is TmdbMissingKeyException) return true;
    if (error is DioException) {
      return error.error is TmdbMissingKeyException ||
          error.response?.statusCode == 401;
    }
    return false;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns movies currently playing in theaters for the configured region.
  Future<List<MediaModel>> getNowPlayingMovies({int page = 1}) async {
    final response = await _dio.get(
      '/movie/now_playing',
      queryParameters: {
        'page': page,
        'language': 'en-US',
        'region': 'ES',
      },
    );
    return _parseResults(response.data, forceMediaType: 'movie');
  }

  /// Returns upcoming theatrical movies for the configured region.
  Future<List<MediaModel>> getUpcomingMovies({int page = 1}) async {
    final response = await _dio.get(
      '/movie/upcoming',
      queryParameters: {
        'page': page,
        'language': 'en-US',
        'region': 'ES',
      },
    );
    return _parseResults(response.data, forceMediaType: 'movie');
  }

  /// Returns TV shows currently airing.
  Future<List<MediaModel>> getOnTheAirTvShows({int page = 1}) async {
    final response = await _dio.get(
      '/tv/on_the_air',
      queryParameters: {'page': page, 'language': 'en-US'},
    );
    return _parseResults(response.data, forceMediaType: 'tv');
  }

  /// Returns trending movies and TV shows for the given time window.
  ///
  /// [timeWindow] must be `'day'` or `'week'`.
  Future<List<MediaModel>> getTrending({String timeWindow = 'week'}) async {
    final response = await _dio.get(
      '/trending/all/$timeWindow',
      queryParameters: {'language': 'en-US'},
    );
    return _parseResults(response.data);
  }

  /// Searches TMDB for movies and TV shows matching [query].
  ///
  /// Returns an empty list when [query] is blank.
  Future<List<MediaModel>> search(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];

    final response = await _dio.get(
      '/search/multi',
      queryParameters: {
        'query': query.trim(),
        'include_adult': false,
        'language': 'en-US',
        'page': page,
      },
    );

    final all = _parseResults(response.data);
    // Filter to only movie and tv — exclude person results, etc.
    return all.where((m) => m.mediaType == 'movie' || m.mediaType == 'tv').toList();
  }

  /// Returns the IMDB identifier for a TMDB title.
  ///
  /// Returns `null` if the IMDB ID is not available.
  Future<String?> getImdbId(int tmdbId, String mediaType) async {
    try {
      final path = mediaType == 'tv'
          ? '/tv/$tmdbId/external_ids'
          : '/movie/$tmdbId/external_ids';
      final response = await _dio.get(path);
      final data = response.data as Map<String, dynamic>;
      return data['imdb_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Fetches full details for a single movie or TV show.
  Future<MediaModel> getDetails(int tmdbId, String mediaType) async {
    final path = mediaType == 'tv' ? '/tv/$tmdbId' : '/movie/$tmdbId';
    final response = await _dio.get(
      path,
      queryParameters: {'language': 'en-US'},
    );
    final json = response.data as Map<String, dynamic>;
    // Inject media_type so fromJson resolves the correct field names.
    json['media_type'] = mediaType;
    return MediaModel.fromJson(json);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<MediaModel> _parseResults(
    dynamic data, {
    String? forceMediaType,
  }) {
    final map = data as Map<String, dynamic>;
    final results = map['results'] as List<dynamic>? ?? [];
    return results.map((item) {
      final json = Map<String, dynamic>.from(item as Map);
      if (forceMediaType != null) {
        json['media_type'] = forceMediaType;
      }
      return MediaModel.fromJson(json);
    }).toList();
  }
}
