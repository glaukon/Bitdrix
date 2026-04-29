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
