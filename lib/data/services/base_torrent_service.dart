import 'dart:async';

import '../../domain/entities/torrent_entity.dart';
import '../../domain/entities/torrent_file_entity.dart';
import 'torrent_service.dart';

/// Shared in-memory store and stream plumbing for the real torrent engines.
///
/// Subclasses talk to their engine and call [put] / [update] / [drop]; this
/// class keeps the snapshots and notifies [allTorrentsStream] and the
/// per-torrent [getStatus] streams.
abstract class BaseTorrentService implements ITorrentService {
  final Map<String, TorrentEntity> torrents = {};
  final Map<String, StreamController<TorrentEntity>> _statusCtrls = {};
  final StreamController<List<TorrentEntity>> _allCtrl =
      StreamController<List<TorrentEntity>>.broadcast();

  /// Stores [torrent] (insert or replace) and notifies listeners.
  void put(TorrentEntity torrent) {
    torrents[torrent.id] = torrent;
    _statusCtrls[torrent.id]?.add(torrent);
    _allCtrl.add(currentTorrents);
  }

  /// Applies [fn] to the stored torrent [id], if present.
  void update(String id, TorrentEntity Function(TorrentEntity) fn) {
    final current = torrents[id];
    if (current != null) put(fn(current));
  }

  /// Forgets torrent [id] locally.
  void drop(String id) {
    torrents.remove(id);
    _statusCtrls.remove(id)?.close();
    _allCtrl.add(currentTorrents);
  }

  /// Placeholder entity shown while the engine resolves the torrent.
  TorrentEntity placeholder({
    required String id,
    required String name,
    String? magnetLink,
    String? filePath,
    String? infoHash,
  }) {
    return TorrentEntity(
      id: id,
      name: name,
      magnetLink: magnetLink,
      filePath: filePath,
      infoHash: infoHash,
      totalSize: 0,
      downloadedSize: 0,
      uploadedSize: 0,
      downloadSpeed: 0,
      uploadSpeed: 0,
      progress: 0,
      status: TorrentStatus.queued,
      files: const [],
      addedAt: DateTime.now(),
      peers: 0,
      seeds: 0,
    );
  }

  @override
  Stream<TorrentEntity> getStatus(String torrentId) {
    final ctrl = _statusCtrls.putIfAbsent(
      torrentId,
      () => StreamController<TorrentEntity>.broadcast(),
    );
    final current = torrents[torrentId];
    if (current == null) return ctrl.stream;

    // Emit the current snapshot first, then forward live updates.
    late StreamController<TorrentEntity> seeded;
    StreamSubscription<TorrentEntity>? sub;
    seeded = StreamController<TorrentEntity>(
      onListen: () {
        seeded.add(torrents[torrentId] ?? current);
        sub = ctrl.stream.listen(
          seeded.add,
          onError: seeded.addError,
          onDone: seeded.close,
        );
      },
      onCancel: () => sub?.cancel(),
    );
    return seeded.stream;
  }

  @override
  Future<List<TorrentFileEntity>> getFiles(String torrentId) async =>
      torrents[torrentId]?.files ?? const [];

  @override
  Stream<List<TorrentEntity>> get allTorrentsStream => _allCtrl.stream;

  @override
  List<TorrentEntity> get currentTorrents => torrents.values.toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  @override
  void dispose() {
    for (final c in _statusCtrls.values) {
      c.close();
    }
    _allCtrl.close();
  }
}

/// Helpers shared by the engines.
class TorrentServiceUtils {
  TorrentServiceUtils._();

  static String nameFromMagnet(String magnet) {
    final m = RegExp(r'[&?]dn=([^&]+)').firstMatch(magnet);
    if (m != null) {
      try {
        return Uri.decodeQueryComponent(m.group(1)!);
      } catch (_) {
        return m.group(1)!;
      }
    }
    return 'Torrent';
  }

  /// Extracts the v1 info hash (lowercase hex) from a magnet link, if present.
  static String? infoHashFromMagnet(String magnet) {
    final hex = RegExp(r'[?&]xt=urn:btih:([0-9a-fA-F]{40})').firstMatch(magnet);
    if (hex != null) return hex.group(1)!.toLowerCase();
    final b32 = RegExp(r'[?&]xt=urn:btih:([A-Za-z2-7]{32})').firstMatch(magnet);
    if (b32 != null) return _base32ToHex(b32.group(1)!.toUpperCase());
    return null;
  }

  static String nameFromTorrentPath(String path) {
    final fileName = path.split('/').last.split('\\').last;
    final name = fileName.toLowerCase().endsWith('.torrent')
        ? fileName.substring(0, fileName.length - 8)
        : fileName;
    return name.isNotEmpty ? name : 'Torrent';
  }

  static String _base32ToHex(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    var bits = 0;
    var bitCount = 0;
    final out = StringBuffer();
    for (final c in input.split('')) {
      final idx = alphabet.indexOf(c);
      if (idx < 0) continue;
      bits = ((bits << 5) | idx) & 0xFFFF;
      bitCount += 5;
      if (bitCount >= 8) {
        bitCount -= 8;
        out.write(((bits >> bitCount) & 0xFF).toRadixString(16).padLeft(2, '0'));
      }
    }
    return out.toString();
  }
}
