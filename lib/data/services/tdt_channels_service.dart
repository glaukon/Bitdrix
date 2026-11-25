import 'package:dio/dio.dart';

import '../models/tv_channel.dart';

/// Loads Spain's free live TV channels from TDTChannels
/// (https://github.com/LaQuay/TDTChannels), a community-maintained list of
/// the official streams broadcasters publish themselves.
class TdtChannelsService {
  TdtChannelsService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ));

  static const listUrl = 'https://www.tdtchannels.com/lists/tv.json';

  /// National categories; every other group is an autonomous community.
  static const nationalGroups = {
    'Generalistas',
    'Informativos',
    'Deportivos',
    'Infantiles',
    'Eventuales',
    'Streaming',
  };

  /// Atresmedia protects its live streams, so TDTChannels leaves its
  /// channels out; they are free to watch on atresplayer, so link there.
  static const _atresmedia = [
    TvChannel(
      name: 'Antena 3',
      group: 'Generalistas',
      externalUrl: 'https://www.atresplayer.com/directos/antena3/',
    ),
    TvChannel(
      name: 'laSexta',
      group: 'Generalistas',
      externalUrl: 'https://www.atresplayer.com/directos/lasexta/',
    ),
    TvChannel(
      name: 'Neox',
      group: 'Generalistas',
      externalUrl: 'https://www.atresplayer.com/directos/neox/',
    ),
    TvChannel(
      name: 'Nova',
      group: 'Generalistas',
      externalUrl: 'https://www.atresplayer.com/directos/nova/',
    ),
    TvChannel(
      name: 'Mega',
      group: 'Generalistas',
      externalUrl: 'https://www.atresplayer.com/directos/mega/',
    ),
    TvChannel(
      name: 'Atreseries',
      group: 'Generalistas',
      externalUrl: 'https://www.atresplayer.com/directos/atreseries/',
    ),
  ];

  final Dio _dio;

  /// Spain's channel groups in list order, keeping only playable channels.
  Future<List<TvChannelGroup>> fetchGroups() async {
    final response = await _dio.get<Map<String, dynamic>>(listUrl);
    return parse(response.data ?? const {});
  }

  static List<TvChannelGroup> parse(Map<String, dynamic> json) {
    final countries = (json['countries'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>();
    final spain = countries.firstWhere(
      (c) => c['name'] == 'Spain',
      orElse: () => countries.isEmpty ? const {} : countries.first,
    );
    final groups = <TvChannelGroup>[];
    for (final ambit in (spain['ambits'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()) {
      final name = (ambit['name'] as String? ?? '').trim();
      final channels = [
        for (final c in (ambit['channels'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>())
          ?TvChannel.fromJson(c, name),
      ];
      if (name == 'Generalistas') {
        final present = channels.map((c) => c.name.toLowerCase()).toSet();
        channels.addAll(_atresmedia
            .where((c) => !present.contains(c.name.toLowerCase())));
      }
      if (name.isEmpty || channels.isEmpty) continue;
      groups.add(TvChannelGroup(
        name: name,
        channels: channels,
        isRegion: !nationalGroups.contains(name),
      ));
    }
    return groups;
  }
}
