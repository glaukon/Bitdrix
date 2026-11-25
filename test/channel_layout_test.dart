import 'package:bitdrix/data/models/stremio_addon.dart';
import 'package:bitdrix/presentation/widgets/channel_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

StremioMeta meta(String shape, {bool logo = true}) => StremioMeta(
      id: 'x',
      type: 'tv',
      name: 'X',
      posterUrl: 'https://img/p.jpg',
      logoUrl: logo ? 'https://img/l.png' : null,
      posterShape: shape,
    );

void main() {
  test('TvVoo channels (square) keep the logo tile', () {
    expect(channelLayoutFor([meta('square'), meta('square')]),
        ChannelCardLayout.logo);
  });

  test('event posters get the big poster tile, logo or not', () {
    expect(channelLayoutFor([meta('poster'), meta('poster', logo: false)]),
        ChannelCardLayout.poster);
  });

  test('landscape stills get the wide tile', () {
    expect(channelLayoutFor([meta('landscape'), meta('landscape')]),
        ChannelCardLayout.landscape);
  });
}
