/// Models for the Stremio addon protocol
/// (https://github.com/Stremio/stremio-addon-sdk/tree/master/docs/api).
///
/// An addon is a web service described by a `manifest.json`; Bitdrix reads
/// its catalogs and streams. Which addons to use is up to the user.
library;

/// A catalog an addon offers, e.g. the channels of one country.
class StremioCatalog {
  const StremioCatalog({
    required this.type,
    required this.id,
    required this.name,
    this.supportsSearch = false,
    this.requiresSearch = false,
    this.genres = const [],
  });

  /// Stremio content type: `movie`, `series`, `tv`, `channel`…
  final String type;
  final String id;
  final String name;
  final bool supportsSearch;

  /// Only usable with a search query (a "search catalog").
  final bool requiresSearch;

  /// Filter values the catalog accepts for its `genre` extra.
  final List<String> genres;

  /// [genres] without the "everything" entry some addons put first
  /// ("Tutti", "All"…): the UI has its own "Todas" chip.
  /// Values that differ only in case ("Sport" / "sport") appear once.
  List<String> get filterGenres {
    final seen = <String>{};
    return [
      for (final g in genres)
        if (!const {'tutti', 'todos', 'todas', 'all', 'any', 'none'}
                .contains(g.trim().toLowerCase()) &&
            seen.add(g.trim().toLowerCase()))
          g,
    ];
  }

