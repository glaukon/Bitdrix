/// How a channel can be watched.
enum TvChannelKind {
  /// An open HLS stream the built-in player opens.
  playable,

  /// Only on YouTube: opened in the YouTube app or website.
  youtube,

  /// Only on the broadcaster's website (or an embedded web player): opened
  /// in the browser.
  web,
}

/// A live TV channel from the TDTChannels list
/// (https://github.com/LaQuay/TDTChannels): the free, official live streams
/// Spanish broadcasters publish on their own websites.
class TvChannel {
  const TvChannel({
    required this.name,
    required this.group,
    this.streams = const [],
    this.externalUrl,
    this.logoUrl,
    this.epgId,
  });

  final String name;

  /// TDTChannels "ambit": a national category ("Generalistas", "Deportivos")
  /// or a region ("Andalucía", "Galicia").
  final String group;

  /// Playable HLS (m3u8) URLs, best first. Empty for external channels.
  final List<String> streams;

  /// Where to watch a channel that cannot play in the app: its YouTube live
  /// page or the broadcaster's website.
  final String? externalUrl;

  final String? logoUrl;

  /// Id in the TDTChannels programme guide.
  final String? epgId;

  /// Stable id for favourites: groups can repeat a channel name.
  String get id => '$group/$name';

  TvChannelKind get kind {
    if (streams.isNotEmpty) return TvChannelKind.playable;
    final url = externalUrl ?? '';
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return TvChannelKind.youtube;
    }
    return TvChannelKind.web;
  }

  /// Parses one channel. Returns null only when there is nowhere at all to
  /// watch it.
  static TvChannel? fromJson(Map<String, dynamic> json, String group) {
    final options = (json['options'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((o) => o['url'] is String && (o['url'] as String).isNotEmpty)
        .toList();
    String? firstOf(String format) =>
        options.where((o) => o['format'] == format).firstOrNull?['url']
            as String?;

    final streams = [
      for (final o in options)
        if (o['format'] == 'm3u8' &&
            // Ad-insertion endpoints need device placeholders filled in.
            !(o['url'] as String).contains('[')) o['url'] as String,
    ];
    final web = json['web'] as String?;
    final externalUrl = firstOf('youtube') ??
        firstOf('stream') ??
        (web != null && web.isNotEmpty ? web : null);
    if (streams.isEmpty && externalUrl == null) return null;

    final logo = json['logo'] as String?;
    return TvChannel(
      name: (json['name'] as String? ?? '').trim(),
      group: group,
      streams: streams,
      externalUrl: externalUrl,
      logoUrl: logo != null && logo.isNotEmpty ? logo : null,
      epgId: json['epg_id'] as String?,
    );
  }
}

/// A TDTChannels category with its channels.
class TvChannelGroup {
  const TvChannelGroup({
    required this.name,
    required this.channels,
    required this.isRegion,
  });

  final String name;
  final List<TvChannel> channels;

  /// True for an autonomous-community group, false for a national category.
  final bool isRegion;
}
