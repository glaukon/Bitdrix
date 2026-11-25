import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/media_model.dart';

/// Movies and TV shows the user marked as favourite, newest first. Stored
/// whole so the Favoritos tab shows them without calling TMDB.
/// (Favourite TV channels live in `favoriteMetasProvider`.)
class FavoriteMediaNotifier extends Notifier<List<MediaModel>> {
  static const _key = 'favorite_media';

  @override
  List<MediaModel> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    state = [
      for (final m in jsonDecode(raw) as List<dynamic>)
        if (m is Map<String, dynamic>) MediaModel.fromJson(m),
    ];
  }

  bool isFavorite(MediaModel media) =>
      state.any((m) => m.id == media.id && m.mediaType == media.mediaType);

  Future<void> toggle(MediaModel media) async {
    state = isFavorite(media)
        ? state
            .where((m) => !(m.id == media.id && m.mediaType == media.mediaType))
            .toList()
        : [media, ...state];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final m in state) m.toJson()]),
    );
  }
}

final favoriteMediaProvider =
    NotifierProvider<FavoriteMediaNotifier, List<MediaModel>>(
  FavoriteMediaNotifier.new,
);
