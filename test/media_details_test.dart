import 'package:bitdrix/data/models/media_details.dart';
import 'package:bitdrix/data/models/media_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the extra detail facts TMDB appends', () {
    final movie = MediaModel.fromJson({
      'id': 1,
      'media_type': 'movie',
      'title': 'Arácnidos',
      'original_title': 'Crawlers',
      'original_language': 'en',
      'release_date': '2026-10-30',
      'budget': 150000000,
      'revenue': 0,
      'production_countries': [
        {'iso_3166_1': 'US', 'name': 'United States of America'},
        {'iso_3166_1': 'ES', 'name': 'Spain'},
      ],
      'production_companies': [
        {'name': 'Estudio Uno'},
      ],
      'credits': {
        'cast': [],
        'crew': [
          {'name': 'Guionista', 'job': 'Screenplay'},
          {'name': 'Guionista', 'job': 'Writer'},
        ],
      },
      'release_dates': {
        'results': [
          {
            'iso_3166_1': 'ES',
            'release_dates': [
              {'certification': ''},
              {'certification': '16'},
            ],
          },
        ],
      },
      'videos': {
        'results': [
          {'site': 'YouTube', 'type': 'Teaser', 'key': 'teaser', 'iso_639_1': 'es'},
          {'site': 'YouTube', 'type': 'Trailer', 'key': 'en-trailer', 'iso_639_1': 'en'},
          {'site': 'YouTube', 'type': 'Trailer', 'key': 'es-trailer', 'iso_639_1': 'es'},
        ],
      },
      'watch/providers': {
        'results': {
          'ES': {
            'flatrate': [
              {'provider_name': 'Netflix', 'logo_path': '/n.png'},
            ],
          },
        },
      },
      'recommendations': {
        'results': [
          {'id': 2, 'title': 'Otra', 'poster_path': '/o.jpg'},
          {'id': 3, 'title': 'Sin póster'},
        ],
      },
    });

    final d = movie.details!;
    expect(d.originalTitle, 'Crawlers');
    expect(d.originalLanguage, 'Inglés');
    expect(d.countries, ['Estados Unidos', 'España']);
    expect(d.certification, '16');
    expect(d.writers, ['Guionista']);
    expect(d.companies, ['Estudio Uno']);
    expect(formatMoney(d.budget!), '150 M\$');
    expect(d.revenue, isNull);
    // A Castilian trailer beats an English one and any teaser.
    expect(d.trailerKey, 'es-trailer');
    expect(d.providers.single.name, 'Netflix');
    expect(d.recommendations.map((m) => m.title), ['Otra']);
    expect(spanishDate(movie.releaseDate), '30 de octubre de 2026');
  });

  test('reads seasons and the next episode of a show', () {
    final show = MediaModel.fromJson({
      'id': 9,
      'media_type': 'tv',
      'name': 'Serie',
      'credits': {'cast': [], 'crew': []},
      'seasons': [
        {'season_number': 0, 'name': 'Especiales'},
        {'season_number': 1, 'name': 'Temporada 1', 'episode_count': 8, 'air_date': '2024-01-05'},
      ],
      'next_episode_to_air': {
        'air_date': '2026-12-01',
        'season_number': 2,
        'episode_number': 3,
      },
      'content_ratings': {
        'results': [
          {'iso_3166_1': 'ES', 'rating': '12'},
        ],
      },
    });
    final d = show.details!;
    expect(d.seasons.single.name, 'Temporada 1');
    expect(d.seasons.single.year, '2024');
    expect(d.nextEpisode!.season, 2);
    expect(d.certification, '12');
  });

  test('reads an episode and knows when it is not out yet', () {
    final e = Episode.fromJson({
      'episode_number': 3,
      'name': 'El regreso',
      'overview': 'Dexter vuelve.',
      'still_path': '/s.jpg',
      'air_date': '2026-12-01',
      'runtime': 52,
    }, 2);
    expect(e.season, 2);
    expect(e.number, 3);
    expect(e.stillUrl, endsWith('/w300/s.jpg'));
    expect(e.isUpcoming(DateTime(2026, 11, 26)), isTrue);
    expect(e.isUpcoming(DateTime(2026, 12, 2)), isFalse);
    expect(Episode.fromJson({'episode_number': 1}, 1).isUpcoming(), isTrue);
  });
}
