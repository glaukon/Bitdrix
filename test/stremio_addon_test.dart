import 'package:bitdrix/core/utils/genre_labels.dart';
import 'package:bitdrix/data/models/stremio_addon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeManifestUrl', () {
    test('accepts manifest, base and stremio:// URLs', () {
      expect(StremioAddon.normalizeManifestUrl('https://a.example/cfg/manifest.json'),
          'https://a.example/cfg/manifest.json');
      expect(StremioAddon.normalizeManifestUrl(' https://a.example/cfg/ '),
          'https://a.example/cfg/manifest.json');
      expect(StremioAddon.normalizeManifestUrl('stremio://a.example/manifest.json'),
          'https://a.example/manifest.json');
      expect(StremioAddon.normalizeManifestUrl('a.example'),
          'https://a.example/manifest.json');
    });
  });

  final addon = StremioAddon.fromManifest(
    'https://tv.example/cfg-es/manifest.json',
    {
      'id': 'org.example.tv',
      'name': 'Example TV',
      'version': '1.2.0',
      'types': ['tv'],
      'idPrefixes': ['extv:'],
      'resources': [
        'catalog',
        {
          'name': 'stream',
          'types': ['tv'],
          'idPrefixes': ['extv:'],
        },
      ],
      'catalogs': [
        {
          'type': 'tv',
          'id': 'es',
          'name': 'España',
          'extra': [
            {'name': 'search'},
            {
              'name': 'genre',
              'options': ['Tutti', 'Deportes', 'Cine'],
            },
          ],
        },
        {
          'type': 'tv',
          'id': 'search',
          'name': 'Buscar',
          'extra': [
            {'name': 'search', 'isRequired': true},
          ],
        },
      ],
    },
  );

  test('parses the manifest', () {
    expect(addon.baseUrl, 'https://tv.example/cfg-es');
    expect(addon.catalogs.first.name, 'España');
    expect(addon.catalogs.first.supportsSearch, isTrue);
    expect(addon.catalogs.first.requiresSearch, isFalse);
    expect(addon.catalogs.first.genres, ['Tutti', 'Deportes', 'Cine']);
    // TvVoo's "everything" option is left to the app's own "Todas" chip.
    expect(addon.catalogs.first.filterGenres, ['Deportes', 'Cine']);
    expect(addon.catalogs.last.requiresSearch, isTrue);
  });

  test('knows which items it serves streams for', () {
    expect(addon.serves('stream', 'tv', id: 'extv:123'), isTrue);
    expect(addon.serves('stream', 'tv', id: 'tt0111161'), isFalse);
    expect(addon.serves('stream', 'movie', id: 'extv:1'), isFalse);
    expect(addon.serves('meta', 'tv'), isFalse);
  });

  test('reads stream URLs and the headers they need', () {
    final s = StremioStream.fromJson('Example TV', {
      'url': 'https://cdn.example/live.m3u8',
      'name': 'Example',
      'description': 'HD',
      'behaviorHints': {
        'notWebReady': true,
        'proxyHeaders': {
          'request': {'User-Agent': 'okhttp/4.11.0', 'Referer': 'https://x/'},
        },
      },
    });
    expect(s.isPlayableUrl, isTrue);
    expect(s.label, 'Example · HD');
    expect(s.headers, {'User-Agent': 'okhttp/4.11.0', 'Referer': 'https://x/'});
  });

  test('shows addon categories in Castilian', () {
    expect(genreLabel('Sport'), 'Deportes');
    expect(genreLabel('Movies'), 'Cine');
    expect(genreLabel('Documentary'), 'Documentales');
    expect(genreLabel('intrattenimento'), 'Entretenimiento');
    expect(genreLabel('telenovelas'), 'Telenovelas');
  });

  test('lists a category once even if the addon repeats it', () {
    const c = StremioCatalog(
      type: 'tv',
      id: 'es',
      name: 'España',
      genres: ['Tutti', 'Sport', 'sport', 'News'],
    );
    expect(c.filterGenres, ['Sport', 'News']);
  });
}
