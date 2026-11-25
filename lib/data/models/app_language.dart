/// Represents a preferred content language for filtering torrent sources.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.name,
    required this.keywords,
  });

  /// BCP-47 language code, e.g. `'es'`, `'en'`. `'any'` means no filter.
  final String code;

  /// Display name shown in the UI.
  final String name;

  /// Lowercase keywords matched against the torrent source name/title.
  /// Empty list means no filtering (used for 'any').
  final List<String> keywords;

  bool get isAny => code == 'any';
}

/// All languages the user can choose from, in display order.
const kAppLanguages = [
  AppLanguage(
    code: 'any',
    name: 'Cualquier idioma',
    keywords: [],
  ),
  AppLanguage(
    code: 'es',
    name: 'Castellano',
    keywords: ['castellano', 'cast', 'es-es', 'spanish', 'esp', 'spa'],
  ),
  AppLanguage(
    code: 'en',
    name: 'English',
    keywords: ['english', 'eng'],
  ),
  AppLanguage(
    code: 'fr',
    name: 'Français',
    keywords: ['french', 'vf', 'vostfr', 'fra'],
  ),
  AppLanguage(
    code: 'de',
    name: 'Deutsch',
    keywords: ['german', 'deutsch', 'ger'],
  ),
  AppLanguage(
    code: 'it',
    name: 'Italiano',
    keywords: ['italian', 'italiano', 'ita'],
  ),
  AppLanguage(
    code: 'pt',
    name: 'Português',
    keywords: ['portuguese', 'por', 'pt-br', 'dublado'],
  ),
  AppLanguage(
    code: 'ja',
    name: '日本語',
    keywords: ['japanese', 'jpn'],
  ),
];
