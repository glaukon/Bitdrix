import '../../core/constants/tmdb_constants.dart';
import 'media_model.dart';

/// The extra facts of a title's detail page, read from TMDB's details
/// response with `append_to_response` (credits, videos, recommendations,
/// watch/providers, release_dates / content_ratings).
class MediaDetails {
  const MediaDetails({
    this.originalTitle,
    this.originalLanguage,
    this.countries = const [],
    this.certification,
    this.companies = const [],
    this.writers = const [],
    this.budget,
    this.revenue,
    this.trailerKey,
    this.providers = const [],
    this.seasons = const [],
    this.nextEpisode,
    this.recommendations = const [],
  });

  /// Only when it differs from the Castilian title.
  final String? originalTitle;

  /// Castilian name of the original language ("Inglés").
  final String? originalLanguage;

  /// Production (movies) or origin (TV) countries, in Castilian.
  final List<String> countries;

  /// Spanish age rating ("12", "16", "TP"…).
  final String? certification;

  /// Production companies (movies) or networks (TV).
  final List<String> companies;
  final List<String> writers;

  /// In US dollars; null when TMDB has none.
  final int? budget;
  final int? revenue;

  /// YouTube id of the best trailer (Castilian first).
  final String? trailerKey;

  /// Subscription services that include the title in Spain.
  final List<WatchProvider> providers;
  final List<SeasonInfo> seasons;
  final NextEpisode? nextEpisode;
  final List<MediaModel> recommendations;

  bool get isEmpty =>
      originalTitle == null &&
      originalLanguage == null &&
      countries.isEmpty &&
      certification == null &&
      companies.isEmpty &&
      writers.isEmpty &&
      budget == null &&
      revenue == null;

  factory MediaDetails.fromJson(
    Map<String, dynamic> json, {
    required String mediaType,
    required String title,
  }) {
    final isTv = mediaType == 'tv';
    List<Map<String, dynamic>> list(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is Map<String, dynamic>) e,
    ];
    String? str(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    int? money(Object? v) => v is num && v > 0 ? v.toInt() : null;

    final original = str(json[isTv ? 'original_name' : 'original_title']);
    final languageCode = str(json['original_language']);

    final countryCodes = isTv
        ? [
            for (final c in json['origin_country'] as List<dynamic>? ?? [])
              if (c is String) c,
          ]
        : [
            for (final c in list(json['production_countries']))
              if (str(c['iso_3166_1']) != null) c['iso_3166_1'] as String,
          ];

    // Spanish age rating.
    String? certification;
    if (isTv) {
      for (final r in list((json['content_ratings'] as Map?)?['results'])) {
        if (r['iso_3166_1'] == 'ES') certification = str(r['rating']);
      }
    } else {
      for (final r in list((json['release_dates'] as Map?)?['results'])) {
        if (r['iso_3166_1'] != 'ES') continue;
        for (final d in list(r['release_dates'])) {
          certification ??= str(d['certification']);
        }
      }
    }

    // Trailer: YouTube, Castilian first, then any language.
    final videos = list((json['videos'] as Map?)?['results'])
        .where((v) => v['site'] == 'YouTube' && str(v['key']) != null)
        .toList();
    int videoRank(Map<String, dynamic> v) =>
        (v['type'] == 'Trailer'
            ? 0
            : v['type'] == 'Teaser'
            ? 2
            : 4) +
        (v['iso_639_1'] == 'es' ? 0 : 1);
    videos.sort((a, b) => videoRank(a).compareTo(videoRank(b)));
    final trailer = videos
        .where((v) => v['type'] == 'Trailer' || v['type'] == 'Teaser')
        .firstOrNull;

    final providersEs = (json['watch/providers'] as Map?)?['results'];
    final es = providersEs is Map ? providersEs['ES'] : null;
    final providers = <WatchProvider>[];
    if (es is Map) {
      for (final kind in const ['flatrate', 'free', 'ads']) {
        for (final p in list(es[kind])) {
          final name = str(p['provider_name']);
          if (name == null || providers.any((x) => x.name == name)) continue;
          providers.add(
            WatchProvider(name: name, logoPath: str(p['logo_path'])),
          );
        }
      }
    }

    final next = json['next_episode_to_air'];

    return MediaDetails(
      originalTitle: original != null && original != title ? original : null,
      originalLanguage: languageCode == null
          ? null
          : languageName(languageCode),
      countries: [for (final c in countryCodes) countryName(c)],
      certification: certification,
      companies: [
        for (final c in list(
          json[isTv ? 'networks' : 'production_companies'],
        ).take(4))
          if (str(c['name']) != null) c['name'] as String,
      ],
      writers: <String>{
        for (final c in list((json['credits'] as Map?)?['crew']))
          if (const {
                'Screenplay',
                'Writer',
                'Novel',
                'Story',
              }.contains(c['job']) &&
              str(c['name']) != null)
            c['name'] as String,
      }.take(4).toList(),
      budget: isTv ? null : money(json['budget']),
      revenue: isTv ? null : money(json['revenue']),
      trailerKey: trailer == null ? null : str(trailer['key']),
      providers: providers,
      seasons: [
        for (final s in list(json['seasons']))
          if (s['season_number'] is num && (s['season_number'] as num) > 0)
            SeasonInfo(
              number: (s['season_number'] as num).toInt(),
              name: str(s['name']) ?? 'Temporada ${s['season_number']}',
              episodeCount: (s['episode_count'] as num?)?.toInt(),
              airDate: str(s['air_date']),
              posterPath: str(s['poster_path']),
            ),
      ],
      nextEpisode: next is Map<String, dynamic> && str(next['air_date']) != null
          ? NextEpisode(
              season: (next['season_number'] as num?)?.toInt(),
              episode: (next['episode_number'] as num?)?.toInt(),
              name: str(next['name']),
              airDate: next['air_date'] as String,
            )
          : null,
      recommendations: [
        for (final r in list((json['recommendations'] as Map?)?['results']))
          MediaModel.fromJson({
            ...r,
            'media_type': r['media_type'] ?? mediaType,
          }),
      ].where((m) => m.posterPath != null).toList(),
    );
  }
}

