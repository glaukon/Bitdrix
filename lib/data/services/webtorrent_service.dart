import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;

import 'package:uuid/uuid.dart';

import '../../domain/entities/torrent_entity.dart';
import '../../domain/entities/torrent_file_entity.dart';
import 'torrent_service.dart';

/// Real torrent engine backed by WebTorrent (JavaScript) via JS interop.
///
/// The bridge is initialised lazily — `init()` is called once and the
/// result (the streaming-server base URL) is awaited before any torrent
/// is added.
class WebTorrentService implements ITorrentService {
  static const _uuid = Uuid();

  final Map<String, TorrentEntity> _torrents = {};
  final Map<String, StreamController<TorrentEntity>> _statusControllers = {};
  final _allController = StreamController<List<TorrentEntity>>.broadcast();

  Timer? _pollTimer;
  Future<void>? _initFuture;

  WebTorrentService() {
    _initFuture = _initBridge();
  }

  // ── Bridge initialisation ─────────────────────────────────────────────────

  Future<void> _initBridge() async {
    final bridge = _bridge;
    if (bridge == null) return;
    try {
      await js_util.promiseToFuture<dynamic>(
        bridge.callMethod('init', []) as Object,
      );
    } catch (_) {
      // Streaming server may not be available; we'll still track progress.
    }
    _startPolling();
  }

  js.JsObject? get _bridge => js.context['bitdrixBridge'] as js.JsObject?;

  // ── Polling ───────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  void _poll() {
    final bridge = _bridge;
    if (bridge == null) return;

    var anyChanged = false;

    for (final entry in _torrents.entries.toList()) {
      final id = entry.key;
      final current = entry.value;

      if (current.status == TorrentStatus.completed ||
          current.status == TorrentStatus.paused ||
          current.status == TorrentStatus.error) {
        continue;
      }

      final statusJson = bridge.callMethod('getStatus', [id]) as String?;
      if (statusJson == null) continue;

      final data = json.decode(statusJson) as Map<String, dynamic>;
      final progress = (data['progress'] as num).toDouble();
      final dlSpeed = (data['downloadSpeed'] as num).toDouble();
      final ulSpeed = (data['uploadSpeed'] as num).toDouble();
      final peers = (data['numPeers'] as num).toInt();
      final downloaded = (data['downloaded'] as num).toInt();
      final length = (data['length'] as num? ?? 0).toInt();
      final done = data['done'] as bool? ?? false;

      final newStatus =
          done ? TorrentStatus.completed : TorrentStatus.downloading;

      final updated = current.copyWith(
        progress: done ? 1.0 : progress,
        downloadSpeed: dlSpeed,
        uploadSpeed: ulSpeed,
        peers: peers,
        downloadedSize: downloaded,
        totalSize: length > 0 ? length : current.totalSize,
        status: newStatus,
      );

      _torrents[id] = updated;
      _statusControllers[id]?.add(updated);
      anyChanged = true;
    }

