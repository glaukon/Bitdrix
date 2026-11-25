/// A torrent source returned by the Torrentio Stremio add-on API.
class StreamSourceModel {
  const StreamSourceModel({
    required this.name,
    required this.title,
    this.infoHash,
    this.magnetUrl,
    this.behaviorHintsFilename,
  });

  /// Short label, e.g. `"[1080p] Inception.2010.BluRay"`.
  final String name;

  /// Detailed title that may include size, seeds, etc.
  final String title;

  /// Torrent info hash (hex string), used to build a magnet URI.
  final String? infoHash;

  /// Full magnet URL if the API provides one directly.
  final String? magnetUrl;

  /// Actual filename from `behaviorHints.filename`.
  final String? behaviorHintsFilename;

  // ── Derived getters ────────────────────────────────────────────────────────

  static const List<String> castilianAudioTags = [
    // Torrentio marks Spain-Spanish audio with this flag in the title.
    '🇪🇸',
    'castellano',
    'cast',
    'es-es',
    ' esp ',
    ' spa ',
  ];

  static const List<String> latinSpanishAudioTags = [
    // Torrentio's flag for Latin-American Spanish audio.
    '🇲🇽',
    'latino',
    'latin',
    'latam',
    'es-la',
    'es-mx',
  ];

  static const List<String> genericSpanishAudioTags = [
    'spanish',
    'es-es',
    'spa',
  ];

  static const List<String> multiAudioTags = [
    'multi',
    'multi audio',
    'dual audio',
  ];

  String get searchableText =>
      ' $name $title ${behaviorHintsFilename ?? ''} '.toLowerCase();

  /// Quality label parsed from [name].
  /// Returns one of: `'4K'`, `'1080p'`, `'720p'`, `'480p'`, `'Unknown'`.
  String get quality {
    final lower = name.toLowerCase();
    if (lower.contains('2160p') || lower.contains('4k')) return '4K';
    if (lower.contains('1080p')) return '1080p';
    if (lower.contains('720p')) return '720p';
    if (lower.contains('480p')) return '480p';
    return 'Unknown';
  }

  /// Seeder count parsed from [title].
  ///
  /// Torrentio embeds seeder counts with a 👤 emoji, e.g. `"👤 123"`.
  int? get seeders {
    // Match "👤 <digits>" — the emoji may appear directly before the number.
    final pattern = RegExp(r'👤\s*(\d+)');
    final match = pattern.firstMatch(title);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// True when the source name/title suggests Castilian Spanish audio.
  bool get hasCastilianAudioTag =>
      _containsAnyTag(searchableText, castilianAudioTags);

  /// True when the source name/title suggests Latin American Spanish audio.
  bool get hasLatinSpanishAudioTag =>
      _containsAnyTag(searchableText, latinSpanishAudioTags);

  /// True when the source name/title suggests Spanish audio of unknown region.
  bool get hasGenericSpanishAudioTag =>
      _containsAnyTag(searchableText, genericSpanishAudioTags);

  /// True when any Spanish audio signal is available.
  bool get hasSpanishAudioTag =>
      hasCastilianAudioTag ||
      hasLatinSpanishAudioTag ||
      hasGenericSpanishAudioTag;

  /// True when the source name/title suggests multiple audio tracks.
  bool get hasMultiAudioTag => _containsAnyTag(searchableText, multiAudioTags);

  /// Labels shown in source lists so users can spot likely multi-audio files.
  List<String> get audioBadges => [
        if (hasCastilianAudioTag) 'CAST',
        if (!hasCastilianAudioTag && hasGenericSpanishAudioTag) 'ESP',
        if (hasLatinSpanishAudioTag) 'LAT',
        if (hasMultiAudioTag) 'MULTi',
      ];

  /// Returns a usable magnet URL.
  ///
  /// Prefers [magnetUrl] if available; otherwise builds one from [infoHash].
  String? get resolvedMagnetUrl {
    if (magnetUrl != null && magnetUrl!.isNotEmpty) return magnetUrl;
    if (infoHash != null && infoHash!.isNotEmpty) {
      final encodedName = Uri.encodeComponent(
        behaviorHintsFilename ?? name,
      );
      return 'magnet:?xt=urn:btih:$infoHash&dn=$encodedName'
          '&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce'
          '&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce'
          '&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce';
    }
    return null;
  }

  // ── Serialization ──────────────────────────────────────────────────────────

  factory StreamSourceModel.fromJson(Map<String, dynamic> json) {
    final behaviorHints = json['behaviorHints'] as Map<String, dynamic>?;
    return StreamSourceModel(
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      infoHash: json['infoHash'] as String?,
      magnetUrl: json['magnetUrl'] as String?,
      behaviorHintsFilename: behaviorHints?['filename'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'title': title,
        'infoHash': infoHash,
        'magnetUrl': magnetUrl,
        'behaviorHints': behaviorHintsFilename != null
            ? {'filename': behaviorHintsFilename}
            : null,
      };

  static bool _containsAnyTag(String text, List<String> tags) {
    return tags.any((tag) {
      final escaped = RegExp.escape(tag.trim());
      final pattern = RegExp(r'(^|[^a-z0-9])' + escaped + r'([^a-z0-9]|$)');
      return pattern.hasMatch(text);
    });
  }
}
