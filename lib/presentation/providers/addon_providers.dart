import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/stremio_addon.dart';
import '../../data/services/stremio_addon_client.dart';

final stremioClientProvider =
    Provider<StremioAddonClient>((ref) => StremioAddonClient());

/// The Stremio addons the user installed, in install order. Each is stored
/// with its manifest so the app starts without waiting for the network.
class InstalledAddonsNotifier extends AsyncNotifier<List<StremioAddon>> {
  static const _key = 'stremio_addons';

  @override
  Future<List<StremioAddon>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    final addons = <StremioAddon>[];
    for (final entry in jsonDecode(raw) as List<dynamic>) {
      if (entry is! Map<String, dynamic>) continue;
      final url = entry['url'];
      final manifest = entry['manifest'];
      if (url is String && manifest is Map<String, dynamic>) {
        addons.add(StremioAddon.fromManifest(url, manifest));
      }
    }
    return addons;
  }

  Future<void> _save(Map<String, Map<String, dynamic>> manifests) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([
        for (final e in manifests.entries) {'url': e.key, 'manifest': e.value},
      ]),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _storedManifests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final result = <String, Map<String, dynamic>>{};
    if (raw == null) return result;
    for (final entry in jsonDecode(raw) as List<dynamic>) {
      if (entry is Map<String, dynamic> &&
          entry['url'] is String &&
          entry['manifest'] is Map<String, dynamic>) {
        result[entry['url'] as String] =
            entry['manifest'] as Map<String, dynamic>;
      }
    }
    return result;
  }

  /// Installs the addon at [input]; replaces it if already installed.
  /// Throws when the URL is not a Stremio addon.
  Future<StremioAddon> install(String input) async {
    final url = StremioAddon.normalizeManifestUrl(input);
    final json =
        await ref.read(stremioClientProvider).fetchManifestJson(url);
    final addon = StremioAddon.fromManifest(url, json);
    // Keep the raw manifest so it can be re-parsed on the next start.
    final manifests = await _storedManifests();
    manifests[url] = json;
    await _save(manifests);
    ref.invalidateSelf();
    await future;
    return addon;
  }

  Future<void> remove(String manifestUrl) async {
    final manifests = await _storedManifests()..remove(manifestUrl);
    await _save(manifests);
    ref.invalidateSelf();
  }
}

final installedAddonsProvider =
    AsyncNotifierProvider<InstalledAddonsNotifier, List<StremioAddon>>(
  InstalledAddonsNotifier.new,
);

/// Channels the user starred on the TV tab, stored with what is needed to
/// show and open them without reloading any catalog.
class FavoriteMetasNotifier extends Notifier<List<StremioMeta>> {
  static const _key = 'tv_addon_favorites';

  @override
  List<StremioMeta> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    state = [
      for (final m in jsonDecode(raw) as List<dynamic>)
        if (m is Map<String, dynamic>) StremioMeta.fromJson(m),
    ];
  }

  bool isFavorite(StremioMeta meta) =>
      state.any((m) => m.id == meta.id && m.type == meta.type);

  Future<void> toggle(StremioMeta meta) async {
    state = isFavorite(meta)
        ? state.where((m) => !(m.id == meta.id && m.type == meta.type)).toList()
        : [...state, meta];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([
        for (final m in state)
          {
            'id': m.id,
            'type': m.type,
            'name': m.name,
            'poster': m.posterUrl,
            'logo': m.logoUrl,
            'posterShape': m.posterShape,
          },
      ]),
    );
  }
}

final favoriteMetasProvider =
    NotifierProvider<FavoriteMetasNotifier, List<StremioMeta>>(
  FavoriteMetasNotifier.new,
);

/// A catalog together with the addon that serves it.
typedef AddonCatalog = ({StremioAddon addon, StremioCatalog catalog});

/// Stremio types shown on the TV tab.
const tvTypes = {'tv', 'channel'};

/// Every browsable live-TV catalog of the installed addons.
final tvCatalogsProvider = Provider<List<AddonCatalog>>((ref) {
  final addons = ref.watch(installedAddonsProvider).value ?? const [];
  return [
    for (final addon in addons)
      for (final catalog in addon.catalogs)
        if (tvTypes.contains(catalog.type) && !catalog.requiresSearch)
          (addon: addon, catalog: catalog),
  ];
});

/// Items of one catalog, optionally narrowed to one of its genres (the
/// filter Stremio shows as a drop-down; for TV addons, the categories).
final catalogItemsProvider = FutureProvider.autoDispose
    .family<List<StremioMeta>, ({AddonCatalog source, String? genre})>(
  (ref, args) => ref.watch(stremioClientProvider).getCatalog(
        args.source.addon,
        args.source.catalog,
        genre: args.genre,
      ),
);

/// Streams every installed addon offers for an item, in addon order.
/// Addons that fail are skipped so one broken addon does not hide the rest.
final itemStreamsProvider = FutureProvider.autoDispose
    .family<List<StremioStream>, ({String type, String id})>((ref, item) async {
  final addons = await ref.watch(installedAddonsProvider.future);
  final client = ref.watch(stremioClientProvider);
  final results = await Future.wait([
    for (final addon in addons)
      if (addon.serves('stream', item.type, id: item.id))
        client
            .getStreams(addon, item.type, item.id)
            .catchError((Object _) => <StremioStream>[]),
  ]);
  return [for (final r in results) ...r];
});