    if (anyChanged) {
      _allController.add(currentTorrents);
    }
  }

  // ── ITorrentService ───────────────────────────────────────────────────────

  @override
  Future<TorrentEntity> addMagnet(String magnetLink) async {
    await _initFuture;

    final id = _uuid.v4();

    final initial = TorrentEntity(
      id: id,
      name: _nameFromMagnet(magnetLink),
      magnetLink: magnetLink,
      totalSize: 1,
      downloadedSize: 0,
      uploadedSize: 0,
      downloadSpeed: 0,
      uploadSpeed: 0,
      progress: 0,
      status: TorrentStatus.queued,
      files: [],
      addedAt: DateTime.now(),
      peers: 0,
      seeds: 0,
    );

    _torrents[id] = initial;
    _statusControllers[id] = StreamController<TorrentEntity>.broadcast();
    _allController.add(currentTorrents);

    final bridge = _bridge;
    if (bridge == null) return initial;

    final completer = Completer<Map<String, dynamic>>();

    bridge.callMethod('addMagnet', [
      magnetLink,
      id,
      js.allowInterop((String result) {
        if (!completer.isCompleted) {
          completer.complete(json.decode(result) as Map<String, dynamic>);
        }
      }),
      js.allowInterop((String error) {
        if (!completer.isCompleted) completer.completeError(error);
      }),
    ]);

    try {
      final data = await completer.future;
      final streamUrl = data['streamUrl'] as String?;
      final name = (data['name'] as String?) ?? initial.name;
      final length = (data['length'] as num? ?? 0).toInt();

      final ready = (_torrents[id] ?? initial).copyWith(
        name: name.isNotEmpty ? name : initial.name,
        totalSize: length > 0 ? length : 1,
        status: TorrentStatus.downloading,
        streamUrl: streamUrl,
      );
      _torrents[id] = ready;
      _statusControllers[id]?.add(ready);
      _allController.add(currentTorrents);
      return ready;
    } catch (e) {
      final errEntity = (_torrents[id] ?? initial).copyWith(
        status: TorrentStatus.error,
        errorMessage: e.toString(),
      );
      _torrents[id] = errEntity;
      _statusControllers[id]?.add(errEntity);
      _allController.add(currentTorrents);
      return errEntity;
    }
  }

  @override
  Future<TorrentEntity> addTorrentFile(String filePath) =>
      addMagnet('magnet:?'); // .torrent file support TBD

  @override
  Future<void> pause(String torrentId) async {
    _bridge?.callMethod('pause', [torrentId]);
    final t = _torrents[torrentId];
    if (t == null) return;
    final updated = t.copyWith(
      status: TorrentStatus.paused,
      downloadSpeed: 0,
      uploadSpeed: 0,
    );
    _torrents[torrentId] = updated;
    _statusControllers[torrentId]?.add(updated);
    _allController.add(currentTorrents);
  }

  @override
  Future<void> resume(String torrentId) async {
    _bridge?.callMethod('resume', [torrentId]);
    final t = _torrents[torrentId];
    if (t == null || !t.canResume) return;
    final updated = t.copyWith(status: TorrentStatus.downloading);
    _torrents[torrentId] = updated;
    _statusControllers[torrentId]?.add(updated);
    _allController.add(currentTorrents);
  }

  @override
  Future<void> remove(String torrentId, {bool deleteFiles = false}) async {
    _bridge?.callMethod('remove', [torrentId]);
    _torrents.remove(torrentId);
    final ctrl = _statusControllers.remove(torrentId);
    ctrl?.close();
    _allController.add(currentTorrents);
  }

  @override
  Stream<TorrentEntity> getStatus(String torrentId) {
    _statusControllers.putIfAbsent(
      torrentId,
      () => StreamController<TorrentEntity>.broadcast(),
    );
    final current = _torrents[torrentId];
    final broadcastStream = _statusControllers[torrentId]!.stream;
    if (current == null) return broadcastStream;

    late StreamController<TorrentEntity> seed;
    seed = StreamController<TorrentEntity>(
      onListen: () {
        seed.add(current);
        broadcastStream.listen(
          seed.add,
          onError: seed.addError,
          onDone: seed.close,
        );
      },
    );
    return seed.stream;
  }

  @override
  Future<List<TorrentFileEntity>> getFiles(String torrentId) async =>
      _torrents[torrentId]?.files ?? [];

  @override
  Future<void> selectFileForStreaming(String torrentId, String fileId) async {
    final torrent = _torrents[torrentId];
    if (torrent == null) return;

    final updatedFiles = torrent.files.map((file) {
      return file.copyWith(
        priority: file.id == fileId ? FilePriority.high : FilePriority.normal,
      );
    }).toList();

    // Keep the HTTP streaming URL set by the WebTorrent server — do NOT replace
    // it with the relative torrent-internal file path from TorrentFileEntity.path.
    final updated = torrent.copyWith(files: updatedFiles);
    _torrents[torrentId] = updated;
    _statusControllers[torrentId]?.add(updated);
    _allController.add(currentTorrents);
  }

  @override
  Stream<List<TorrentEntity>> get allTorrentsStream => _allController.stream;

  @override
  List<TorrentEntity> get currentTorrents => _torrents.values.toList();

  @override
  void dispose() {
    _pollTimer?.cancel();
    for (final c in _statusControllers.values) {
      c.close();
    }
    _allController.close();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _nameFromMagnet(String magnet) {
    final m = RegExp(r'[&?]dn=([^&]+)').firstMatch(magnet);
    if (m != null) {
      return Uri.decodeComponent(m.group(1)!.replaceAll('+', ' '));
    }
    return 'Torrent ${DateTime.now().millisecondsSinceEpoch % 10000}';
  }
}
