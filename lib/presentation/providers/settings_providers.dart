import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/app_language.dart';

const _kLangKey = 'preferred_language';
const _kAudioLangKey = 'preferred_audio_language';

/// Manages the user's preferred content language.
///
/// - Default: `'any'` (no filtering).
/// - Persisted in [SharedPreferences] under [_kLangKey].
class LanguagePreferenceNotifier extends StateNotifier<AppLanguage> {
  LanguagePreferenceNotifier() : super(kAppLanguages.first) {
    _load();
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
    StateNotifierProvider<LanguagePreferenceNotifier, AppLanguage>(
  (ref) => LanguagePreferenceNotifier(),
);

/// Manages the user's preferred playback audio language.
///
/// Defaults to Spanish because playback should prefer castellano/español when
/// a media file exposes that audio track.
class AudioLanguagePreferenceNotifier extends StateNotifier<AppLanguage> {
  AudioLanguagePreferenceNotifier() : super(_spanishLanguage) {
    _load();
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
    StateNotifierProvider<AudioLanguagePreferenceNotifier, AppLanguage>(
  (ref) => AudioLanguagePreferenceNotifier(),
);

const _kTmdbKey = 'tmdb_api_key';

/// TMDB credential used by Discover: either a v3 API key or a v4 read access
/// token. Set in Settings, or at build time with
/// `--dart-define=TMDB_API_KEY=...`. Empty means "not configured".
class TmdbApiKeyNotifier extends StateNotifier<String> {
  TmdbApiKeyNotifier() : super(const String.fromEnvironment('TMDB_API_KEY')) {
    _load();
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

final tmdbApiKeyProvider = StateNotifierProvider<TmdbApiKeyNotifier, String>(
  (ref) => TmdbApiKeyNotifier(),
);

// ── Castilian-only sources filter ────────────────────────────────────────────

const _kCastilianOnlyKey = 'sources_castilian_only';

/// Whether the sources list shows only sources with Castilian audio.
/// On by default: the app is tuned for watching everything in castellano.
class CastilianOnlyNotifier extends StateNotifier<bool> {
  CastilianOnlyNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kCastilianOnlyKey) ?? true;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCastilianOnlyKey, value);
  }
}

final castilianOnlyProvider = StateNotifierProvider<CastilianOnlyNotifier, bool>(
  (ref) => CastilianOnlyNotifier(),
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

class SubtitleModeNotifier extends StateNotifier<SubtitleMode> {
  SubtitleModeNotifier() : super(SubtitleMode.auto) {
    _load();
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
    StateNotifierProvider<SubtitleModeNotifier, SubtitleMode>(
  (ref) => SubtitleModeNotifier(),
);
