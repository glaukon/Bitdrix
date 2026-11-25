import '../../core/constants/tmdb_constants.dart';

/// Represents a movie or TV show returned by the TMDB API.
class MediaModel {
  const MediaModel({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    required this.voteAverage,
    required this.mediaType,
    this.imdbId,
    this.status,
    this.numberOfSeasons,
    this.genres = const [],
  });

  final int id;

  /// Human-readable title (resolved from `title` for movies or `name` for TV).
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;

  /// ISO-8601 date string. For movies: `release_date`; for TV: `first_air_date`.
  final String? releaseDate;
  final double voteAverage;

  /// Either `'movie'` or `'tv'`.
  final String mediaType;

  /// IMDB identifier — populated separately via `/external_ids`.
  final String? imdbId;

  /// TV status: "Returning Series", "Ended", "Canceled", etc.
  final String? status;

  /// Number of seasons — only set for TV shows.
  final int? numberOfSeasons;

  /// Genre names, e.g. ["Action", "Drama"].
  final List<String> genres;

  // ── Getters ──────────────────────────────────────────────────────────────────

  String? get posterUrl {
    if (posterPath == null) return null;
    return '${TmdbConstants.imageBaseUrl}/${TmdbConstants.posterSize}$posterPath';
  }

  String? get backdropUrl {
    if (backdropPath == null) return null;
    return '${TmdbConstants.imageBaseUrl}/${TmdbConstants.backdropSize}$backdropPath';
  }

  /// The display title (same as [title] — kept for API symmetry).
  String get displayTitle => title;

  /// Four-digit year string extracted from [releaseDate], or `null`.
  String? get displayYear {
    if (releaseDate == null || releaseDate!.length < 4) return null;
    return releaseDate!.substring(0, 4);
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    // TMDB returns different field names for movies vs TV shows.
    // In /trending/all and /search/multi the `media_type` field is included.
    // In /movie/popular and /tv/popular it is not included, so we use a fallback.
    final rawMediaType = json['media_type'] as String?;

    // Detect whether this is a TV show by the presence of the `name` key.
    final isTV = rawMediaType == 'tv' ||
        (rawMediaType == null && json.containsKey('name'));

    final mediaType = isTV ? 'tv' : 'movie';

    final titleRaw = isTV
        ? (json['name'] as String? ?? json['original_name'] as String? ?? '')
        : (json['title'] as String? ?? json['original_title'] as String? ?? '');

    final releaseDateRaw = isTV
        ? json['first_air_date'] as String?
        : json['release_date'] as String?;

    final rawGenres = json['genres'] as List<dynamic>?;
    final genres = rawGenres
            ?.map((g) => (g as Map<String, dynamic>)['name'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    return MediaModel(
      id: (json['id'] as num).toInt(),
      title: titleRaw,
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: releaseDateRaw,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      mediaType: mediaType,
      imdbId: json['imdb_id'] as String?,
      status: json['status'] as String?,
      numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt(),
      genres: genres,
    );
  }

  /// The inverse of [MediaModel.fromJson]: TV shows use TMDB's `name` and
  /// `first_air_date` keys, movies `title` and `release_date`.
  Map<String, dynamic> toJson() => {
        'id': id,
        if (mediaType == 'tv') 'name': title else 'title': title,
        'overview': overview,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        if (mediaType == 'tv')
          'first_air_date': releaseDate
        else
          'release_date': releaseDate,
        'vote_average': voteAverage,
        'media_type': mediaType,
        'imdb_id': imdbId,
        'status': status,
        'number_of_seasons': numberOfSeasons,
        'genres': genres.map((g) => {'name': g}).toList(),
      };

  MediaModel copyWith({
    int? id,
    String? title,
    String? overview,
    String? posterPath,
    String? backdropPath,
    String? releaseDate,
    double? voteAverage,
    String? mediaType,
    String? imdbId,
    String? status,
    int? numberOfSeasons,
    List<String>? genres,
  }) {
    return MediaModel(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      releaseDate: releaseDate ?? this.releaseDate,
      voteAverage: voteAverage ?? this.voteAverage,
      mediaType: mediaType ?? this.mediaType,
      imdbId: imdbId ?? this.imdbId,
      status: status ?? this.status,
      numberOfSeasons: numberOfSeasons ?? this.numberOfSeasons,
      genres: genres ?? this.genres,
    );
  }
}
