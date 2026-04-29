// Stub for non-web platforms. WebTorrentService is web-only;
// the provider guards instantiation with kIsWeb so this is never called.
export 'torrent_service.dart' show MockTorrentService;

// Alias so torrent_providers.dart can refer to WebTorrentService on all platforms.
import 'torrent_service.dart';

typedef WebTorrentService = MockTorrentService;
