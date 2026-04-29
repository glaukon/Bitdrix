import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/torrent_entity.dart';
import '../../domain/entities/torrent_file_entity.dart';
import 'torrent_service.dart';

/// Real torrent engine for Android/iOS backed by libtorrent4j via platform channels.
class NativeTorrentService implements ITorrentService {
  static const _channel = MethodChannel('com.bitdrix.bitdrix/torrent');
  static const _events = EventChannel('com.bitdrix.bitdrix/torrent_updates');
  static const _uuid = Uuid();

  final _torrents = <String, TorrentEntity>{};
  final _statusCtrls = <String, StreamController<TorrentEntity>>{};
  final _allCtrl = StreamController<List<TorrentEntity>>.broadcast();
  final _loadingFiles = <String>{};
  late final StreamSubscription<dynamic> _sub;

  NativeTorrentService() {
    _sub = _events
        .receiveBroadcastStream()
        .listen(_onNativeUpdate, onError: (_) {});
  }

  // ── Native event handler ──────────────────────────────────────────────────

  void _onNativeUpdate(dynamic raw) {
    try {
      final map = json.decode(raw as String) as Map<String, dynamic>;
      final id = map['id'] as String? ?? '';
      final current = _torrents[id];
      // ignore: avoid_print
      print('NTS update id=$id status=${map['status']} currentNull=${current == null}');
      if (current == null) return;

      final newStatus = _parseStatus(map['status'] as String? ?? 'downloading');
      final rawName = map['name'] as String?;
      final rawTotal = (map['totalSize'] as num?)?.toInt() ?? 0;
      final parsedFiles = _parseFiles(map['files']);

      final updated = current.copyWith(
        name: (rawName != null && rawName.isNotEmpty) ? rawName : null,
        progress: (map['progress'] as num?)?.toDouble(),
        downloadSpeed: (map['downloadSpeed'] as num?)?.toDouble() ?? 0,
        uploadSpeed: (map['uploadSpeed'] as num?)?.toDouble() ?? 0,
        peers: (map['peers'] as num?)?.toInt() ?? 0,
        seeds: (map['seeds'] as num?)?.toInt() ?? 0,
        downloadedSize: (map['downloadedSize'] as num?)?.toInt(),
        uploadedSize: (map['uploadedSize'] as num?)?.toInt(),
        totalSize: rawTotal > 0 ? rawTotal : null,
        status: newStatus,
        files: parsedFiles ?? current.files,
        errorMessage: map['errorMessage'] as String?,
      );

      // ignore: avoid_print
      print('NTS updated status=${updated.status}');
      _torrents[id] = updated;
      _statusCtrls[id]?.add(updated);
      _allCtrl.add(currentTorrents);

      if ((parsedFiles == null || parsedFiles.isEmpty) &&
          updated.files.isEmpty &&
          updated.totalSize > 0 &&
          updated.status != TorrentStatus.error) {
        _scheduleFilesLoad(id);
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('NTS ERROR: $e\n$st');
    }
  }

  TorrentStatus _parseStatus(String s) => switch (s) {
        'completed' => TorrentStatus.completed,
        'paused' => TorrentStatus.paused,
        'error' => TorrentStatus.error,
        'queued' => TorrentStatus.queued,
        _ => TorrentStatus.downloading,
      };

  // ── ITorrentService ───────────────────────────────────────────────────────

  @override
  Future<TorrentEntity> addMagnet(String magnetLink) async {
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
      files: const [],
      addedAt: DateTime.now(),
      peers: 0,
      seeds: 0,
    );

    _torrents[id] = initial;
    _statusCtrls[id] = StreamController<TorrentEntity>.broadcast();
    _allCtrl.add(currentTorrents);

    await _channel.invokeMethod<void>('addMagnet', {'magnet': magnetLink, 'id': id});
    return initial;
  }

