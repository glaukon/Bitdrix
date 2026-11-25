import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/tv_channel.dart';
import '../../data/services/tdt_channels_service.dart';

final tdtChannelsServiceProvider =
    Provider<TdtChannelsService>((ref) => TdtChannelsService());

/// Spain's live channel groups. Kept for the whole session: the list changes
/// rarely and pull-to-refresh reloads it.
final tvGroupsProvider = FutureProvider<List<TvChannelGroup>>(
  (ref) => ref.watch(tdtChannelsServiceProvider).fetchGroups(),
);

/// A persisted set of strings, loaded asynchronously from SharedPreferences.
abstract class _StoredSetNotifier extends Notifier<Set<String>> {
  String get key;

  @override
  Set<String> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(key);
    if (saved != null) state = saved.toSet();
  }

  Future<void> toggle(String value) async {
    state = state.contains(value)
        ? ({...state}..remove(value))
        : {...state, value};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, state.toList());
  }
}

/// Ids ([TvChannel.id]) of the channels the user starred.
class FavoriteChannelsNotifier extends _StoredSetNotifier {
  @override
  String get key => 'tv_favorite_channels';
}

final favoriteChannelsProvider =
    NotifierProvider<FavoriteChannelsNotifier, Set<String>>(
  FavoriteChannelsNotifier.new,
);

/// The autonomous community whose regional channels the TV tab offers.
class TvRegionNotifier extends Notifier<String?> {
  static const _key = 'tv_region';

  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> set(String region) async {
    state = region;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, region);
  }
}

final tvRegionProvider =
    NotifierProvider<TvRegionNotifier, String?>(TvRegionNotifier.new);
