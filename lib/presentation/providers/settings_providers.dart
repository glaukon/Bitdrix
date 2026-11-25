import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/app_language.dart';
import '../../data/models/audio_language.dart';

const _kLangKey = 'preferred_language';
const _kAudioLangKey = 'preferred_audio_language';

/// Manages the user's preferred content language.
///
/// - Default: `'any'` (no filtering).
/// - Persisted in [SharedPreferences] under [_kLangKey].
class LanguagePreferenceNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    _load();
    return kAppLanguages.first;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLangKey);
    if (code != null) {
      final lang = kAppLanguages.firstWhere(
        (l) => l.code == code,
        orElse: () => kAppLanguages.first,
      );
      state = lang;
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangKey, lang.code);
  }
}

final languagePreferenceProvider =
    NotifierProvider<LanguagePreferenceNotifier, AppLanguage>(
  LanguagePreferenceNotifier.new,
);

/// Manages the user's preferred playback audio language.
///
/// Defaults to Spanish because playback should prefer castellano/español when
/// a media file exposes that audio track.
class AudioLanguagePreferenceNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    _load();
    return _spanishLanguage;
  }

  static AppLanguage get _spanishLanguage => kAppLanguages.firstWhere(
        (l) => l.code == 'es',
        orElse: () => kAppLanguages.first,
      );

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kAudioLangKey);
    if (code != null) {
      final lang = kAppLanguages.firstWhere(
        (l) => l.code == code,
        orElse: () => _spanishLanguage,
      );
      state = lang;
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAudioLangKey, lang.code);
  }
}

final audioLanguagePreferenceProvider =
    NotifierProvider<AudioLanguagePreferenceNotifier, AppLanguage>(
  AudioLanguagePreferenceNotifier.new,
);

const _kTmdbKey = 'tmdb_api_key';

/// TMDB credential used by Discover: either a v3 API key or a v4 read access
/// token. Set in Settings, or at build time with
/// `--dart-define=TMDB_API_KEY=...`. Empty means "not configured".
class TmdbApiKeyNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return const String.fromEnvironment('TMDB_API_KEY');
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kTmdbKey);
    if (saved != null && saved.isNotEmpty) state = saved;
  }

  Future<void> setKey(String key) async {
    final trimmed = key.trim();
    state = trimmed.isNotEmpty
        ? trimmed
        : const String.fromEnvironment('TMDB_API_KEY');
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_kTmdbKey);
    } else {
      await prefs.setString(_kTmdbKey, trimmed);
    }
  }
}

final tmdbApiKeyProvider = NotifierProvider<TmdbApiKeyNotifier, String>(
  TmdbApiKeyNotifier.new,
);

// ── Sources audio-language filter ────────────────────────────────────────────

const _kSourceLanguagesKey = 'sources_audio_languages';
const _kLegacyCastilianOnlyKey = 'sources_castilian_only';

/// Audio languages (flag country codes, see [AudioLanguage]) the sources list
/// is filtered by. Empty means "show every source". Castellano by default:
/// the app is tuned for watching everything in castellano.
class SourceLanguagesNotifier extends Notifier<Set<String>> {
  static const _default = {'ES'};

  @override
  Set<String> build() {
    _load();
    return _default;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kSourceLanguagesKey);
    if (saved != null) {
      state = saved.toSet();
    } else if (prefs.getBool(_kLegacyCastilianOnlyKey) == false) {
      // The old "Solo audio en castellano" switch was turned off.
      state = const {};
    }
  }

  /// Adds or removes one language from the filter.
  Future<void> toggle(String code) =>
      _save(state.contains(code) ? ({...state}..remove(code)) : {...state, code});

  /// Shows every source again.
  Future<void> clear() => _save(const {});

  Future<void> _save(Set<String> codes) async {
    state = codes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSourceLanguagesKey, codes.toList());
  }
}

final sourceLanguagesProvider =
    NotifierProvider<SourceLanguagesNotifier, Set<String>>(
  SourceLanguagesNotifier.new,
);

// ── Subtitles ────────────────────────────────────────────────────────────────

const _kSubtitleModeKey = 'subtitle_mode';

enum SubtitleMode {
  /// Forced Spanish subtitles when the audio is Spanish; full Spanish
  /// subtitles when no Spanish audio track exists.
  auto('Automáticos'),

  /// Never enable subtitles automatically.
  off('Desactivados'),

  /// Always enable full Spanish subtitles when available.
  always('Siempre en castellano');

  const SubtitleMode(this.label);
  final String label;
}

class SubtitleModeNotifier extends Notifier<SubtitleMode> {
  @override
  SubtitleMode build() {
    _load();
    return SubtitleMode.auto;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kSubtitleModeKey);
    state = SubtitleMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => SubtitleMode.auto,
    );
  }

  Future<void> set(SubtitleMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSubtitleModeKey, mode.name);
  }
}

final subtitleModeProvider =
    NotifierProvider<SubtitleModeNotifier, SubtitleMode>(
  SubtitleModeNotifier.new,
);