  factory StremioCatalog.fromJson(Map<String, dynamic> json) {
    var supportsSearch = false;
    var requiresSearch = false;
    var genres = const <String>[];
    final extra = (json['extra'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>();
    for (final e in extra) {
      switch (e['name']) {
        case 'search':
          supportsSearch = true;
          requiresSearch = e['isRequired'] == true;
        case 'genre':
          genres = [
            for (final o in e['options'] as List<dynamic>? ?? [])
              if (o is String) o,
          ];
      }
    }
    // Legacy manifests list extras by name only.
    final legacy = json['extraSupported'] as List<dynamic>? ?? [];
    final legacyRequired = json['extraRequired'] as List<dynamic>? ?? [];
    if (legacy.contains('search')) supportsSearch = true;
    if (legacyRequired.contains('search')) requiresSearch = true;
    if (genres.isEmpty && json['genres'] is List) {
      genres = [
        for (final g in json['genres'] as List<dynamic>)
          if (g is String) g,
      ];
    }
    return StremioCatalog(
      type: json['type'] as String? ?? '',
      id: json['id'] as String? ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : (json['id'] as String? ?? ''),
      supportsSearch: supportsSearch,
      requiresSearch: requiresSearch,
      genres: genres,
    );
  }
}

/// A resource (`catalog`, `meta`, `stream`, `subtitles`) an addon serves,
/// optionally limited to some types and id prefixes.
class StremioResource {
  const StremioResource({
    required this.name,
    this.types,
    this.idPrefixes,
  });

  final String name;

  /// Null means "the addon's top-level types".
  final List<String>? types;

  /// Null means "the addon's top-level id prefixes".
  final List<String>? idPrefixes;
}

/// An installed addon: its manifest plus the URL it was installed from.
class StremioAddon {
  const StremioAddon({
    required this.manifestUrl,
    required this.id,
    required this.name,
    required this.version,
    required this.types,
    required this.catalogs,
    required this.resources,
    this.description,
    this.logoUrl,
    this.idPrefixes,
  });

  /// `https://…/manifest.json`; every other request is relative to it.
  final String manifestUrl;
  final String id;
  final String name;
  final String version;
  final String? description;
  final String? logoUrl;
  final List<String> types;
  final List<String>? idPrefixes;
  final List<StremioCatalog> catalogs;
  final List<StremioResource> resources;

  /// The URL the resource paths hang off (the manifest URL without
  /// `/manifest.json`).
  String get baseUrl {
    final u = manifestUrl.split('?').first;
    return u.endsWith('/manifest.json')
        ? u.substring(0, u.length - '/manifest.json'.length)
        : u.replaceFirst(RegExp(r'/+$'), '');
  }

  /// Whether this addon serves [resource] for content of [type] whose id
  /// is [id] (when given).
  bool serves(String resource, String type, {String? id}) {
    for (final r in resources) {
      if (r.name != resource) continue;
      final types = r.types ?? this.types;
      if (!types.contains(type)) continue;
      final prefixes = r.idPrefixes ?? idPrefixes;
      if (id != null &&
          prefixes != null &&
          prefixes.isNotEmpty &&
          !prefixes.any(id.startsWith)) {
        continue;
      }
      return true;
    }
    return false;
  }

  /// Turns what the user pasted (also `stremio://` install links, or the
  /// addon's base URL) into the manifest URL.
  static String normalizeManifestUrl(String input) {
    var url = input.trim();
    if (url.startsWith('stremio://')) {
      url = 'https://${url.substring('stremio://'.length)}';
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final path = url.split('?').first;
    if (!path.endsWith('/manifest.json')) {
      url = '${path.replaceFirst(RegExp(r'/+$'), '')}/manifest.json';
    }
    return url;
  }

  factory StremioAddon.fromManifest(
    String manifestUrl,
    Map<String, dynamic> json,
  ) {
    List<String>? strings(Object? value) => value is List
        ? [
            for (final v in value)
              if (v is String) v,
          ]
        : null;

    final types = strings(json['types']) ?? const [];
    final resources = <StremioResource>[];
    for (final r in json['resources'] as List<dynamic>? ?? []) {
      if (r is String) {
        resources.add(StremioResource(name: r));
      } else if (r is Map<String, dynamic> && r['name'] is String) {
        resources.add(StremioResource(
          name: r['name'] as String,
          types: strings(r['types']),
          idPrefixes: strings(r['idPrefixes']),
        ));
      }
    }
    return StremioAddon(
      manifestUrl: manifestUrl,
      id: json['id'] as String? ?? manifestUrl,
      name: json['name'] as String? ?? 'Addon',
      version: json['version'] as String? ?? '',
      description: json['description'] as String?,
      logoUrl: json['logo'] as String?,
      types: types,
      idPrefixes: strings(json['idPrefixes']),
      catalogs: [
        for (final c in json['catalogs'] as List<dynamic>? ?? [])
          if (c is Map<String, dynamic>) StremioCatalog.fromJson(c),
      ],
      resources: resources,
    );
  }
}

/// An item of a catalog: a movie, a show, a TV channel…
class StremioMeta {
  const StremioMeta({
    required this.id,
    required this.type,
    required this.name,
    this.posterUrl,
    this.logoUrl,
    this.posterShape = 'poster',
    this.description,
    this.genres = const [],
  });

  final String id;
  final String type;
  final String name;
  final String? posterUrl;
  final String? logoUrl;

  /// `poster` (2:3), `landscape` (16:9) or `square`.
  final String posterShape;
  final String? description;
  final List<String> genres;

  /// The best image to show for a channel tile.
  String? get imageUrl => logoUrl ?? posterUrl;

  factory StremioMeta.fromJson(Map<String, dynamic> json) {
    String? str(String key) {
      final v = json[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return StremioMeta(
      id: str('id') ?? '',
      type: str('type') ?? '',
      name: str('name') ?? str('id') ?? '',
      posterUrl: str('poster'),
      logoUrl: str('logo'),
      posterShape: str('posterShape') ?? 'poster',
      description: str('description'),
      genres: [
        for (final g in json['genres'] as List<dynamic>? ?? [])
          if (g is String) g,
      ],
    );
  }
}

/// One way to watch an item, as an addon returns it.
class StremioStream {
  const StremioStream({
    required this.addonName,
    this.url,
    this.infoHash,
    this.fileIdx,
    this.ytId,
    this.externalUrl,
    this.name,
    this.title,
    this.headers = const {},
  });

  /// Name of the addon that returned it.
  final String addonName;

  /// A direct (HTTP/HLS) URL the player can open.
  final String? url;
  final String? infoHash;
  final int? fileIdx;
  final String? ytId;

  /// A web page to open in the browser.
  final String? externalUrl;
  final String? name;
  final String? title;

  /// HTTP headers the player must send (`behaviorHints.proxyHeaders`).
  final Map<String, String> headers;

  bool get isPlayableUrl => url != null && url!.isNotEmpty;

  /// The text to show for this stream: Stremio's `name` and `title`/
  /// `description`, whichever exist.
  String get label => [name, title]
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(' · ');

  factory StremioStream.fromJson(String addonName, Map<String, dynamic> json) {
    String? str(String key) {
      final v = json[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final hints = json['behaviorHints'];
    final headers = <String, String>{};
    if (hints is Map<String, dynamic>) {
      final proxy = hints['proxyHeaders'];
      if (proxy is Map<String, dynamic> && proxy['request'] is Map) {
        (proxy['request'] as Map).forEach((k, v) {
          if (k is String && v is String) headers[k] = v;
        });
      }
    }
    return StremioStream(
      addonName: addonName,
      url: str('url'),
      infoHash: str('infoHash'),
      fileIdx: json['fileIdx'] is int ? json['fileIdx'] as int : null,
      ytId: str('ytId'),
      externalUrl: str('externalUrl'),
      name: str('name'),
      title: str('title') ?? str('description'),
      headers: headers,
    );
  }
}