  @override
  Future<TorrentEntity> addTorrentFile(String filePath) async {
    final id = _uuid.v4();
    final fileName = filePath.split('/').last.split('\\').last;
    final name = fileName.endsWith('.torrent')
        ? fileName.substring(0, fileName.length - 8)
        : fileName;

    final initial = TorrentEntity(
      id: id,
      name: name.isNotEmpty ? name : 'Torrent',
      filePath: filePath,
      totalSize: 1,
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

    _torrents[id] = initial;
    _statusCtrls[id] = StreamController<TorrentEntity>.broadcast();
    _allCtrl.add(currentTorrents);

    await _channel.invokeMethod<void>('addTorrentFile', {'filePath': filePath, 'id': id});
    return initial;
  }

  @override
  Future<void> pause(String torrentId) async {
    await _channel.invokeMethod<void>('pause', {'id': torrentId});
    _updateLocal(torrentId, (t) => t.copyWith(
          status: TorrentStatus.paused,
          downloadSpeed: 0,
          uploadSpeed: 0,
        ));
  }

  @override
  Future<void> resume(String torrentId) async {
    await _channel.invokeMethod<void>('resume', {'id': torrentId});
    _updateLocal(torrentId,
        (t) => t.copyWith(status: TorrentStatus.downloading));
  }

  @override
  Future<void> remove(String torrentId, {bool deleteFiles = false}) async {
    await _channel.invokeMethod<void>(
        'remove', {'id': torrentId, 'deleteFiles': deleteFiles});
    _torrents.remove(torrentId);
    _statusCtrls.remove(torrentId)?.close();
    _allCtrl.add(currentTorrents);
  }

  @override
  Stream<TorrentEntity> getStatus(String torrentId) {
    _statusCtrls.putIfAbsent(
        torrentId, () => StreamController<TorrentEntity>.broadcast());
    final current = _torrents[torrentId];
    final broadcast = _statusCtrls[torrentId]!.stream;
    if (current == null) return broadcast;

    late StreamController<TorrentEntity> seed;
    seed = StreamController<TorrentEntity>(onListen: () {
      seed.add(current);
      broadcast.listen(seed.add, onError: seed.addError, onDone: seed.close);
    });
    return seed.stream;
  }

  @override
  Future<List<TorrentFileEntity>> getFiles(String torrentId) async {
    final cached = _torrents[torrentId]?.files;
    if (cached != null && cached.isNotEmpty) return cached;

    final raw =
        await _channel.invokeMethod<String>('getFiles', {'id': torrentId});
    if (raw == null) return const [];

    final files = (json.decode(raw) as List<dynamic>).map((e) {
      final m = e as Map<String, dynamic>;
      return TorrentFileEntity(
        id: m['id'] as String,
        name: m['name'] as String,
        path: m['path'] as String,
        size: (m['size'] as num).toInt(),
        downloadedSize: (m['downloadedSize'] as num).toInt(),
        contiguousDownloadedSize:
            (m['contiguousDownloadedSize'] as num?)?.toInt() ?? 0,
        bufferedSize: (m['bufferedSize'] as num?)?.toInt() ?? 0,
        progress: (m['progress'] as num).toDouble(),
        priority: _parsePriority(m['priority'] as String?),
      );
    }).toList();

    _updateLocal(torrentId, (t) => t.copyWith(files: files));
    return files;
  }

  @override
  Future<void> selectFileForStreaming(String torrentId, String fileId) async {
    final streamUrl = await _channel.invokeMethod<String>(
      'selectFile',
      {'id': torrentId, 'fileId': fileId},
    );

    final torrent = _torrents[torrentId];
    if (torrent == null) return;

    TorrentFileEntity? selected;
    final updatedFiles = torrent.files.map((file) {
      final isSelected = file.id == fileId;
      if (isSelected) selected = file;
      return file.copyWith(
        priority: isSelected ? FilePriority.high : FilePriority.normal,
      );
    }).toList();

    _updateLocal(
      torrentId,
      (t) => t.copyWith(
        files: updatedFiles,
        streamUrl: streamUrl ??
            (selected != null ? _toPlayablePath(selected!.path) : null),
      ),
    );
  }

  @override
  Stream<List<TorrentEntity>> get allTorrentsStream => _allCtrl.stream;

  @override
  List<TorrentEntity> get currentTorrents => _torrents.values.toList();

  @override
  void dispose() {
    _sub.cancel();
    for (final c in _statusCtrls.values) {
      c.close();
    }
    _allCtrl.close();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _updateLocal(String id, TorrentEntity Function(TorrentEntity) fn) {
    final t = _torrents[id];
    if (t == null) return;
    final updated = fn(t);
    _torrents[id] = updated;
    _statusCtrls[id]?.add(updated);
    _allCtrl.add(currentTorrents);
  }

  void _scheduleFilesLoad(String id) {
    if (_loadingFiles.contains(id)) return;
    _loadingFiles.add(id);

    Future<void>(() async {
      try {
        await getFiles(id);
      } catch (_) {
        // Ignore transient metadata timing issues; later native updates retry.
      } finally {
        _loadingFiles.remove(id);
      }
    });
  }

  String _nameFromMagnet(String magnet) {
    final m = RegExp(r'[&?]dn=([^&]+)').firstMatch(magnet);
    if (m != null) {
      return Uri.decodeComponent(m.group(1)!.replaceAll('+', ' '));
    }
    return 'Torrent ${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  List<TorrentFileEntity>? _parseFiles(dynamic rawFiles) {
    final list = rawFiles as List<dynamic>?;
    if (list == null) return null;

    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return TorrentFileEntity(
        id: m['id'] as String,
        name: m['name'] as String,
        path: m['path'] as String,
        size: (m['size'] as num).toInt(),
        downloadedSize: (m['downloadedSize'] as num?)?.toInt() ?? 0,
        contiguousDownloadedSize:
            (m['contiguousDownloadedSize'] as num?)?.toInt() ?? 0,
        bufferedSize: (m['bufferedSize'] as num?)?.toInt() ?? 0,
        progress: (m['progress'] as num?)?.toDouble() ?? 0,
        priority: _parsePriority(m['priority'] as String?),
      );
    }).toList();
  }

  FilePriority _parsePriority(String? priority) => switch (priority) {
        'skip' => FilePriority.skip,
        'high' => FilePriority.high,
        _ => FilePriority.normal,
      };

  String _toPlayablePath(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.scheme.isNotEmpty) return path;
    if (path.startsWith('/')) {
      return Uri(scheme: 'file', path: path).toString();
    }
    return path;
  }
}
