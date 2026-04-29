/// A single content provider available through the Torrentio Stremio add-on API.
class TorrentioProvider {
  const TorrentioProvider({
    required this.id,
    required this.name,
    required this.category,
  });

  /// The provider identifier used in Torrentio's config URL segment.
  /// e.g. `'yts'` → `https://torrentio.strem.fun/providers=yts/stream/…`
  final String id;

  /// Human-readable display name shown in Settings.
  final String name;

  /// Category label: `'General'` or `'Anime'`.
  final String category;
}

/// All providers supported by Torrentio, in display order.
const kTorrentioProviders = [
  // ── General ────────────────────────────────────────────────────────────────
  TorrentioProvider(id: 'yts',             name: 'YTS',             category: 'General'),
  TorrentioProvider(id: 'eztv',            name: 'EZTV',            category: 'General'),
  TorrentioProvider(id: '1337x',           name: '1337x',           category: 'General'),
  TorrentioProvider(id: 'thepiratebay',    name: 'The Pirate Bay',  category: 'General'),
  TorrentioProvider(id: 'kickasstorrents', name: 'KickassTorrents', category: 'General'),
  TorrentioProvider(id: 'torrentgalaxy',   name: 'TorrentGalaxy',   category: 'General'),
  TorrentioProvider(id: 'magnetdl',        name: 'MagnetDL',        category: 'General'),
  // ── Anime ──────────────────────────────────────────────────────────────────
  TorrentioProvider(id: 'horriblesubs',    name: 'HorribleSubs',    category: 'Anime'),
  TorrentioProvider(id: 'nyaasi',          name: 'Nyaa.si',         category: 'Anime'),
  TorrentioProvider(id: 'tokyotosho',      name: 'TokyoTosho',      category: 'Anime'),
  TorrentioProvider(id: 'anidex',          name: 'AniDex',          category: 'Anime'),
];

/// Set of all provider IDs — used as the default "all enabled" state.
final kAllProviderIds = kTorrentioProviders.map((p) => p.id).toSet();
