import 'package:bitdrix/data/models/media_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Favourites are stored with toJson and read back with fromJson.
  test('a TV show keeps its name and date through toJson/fromJson', () {
    final show = MediaModel.fromJson({
      'id': 1399,
      'media_type': 'tv',
      'name': 'Juego de tronos',
      'first_air_date': '2011-04-17',
      'poster_path': '/p.jpg',
      'vote_average': 8.4,
    });
    final back = MediaModel.fromJson(show.toJson());
    expect(back.mediaType, 'tv');
    expect(back.title, 'Juego de tronos');
    expect(back.releaseDate, '2011-04-17');
    expect(back.posterPath, '/p.jpg');
  });

  test('a movie keeps its title and date through toJson/fromJson', () {
    final movie = MediaModel.fromJson({
      'id': 603,
      'media_type': 'movie',
      'title': 'Matrix',
      'release_date': '1999-03-30',
    });
    final back = MediaModel.fromJson(movie.toJson());
    expect(back.mediaType, 'movie');
    expect(back.title, 'Matrix');
    expect(back.releaseDate, '1999-03-30');
  });

  test('reads runtime, tagline, cast and director from full details', () {
    final movie = MediaModel.fromJson({
      'id': 1,
      'media_type': 'movie',
      'title': 'X',
      'runtime': 112,
      'tagline': '  Una familia, dos bodas  ',
      'credits': {
        'cast': [
          {'name': 'Ben Stiller', 'character': 'Greg', 'profile_path': '/b.jpg'},
        ],
        'crew': [
          {'name': 'John Hamburg', 'job': 'Director'},
          {'name': 'Otra', 'job': 'Producer'},
        ],
      },
    });
    expect(movie.displayRuntime, '1 h 52 min');
    expect(movie.tagline, 'Una familia, dos bodas');
    expect(movie.cast.single.name, 'Ben Stiller');
    expect(movie.cast.single.photoUrl, endsWith('/w185/b.jpg'));
    expect(movie.directors, ['John Hamburg']);
  });

  test('shows TV status and creators in Castilian', () {
    final show = MediaModel.fromJson({
      'id': 2,
      'media_type': 'tv',
      'name': 'Y',
      'status': 'Returning Series',
      'episode_run_time': [45],
      'created_by': [
        {'name': 'Creadora'},
      ],
    });
    expect(show.displayStatus, 'En emisión');
    expect(show.displayRuntime, '45 min');
    expect(show.directors, ['Creadora']);
  });
}
