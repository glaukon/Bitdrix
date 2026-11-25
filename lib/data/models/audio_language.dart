/// An audio language detected in a torrent source.
///
/// Torrentio lists a release's audio languages as country flag emojis
/// (🇪🇸 / 🇲🇽 / 🇬🇧 …); some releases only say it in the file name
/// ("castellano", "latino", "eng"…). Both are mapped to an [AudioLanguage]
/// identified by the ISO country code of its flag.
class AudioLanguage {
  const AudioLanguage({
    required this.code,
    required this.name,
    this.keywords = const [],
  });

  /// Country code of the language's flag (`'ES'`, `'MX'`, `'GB'`…), or
  /// [unknownCode] for sources that state no language at all.
  final String code;

  /// Display name in Spanish.
  final String name;

  /// Lowercase words that reveal this language in a release name.
  final List<String> keywords;

  bool get isUnknown => code == unknownCode;

  /// Code for sources without any language information. On Torrentio these
  /// are usually in the original language only.
  static const unknownCode = '??';

  static const unknown = AudioLanguage(code: unknownCode, name: 'Sin indicar');

  /// Looks up a language by flag country code. Unknown flags still get an
  /// entry, named after the code, so no detected language is ever lost.
  static AudioLanguage byCode(String code) =>
      _byCode[code] ?? AudioLanguage(code: code, name: code);

  /// Flags that mean the same language as another, more common one.
  static const _aliases = {'US': 'GB', 'TW': 'CN', 'AT': 'DE', 'BE': 'NL'};

  static String normalize(String countryCode) =>
      _aliases[countryCode] ?? countryCode;

  /// Languages that can be detected from words in a release name.
  static const List<AudioLanguage> withKeywords = [
    AudioLanguage(
      code: 'ES',
      name: 'Castellano',
      keywords: ['castellano', 'cast', 'es-es', 'esp', 'spa'],
    ),
    AudioLanguage(
      code: 'MX',
      name: 'Latino',
      keywords: ['latino', 'latin', 'latam', 'es-la', 'es-mx'],
    ),
    AudioLanguage(code: 'GB', name: 'Inglés', keywords: ['english', 'eng']),
    AudioLanguage(
      code: 'FR',
      name: 'Francés',
      keywords: ['french', 'truefrench', 'vff', 'vfq'],
    ),
    AudioLanguage(code: 'DE', name: 'Alemán', keywords: ['german', 'deutsch']),
    AudioLanguage(code: 'IT', name: 'Italiano', keywords: ['italian', 'ita']),
    AudioLanguage(code: 'BR', name: 'Portugués (Brasil)', keywords: ['dublado']),
  ];

  static final Map<String, AudioLanguage> _byCode = {
    for (final l in withKeywords) l.code: l,
    for (final l in const [
      AudioLanguage(code: 'PT', name: 'Portugués'),
      AudioLanguage(code: 'RU', name: 'Ruso'),
      AudioLanguage(code: 'JP', name: 'Japonés'),
      AudioLanguage(code: 'KR', name: 'Coreano'),
      AudioLanguage(code: 'CN', name: 'Chino'),
      AudioLanguage(code: 'IN', name: 'Hindi'),
      AudioLanguage(code: 'NL', name: 'Neerlandés'),
      AudioLanguage(code: 'PL', name: 'Polaco'),
      AudioLanguage(code: 'CZ', name: 'Checo'),
      AudioLanguage(code: 'SK', name: 'Eslovaco'),
      AudioLanguage(code: 'HU', name: 'Húngaro'),
      AudioLanguage(code: 'RO', name: 'Rumano'),
      AudioLanguage(code: 'BG', name: 'Búlgaro'),
      AudioLanguage(code: 'RS', name: 'Serbio'),
      AudioLanguage(code: 'HR', name: 'Croata'),
      AudioLanguage(code: 'SI', name: 'Esloveno'),
      AudioLanguage(code: 'UA', name: 'Ucraniano'),
      AudioLanguage(code: 'GR', name: 'Griego'),
      AudioLanguage(code: 'TR', name: 'Turco'),
      AudioLanguage(code: 'DK', name: 'Danés'),
      AudioLanguage(code: 'SE', name: 'Sueco'),
      AudioLanguage(code: 'NO', name: 'Noruego'),
      AudioLanguage(code: 'FI', name: 'Finés'),
      AudioLanguage(code: 'EE', name: 'Estonio'),
      AudioLanguage(code: 'LV', name: 'Letón'),
      AudioLanguage(code: 'LT', name: 'Lituano'),
      AudioLanguage(code: 'SA', name: 'Árabe'),
      AudioLanguage(code: 'IL', name: 'Hebreo'),
      AudioLanguage(code: 'IR', name: 'Persa'),
      AudioLanguage(code: 'TH', name: 'Tailandés'),
      AudioLanguage(code: 'VN', name: 'Vietnamita'),
      AudioLanguage(code: 'ID', name: 'Indonesio'),
      AudioLanguage(code: 'MY', name: 'Malayo'),
      AudioLanguage(code: 'PH', name: 'Filipino'),
    ])
      l.code: l,
  };
}
