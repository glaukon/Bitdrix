import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/torrent_entity.dart';
import '../../domain/entities/torrent_file_entity.dart';
import 'base_torrent_service.dart';

/// Android engine backed by libtorrent4j through platform channels.
///
/// The native engine persists torrents and keeps downloading in a foreground
/// service, so on start-up it pushes back every restored torrent; unknown ids
/// arriving from native are therefore added to the local store.
class NativeTorrentService extends BaseTorrentService {
  static const _channel = MethodChannel('com.bitdrix.bitdrix/torrent');
  static const _events = EventChannel('com.bitdrix.bitdrix/torrent_updates');
  static const _uuid = Uuid();

  late final StreamSubscription<dynamic> _sub;
  bool _askedNotifications = false;

  NativeTorrentService() {
    _sub = _events.receiveBroadcastStream().listen(
          _onNativeUpdate,
          onError: (Object e) => debugPrint('Torrent events error: $e'),
        );
  }

  // ── Native events ─────────────────────────────────────────────────────────

  void _onNativeUpdate(dynamic raw) {
    try {
      final map = json.decode(raw as String) as Map<String, dynamic>;
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) return;

      final status = _parseStatus(map['status'] as String?);
      if (status == TorrentStatus.error && !map.containsKey('progress')) {
        update(
          id,
          (t) => t.copyWith(
            status: TorrentStatus.error,
            errorMessage: map['errorMessage'] as String?,
            downloadSpeed: 0,
            uploadSpeed: 0,
          ),
        );
        return;
      }

      final current = torrents[id] ?? _restored(id, map);
      final rawName = map['name'] as String?;
      final total = (map['totalSize'] as num?)?.toInt() ?? 0;
      final files = _parseFiles(map['files']);

      put(current.copyWith(
        name: (rawName != null && rawName.isNotEmpty) ? rawName : null,
        infoHash: map['infoHash'] as String?,
        progress: (map['progress'] as num?)?.toDouble(),
        downloadSpeed: (map['downloadSpeed'] as num?)?.toDouble() ?? 0,
        uploadSpeed: (map['uploadSpeed'] as num?)?.toDouble() ?? 0,
        peers: (map['peers'] as num?)?.toInt() ?? 0,
        seeds: (map['seeds'] as num?)?.toInt() ?? 0,
        downloadedSize: (map['downloadedSize'] as num?)?.toInt(),
        uploadedSize: (map['uploadedSize'] as num?)?.toInt(),
        totalSize: total > 0 ? total : null,
        status: status,
        files: files != null && files.isNotEmpty ? files : null,
        clearError: status != TorrentStatus.error,
      ));
    } catch (e, st) {
      debugPrint('NativeTorrentService update error: $e\n$st');
    }
  }

  /// Builds the entity for a torrent restored by the native engine.
  TorrentEntity _restored(String id, Map<String, dynamic> map) {
    final addedAtMs = (map['addedAt'] as num?)?.toInt() ?? 0;
    return placeholder(
      id: id,
      name: map['name'] as String? ?? 'Torrent',
      magnetLink: map['magnet'] as String?,
    ).copyWith(
      addedAt: addedAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(addedAtMs)
          : DateTime.now(),
    );
  }

  TorrentStatus _parseStatus(String? s) => switch (s) {
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
    final initial = placeholder(
      id: id,
      name: TorrentServiceUtils.nameFromMagnet(magnetLink),
      magnetLink: magnetLink,
      infoHash: TorrentServiceUtils.infoHashFromMagnet(magnetLink),
    );
    put(initial);
    unawaited(_askForNotifications());
    await _channel.invokeMethod<void>('addMagnet', {'magnet': magnetLink, 'id': id});
    return initial;
  }

  @override
  Future<TorrentEntity> addTorrentFile(String filePath) async {
    final id = _uuid.v4();
    final initial = placeholder(
      id: id,
      name: TorrentServiceUtils.nameFromTorrentPath(filePath),
      filePath: filePath,
    );
    put(initial);
    unawaited(_askForNotifications());
    await _channel.invokeMethod<void>('addTorrentFile', {'filePath': filePath, 'id': id});
    return initial;
  }

  @override
  Future<void> pause(String torrentId) async {
    await _channel.invokeMethod<void>('pause', {'id': torrentId});
    update(
      torrentId,
      (t) => t.copyWith(status: TorrentStatus.paused, downloadSpeed: 0, uploadSpeed: 0),
    );
  }

  @override
  Future<void> resume(String torrentId) async {
    await _channel.invokeMethod<void>('resume', {'id': torrentId});
    update(
      torrentId,
      (t) => t.copyWith(status: TorrentStatus.downloading, clearError: true),
    );
  }

  @override
  Future<void> remove(String torrentId, {bool deleteFiles = false}) async {
    await _channel.invokeMethod<void>(
      'remove',
      {'id': torrentId, 'deleteFiles': deleteFiles},
    );
    drop(torrentId);
  }

  @override
  Future<List<TorrentFileEntity>> getFiles(String torrentId) async {
    final cached = torrents[torrentId]?.files;
    if (cached != null && cached.isNotEmpty) return cached;
    final raw = await _channel.invokeMethod<String>('getFiles', {'id': torrentId});
    final files = _parseFiles(raw == null ? null : json.decode(raw)) ?? const [];
    if (files.isNotEmpty) update(torrentId, (t) => t.copyWith(files: files));
    return files;
  }

  @override
  Future<void> selectFileForStreaming(String torrentId, String fileId) async {
    final streamUrl = await _channel.invokeMethod<String>(
      'selectFile',
      {'id': torrentId, 'fileId': fileId},
    );
    if (streamUrl == null) {
      throw StateError('Todavía no hay información del torrent.');
    }
    update(
      torrentId,
      (t) => t.copyWith(
        streamUrl: streamUrl,
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
    _sub.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _askForNotifications() async {
    // Android 13+ hides the download notification unless this is granted.
    if (_askedNotifications) return;
    _askedNotifications = true;
    try {
      await Permission.notification.request();
    } catch (_) {}
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
        priority: switch (m['priority'] as String?) {
          'skip' => FilePriority.skip,
          'high' => FilePriority.high,
          _ => FilePriority.normal,
        },
      );
    }).toList();
  }
}
