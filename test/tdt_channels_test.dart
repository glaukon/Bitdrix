import 'package:bitdrix/data/models/tv_channel.dart';
import 'package:bitdrix/data/services/tdt_channels_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Trimmed from the real https://www.tdtchannels.com/lists/tv.json.
  final json = {
    'countries': [
      {
        'name': 'Spain',
        'ambits': [
          {
            'name': 'Generalistas',
            'channels': [
              {
                'name': 'La 1',
                'logo': 'https://example.org/la1.png',
                'epg_id': 'La1.TV',
                'options': [
                  {
                    'format': 'm3u8',
                    'url': 'https://rtvelivestream.rtve.es/la1/la1_main.m3u8',
                  },
                  {
                    'format': 'm3u8',
                    'url': 'https://ads.example/playlist.m3u8?did=[DEVICE_ID]',
                  },
                  {'format': 'youtube', 'url': 'https://youtube.com/x'},
                ],
              },
              {
                'name': 'Solo YouTube',
                'options': [
                  {'format': 'youtube', 'url': 'https://youtube.com/y'},
                ],
              },
            ],
          },
          {
            'name': 'Galicia',
            'channels': [
              {
                'name': 'TVG',
                'options': [
                  {'format': 'm3u8', 'url': 'https://tvg.example/live.m3u8'},
                ],
              },
            ],
          },
          {
            'name': 'Vacío',
            'channels': [
              {
                'name': 'Web',
                'options': [
                  {'format': 'stream', 'url': 'https://web.example'},
                ],
              },
            ],
          },
        ],
      },
    ],
  };

  test('sorts channels by where they can be watched', () {
    final groups = TdtChannelsService.parse(json);
    expect(groups.map((g) => g.name), ['Generalistas', 'Galicia', 'Vacío']);

    final la1 = groups.first.channels.first;
    expect(la1.name, 'La 1');
    expect(la1.kind, TvChannelKind.playable);
    // The ad URL with placeholders is dropped.
    expect(la1.streams, ['https://rtvelivestream.rtve.es/la1/la1_main.m3u8']);
    expect(la1.id, 'Generalistas/La 1');

    final youtube = groups.first.channels[1];
    expect(youtube.kind, TvChannelKind.youtube);
    expect(youtube.externalUrl, 'https://youtube.com/y');

    final web = groups.last.channels.single;
    expect(web.kind, TvChannelKind.web);
    expect(web.externalUrl, 'https://web.example');
  });

  test('adds the Atresmedia channels TDTChannels leaves out', () {
    final names = TdtChannelsService.parse(json).first.channels.map((c) => c.name);
    expect(names, containsAll(['Antena 3', 'laSexta', 'Neox', 'Nova']));
  });

  test('tells national categories from autonomous communities', () {
    final groups = TdtChannelsService.parse(json);
    expect(groups.first.isRegion, isFalse);
    expect(groups[1].isRegion, isTrue);
  });
}
