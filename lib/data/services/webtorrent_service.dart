import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/torrent_entity.dart';
import '../../domain/entities/torrent_file_entity.dart';
import 'base_torrent_service.dart';

/// Browser engine backed by WebTorrent (see `web/webtorrent_bridge.js`).
///
/// Browsers can only reach WebRTC peers, so many classic torrents will find no
/// peers here. Added torrents are remembered and re-added on the next visit.
class WebTorrentService extends BaseTorrentService {
  WebTorrentService() {
    _ready = _init();
  }

  static const _uuid = Uuid();
  static const _storeKey = 'webtorrent_torrents';

  late final Future<void> _ready;
  Timer? _poll;
  SharedPreferences? _prefs;

  /// id → {source, addedAt}
  final Map<String, Map<String, dynamic>> _saved = {};

  JSObject? get _bridge => globalContext.getProperty<JSObject?>('bitdrixBridge'.toJS);

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final bridge = _bridge;
    if (bridge == null) return;
    try {
      await bridge.callMethod<JSPromise<JSAny?>>('init'.toJS).toDart;
    } catch (e) {
      debugPrint('WebTorrent init failed: $e');
    }
    _restore();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  void _restore() {
    final raw = _prefs?.getString(_storeKey);
    if (raw == null) return;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      map.forEach((id, value) {
        final entry = Map<String, dynamic>.from(value as Map);
        final source = entry['source'] as String;
        _saved[id] = entry;
        final addedAt = DateTime.fromMillisecondsSinceEpoch(
          (entry['addedAt'] as num?)?.toInt() ?? 0,
        );
        put(placeholder(
          id: id,
          name: entry['name'] as String? ?? 'Torrent',
          magnetLink: source.startsWith('magnet:') ? source : null,
        ).copyWith(addedAt: addedAt));
        _addToBridge(id, source);
      });
    } catch (e) {
      debugPrint('Could not restore web torrents: $e');
    }
  }

  Future<void> _persist() async {
    await _prefs?.setString(_storeKey, json.encode(_saved));
  }

  // ── Bridge calls ──────────────────────────────────────────────────────────

  void _addToBridge(String id, String source) {
    final bridge = _bridge;
    if (bridge == null) {
      update(
        id,
        (t) => t.copyWith(
          status: TorrentStatus.error,
          errorMessage: 'WebTorrent no está disponible en este navegador.',
        ),
      );
      return;
    }
    bridge.callMethodVarArgs<JSAny?>('add'.toJS, [
      source.toJS,
      id.toJS,
      ((JSString result) => _onReady(id, result.toDart)).toJS,
      ((JSString error) => update(
            id,
            (t) => t.copyWith(status: TorrentStatus.error, errorMessage: error.toDart),
          )).toJS,
    ]);
  }

  void _onReady(String id, String payload) {
    final data = json.decode(payload) as Map<String, dynamic>;
    final rawFiles = (data['files'] as List<dynamic>? ?? const []);
    final files = <TorrentFileEntity>[
      for (var i = 0; i < rawFiles.length; i++)
        TorrentFileEntity(
          id: '$id-$i',
          name: (rawFiles[i] as Map)['name'] as String,
          path: (rawFiles[i] as Map)['path'] as String,
          size: ((rawFiles[i] as Map)['length'] as num).toInt(),
          downloadedSize: 0,
          progress: 0,
          priority: FilePriority.normal,
        ),
    ];
    final name = data['name'] as String? ?? '';
    update(
      id,
      (t) => t.copyWith(
        name: name.isNotEmpty ? name : null,
        infoHash: data['infoHash'] as String?,
        totalSize: (data['length'] as num?)?.toInt(),
        status: TorrentStatus.downloading,
        files: files,
        clearError: true,
      ),
    );
    final saved = _saved[id];
    if (saved != null && name.isNotEmpty) {
      saved['name'] = name;
      unawaited(_persist());
    }
  }

  void _refresh() {
    final bridge = _bridge;
    if (bridge == null) return;
    for (final id in torrents.keys.toList()) {
      final raw = bridge.callMethod<JSString?>('getStatus'.toJS, id.toJS)?.toDart;
      if (raw == null) continue;
      final s = json.decode(raw) as Map<String, dynamic>;
      final current = torrents[id]!;
      if (current.status == TorrentStatus.error) continue;

      final done = s['done'] == true;
      final paused = s['paused'] == true;
      final fileBytes = (s['files'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toInt())
          .toList();
      final files = [
        for (var i = 0; i < current.files.length; i++)
          i < fileBytes.length ? _withProgress(current.files[i], fileBytes[i]) : current.files[i],
      ];
      final length = (s['length'] as num?)?.toInt() ?? 0;

      put(current.copyWith(
        progress: done ? 1.0 : (s['progress'] as num?)?.toDouble(),
        downloadSpeed: paused ? 0 : (s['downloadSpeed'] as num?)?.toDouble(),
        uploadSpeed: (s['uploadSpeed'] as num?)?.toDouble(),
        peers: (s['numPeers'] as num?)?.toInt(),
        downloadedSize: (s['downloaded'] as num?)?.toInt(),
        uploadedSize: (s['uploaded'] as num?)?.toInt(),
        totalSize: length > 0 ? length : null,
        status: done
            ? TorrentStatus.completed
            : paused
                ? TorrentStatus.paused
                : s['ready'] == true
                    ? TorrentStatus.downloading
                    : TorrentStatus.queued,
        files: files,
      ));
    }
  }

  TorrentFileEntity _withProgress(TorrentFileEntity f, int bytes) => f.copyWith(
        downloadedSize: bytes,
        contiguousDownloadedSize: bytes,
        bufferedSize: bytes,
        progress: f.size > 0 ? (bytes / f.size).clamp(0.0, 1.0) : 0,
      );

  // ── ITorrentService ───────────────────────────────────────────────────────

  @override
  Future<TorrentEntity> addMagnet(String magnetLink) => _add(
        magnetLink,
        TorrentServiceUtils.nameFromMagnet(magnetLink),
        magnetLink: magnetLink,
      );

  /// On the web [filePath] is a `data:` URI produced by the file picker.
  @override
  Future<TorrentEntity> addTorrentFile(String filePath) {
    final nameMatch = RegExp(r';name=([^;]+);').firstMatch(filePath);
    final name = nameMatch != null
        ? TorrentServiceUtils.nameFromTorrentPath(Uri.decodeComponent(nameMatch.group(1)!))
        : 'Torrent';
    return _add(filePath, name);
  }

  Future<TorrentEntity> _add(String source, String name, {String? magnetLink}) async {
    await _ready;
    final id = _uuid.v4();
    final initial = placeholder(id: id, name: name, magnetLink: magnetLink);
    put(initial);
    _saved[id] = {
      'source': source,
      'name': name,
      'addedAt': initial.addedAt.millisecondsSinceEpoch,
    };
    await _persist();
    _addToBridge(id, source);
    return initial;
  }

  @override
  Future<void> pause(String torrentId) async {
    _bridge?.callMethod<JSAny?>('pause'.toJS, torrentId.toJS);
    update(
      torrentId,
      (t) => t.copyWith(status: TorrentStatus.paused, downloadSpeed: 0, uploadSpeed: 0),
    );
  }

  @override
  Future<void> resume(String torrentId) async {
    final t = torrents[torrentId];
    if (t?.status == TorrentStatus.error) {
      // Retry from scratch.
      final source = _saved[torrentId]?['source'] as String?;
      if (source != null) {
        update(torrentId, (t) => t.copyWith(status: TorrentStatus.queued, clearError: true));
        _addToBridge(torrentId, source);
      }
      return;
    }
    _bridge?.callMethod<JSAny?>('resume'.toJS, torrentId.toJS);
    update(torrentId, (t) => t.copyWith(status: TorrentStatus.downloading));
  }

  @override
  Future<void> remove(String torrentId, {bool deleteFiles = false}) async {
    _bridge?.callMethod<JSAny?>('remove'.toJS, torrentId.toJS);
    _saved.remove(torrentId);
    await _persist();
    drop(torrentId);
  }

  @override
  Future<void> selectFileForStreaming(String torrentId, String fileId) async {
    final index = int.tryParse(fileId.split('-').last) ?? 0;
    final url = _bridge
        ?.callMethod<JSString?>('streamUrl'.toJS, torrentId.toJS, index.toJS)
        ?.toDart;
    if (url == null) {
      throw StateError('Este torrent todavía no se puede reproducir.');
    }
    update(
      torrentId,
      (t) => t.copyWith(
        streamUrl: url,
        files: t.files
            .map((f) => f.copyWith(
                  priority: f.id == fileId ? FilePriority.high : FilePriority.normal,
                ))
            .toList(),
      ),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
