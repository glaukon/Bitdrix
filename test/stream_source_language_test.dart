import 'package:bitdrix/data/models/audio_language.dart';
import 'package:bitdrix/data/models/stream_source_model.dart';
import 'package:flutter_test/flutter_test.dart';

StreamSourceModel source(String title, {String name = 'Torrentio\n1080p'}) =>
    StreamSourceModel(name: name, title: title);

void main() {
  test('a short flag list is the audio, in order', () {
    final s = source(
      'Movie.2017.2160p.Remux\n👤 41 💾 71.8 GB ⚙️ ThePirateBay\n'
      '🇬🇧 / 🇪🇸 / 🇺🇸 / 🇲🇽',
    );
    // 🇺🇸 is folded into 🇬🇧.
    expect(s.audioLanguageCodes, ['GB', 'ES', 'MX']);
    expect(s.subtitleLanguageCodes, isEmpty);
  });

  test('a long flag list is subtitles unless the name confirms the audio', () {
    // Real YTS release: one AAC 5.1 track, 23 subtitle flags.
    final yts = source(
      'Spider-Man: Brand New Day 2026 2160p WEBRip\n👤 1233 💾 6.47 GB ⚙️ YTS\n'
      '🇬🇧 / 🇯🇵 / 🇮🇹 / 🇵🇹 / 🇪🇸 / 🇰🇷 / 🇨🇳 / 🇫🇷 / 🇩🇪',
    );
    expect(yts.audioLanguageCodes, [AudioLanguage.unknownCode]);
    expect(yts.subtitleLanguageCodes, contains('ES'));

    final dual = source(
      'Movie.2017.1080p.Castellano.English\n👤 9\n'
      '🇬🇧 / 🇪🇸 / 🇫🇷 / 🇩🇪 / 🇮🇹',
    );
    expect(dual.audioLanguageCodes, containsAll(['ES', 'GB']));
    expect(dual.subtitleLanguageCodes, ['FR', 'DE', 'IT']);
  });

  test('reads languages from words in the release name', () {
    expect(
      source('Pelicula.2020.1080p.Castellano.Latino\n👤 5').audioLanguageCodes,
      containsAll(['ES', 'MX']),
    );
    expect(source('Movie 2017 EN ENG x265\n👤 5').audioLanguageCodes, ['GB']);
  });

  test('marks sources without language information as unknown', () {
    expect(
      source('Movie.2017.1080p.WEB-DL\n👤 88 💾 18 GB ⚙️ 1337x')
          .audioLanguageCodes,
      [AudioLanguage.unknownCode],
    );
  });

  test('"Torrentio" in the name is not mistaken for a language', () {
    expect(source('X\n👤 1', name: 'Torrentio\n4k DV').audioLanguageCodes,
        [AudioLanguage.unknownCode]);
  });

  test('every language has a Spanish name, unknown flags keep their code', () {
    expect(AudioLanguage.byCode('ES').name, 'Castellano');
    expect(AudioLanguage.byCode('MX').name, 'Latino');
    expect(AudioLanguage.byCode('ZZ').name, 'ZZ');
  });
}