class WatchProvider {
  const WatchProvider({required this.name, this.logoPath});

  final String name;
  final String? logoPath;

  String? get logoUrl =>
      logoPath == null ? null : '${TmdbConstants.imageBaseUrl}/w92$logoPath';
}

class SeasonInfo {
  const SeasonInfo({
    required this.number,
    required this.name,
    this.episodeCount,
    this.airDate,
    this.posterPath,
  });

  final int number;
  final String name;
  final int? episodeCount;
  final String? airDate;
  final String? posterPath;

  String? get year =>
      airDate != null && airDate!.length >= 4 ? airDate!.substring(0, 4) : null;

  String? get posterUrl => posterPath == null
      ? null
      : '${TmdbConstants.imageBaseUrl}/w185$posterPath';
}

/// One episode of a season, from TMDB's season endpoint.
class Episode {
  const Episode({
    required this.season,
    required this.number,
    required this.name,
    this.overview,
    this.stillPath,
    this.airDate,
    this.runtimeMinutes,
  });

  final int season;
  final int number;
  final String name;
  final String? overview;
  final String? stillPath;
  final String? airDate;
  final int? runtimeMinutes;

  String? get stillUrl => stillPath == null
      ? null
      : '${TmdbConstants.imageBaseUrl}/w300$stillPath';

  /// Not broadcast yet (no date, or a date after [now]).
  bool isUpcoming([DateTime? now]) {
    final date = airDate == null ? null : DateTime.tryParse(airDate!);
    return date == null || date.isAfter(now ?? DateTime.now());
  }

  factory Episode.fromJson(Map<String, dynamic> json, int season) {
    String? str(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    final number = (json['episode_number'] as num?)?.toInt() ?? 0;
    return Episode(
      season: season,
      number: number,
      name: str(json['name']) ?? 'Episodio $number',
      overview: str(json['overview']),
      stillPath: str(json['still_path']),
      airDate: str(json['air_date']),
      runtimeMinutes: (json['runtime'] as num?)?.toInt(),
    );
  }
}

class NextEpisode {
  const NextEpisode({
    required this.airDate,
    this.season,
    this.episode,
    this.name,
  });

  final String airDate;
  final int? season;
  final int? episode;
  final String? name;
}

/// "2026-11-26" → "26 de noviembre de 2026".
String spanishDate(String? isoDate) {
  if (isoDate == null) return '';
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${d.day} de ${months[d.month - 1]} de ${d.year}';
}

/// US dollars, short: "150 M$", "1.200 M$", "850.000 $".
String formatMoney(int dollars) {
  String grouped(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  if (dollars >= 1000000) return '${grouped((dollars / 1000000).round())} M\$';
  return '${grouped(dollars)} \$';
}

String languageName(String code) => _languages[code] ?? code.toUpperCase();

String countryName(String code) => _countries[code] ?? code;

const _languages = {
  'en': 'Inglés',
  'es': 'Español',
  'fr': 'Francés',
  'de': 'Alemán',
  'it': 'Italiano',
  'pt': 'Portugués',
  'ja': 'Japonés',
  'ko': 'Coreano',
  'zh': 'Chino',
  'cn': 'Cantonés',
  'hi': 'Hindi',
  'ru': 'Ruso',
  'sv': 'Sueco',
  'da': 'Danés',
  'no': 'Noruego',
  'nl': 'Neerlandés',
  'pl': 'Polaco',
  'tr': 'Turco',
  'ar': 'Árabe',
  'th': 'Tailandés',
  'ca': 'Catalán',
  'eu': 'Euskera',
  'gl': 'Gallego',
  'fi': 'Finés',
  'he': 'Hebreo',
  'id': 'Indonesio',
  'fa': 'Persa',
  'el': 'Griego',
};

const _countries = {
  'US': 'Estados Unidos',
  'ES': 'España',
  'GB': 'Reino Unido',
  'FR': 'Francia',
  'DE': 'Alemania',
  'IT': 'Italia',
  'CA': 'Canadá',
  'MX': 'México',
  'AR': 'Argentina',
  'JP': 'Japón',
  'KR': 'Corea del Sur',
  'CN': 'China',
  'IN': 'India',
  'AU': 'Australia',
  'NZ': 'Nueva Zelanda',
  'IE': 'Irlanda',
  'BE': 'Bélgica',
  'NL': 'Países Bajos',
  'SE': 'Suecia',
  'DK': 'Dinamarca',
  'NO': 'Noruega',
  'FI': 'Finlandia',
  'PT': 'Portugal',
  'BR': 'Brasil',
  'CL': 'Chile',
  'CO': 'Colombia',
  'RU': 'Rusia',
  'PL': 'Polonia',
  'TR': 'Turquía',
  'HK': 'Hong Kong',
  'TW': 'Taiwán',
  'ZA': 'Sudáfrica',
  'CZ': 'Chequia',
  'AT': 'Austria',
  'CH': 'Suiza',
  'HU': 'Hungría',
  'IS': 'Islandia',
  'TH': 'Tailandia',
};
