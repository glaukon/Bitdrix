import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/torrent_entity.dart';
import '../../domain/entities/torrent_file_entity.dart';
import 'base_torrent_service.dart';

/// Desktop (Windows) engine: drives a bundled `rqbit` server over its local
/// HTTP API. rqbit persists the session itself and serves files with Range
/// support while they download, prioritising the pieces being streamed.
///
/// Torrent ids are the info hashes, so they are stable across restarts.
class RqbitTorrentService extends BaseTorrentService {
  RqbitTorrentService() {
    _ready = _start();
  }

  static const _port = 39303;
  static const _base = 'http://127.0.0.1:$_port';
  static const _addedAtKey = 'rqbit_added_at';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _base,
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 30),
  ));

  late final Future<void> _ready;
  Process? _process;
  Timer? _poll;
  bool _polling = false;
  SharedPreferences? _prefs;
  final Set<String> _filesLoaded = {};
  final Set<String> _pendingAdds = {};

  // ── Server lifecycle ──────────────────────────────────────────────────────

  Future<void> _start() async {
    _prefs = await SharedPreferences.getInstance();
    if (!await _isServerUp()) {
      final exe = _rqbitExecutable();
      if (exe == null) {
        debugPrint('rqbit.exe not found next to the app executable');
        return;
      }
      final support = await getApplicationSupportDirectory();
      final downloads = await _downloadDir();
      final persistence = Directory('${support.path}${Platform.pathSeparator}rqbit')
        ..createSync(recursive: true);
      _process = await Process.start(
        exe,
        [
          '--http-api-listen-addr',
          '127.0.0.1:$_port',
          'server',
          'start',
          '--persistence-location',
          persistence.path,
          downloads.path,
        ],
        mode: ProcessStartMode.normal,
      );
      _process!.stdout.drain<void>();
      _process!.stderr.transform(utf8.decoder).listen((l) => debugPrint('[rqbit] $l'));
      for (var i = 0; i < 50 && !await _isServerUp(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    await _refresh();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  Future<bool> _isServerUp() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/');
      return r.data?['server'] == 'rqbit';
    } catch (_) {
      return false;
    }
  }

  String? _rqbitExecutable() {
    final dir = File(Platform.resolvedExecutable).parent.path;
    final exe = File('$dir${Platform.pathSeparator}rqbit.exe');
    return exe.existsSync() ? exe.path : null;
  }

  Future<Directory> _downloadDir() async {
    final base = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    return Directory('${base.path}${Platform.pathSeparator}Bitdrix')
      ..createSync(recursive: true);
  }

  // ── Polling ───────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    if (_polling) return;
    _polling = true;
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/torrents',
        queryParameters: {'with_stats': 'true'},
      );
      final list = (r.data?['torrents'] as List<dynamic>? ?? const []);
      final seen = <String>{};
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        final hash = (m['info_hash'] as String?)?.toLowerCase();
        if (hash == null) continue;
        seen.add(hash);
        _apply(hash, m);
        if (!_filesLoaded.contains(hash)) unawaited(_loadFiles(hash));
      }
      // Torrents removed outside the app.
      for (final id in torrents.keys.toList()) {
        if (!seen.contains(id) && !_pendingAdds.contains(id)) {
          if (torrents[id]?.status != TorrentStatus.error) drop(id);
        }
      }
    } catch (_) {
      // Server not reachable this tick.
    } finally {
      _polling = false;
    }
  }

  void _apply(String hash, Map<String, dynamic> m) {
    final stats = m['stats'] as Map<String, dynamic>? ?? const {};
    final live = stats['live'] as Map<String, dynamic>?;
    final total = (stats['total_bytes'] as num?)?.toInt() ?? 0;
    final done = (stats['progress_bytes'] as num?)?.toInt() ?? 0;
    final finished = stats['finished'] == true;
    final state = stats['state'] as String?;
    final error = stats['error'] as String?;

    final status = switch (state) {
      'error' => TorrentStatus.error,
      'paused' => finished ? TorrentStatus.completed : TorrentStatus.paused,
      'initializing' => TorrentStatus.queued,
      _ => finished ? TorrentStatus.completed : TorrentStatus.downloading,
    };
    double mibToBytes(dynamic speed) =>
        (((speed as Map<String, dynamic>?)?['mbps'] as num?)?.toDouble() ?? 0) *
        1024 *
        1024;
    final peerStats = (live?['snapshot'] as Map<String, dynamic>?)?['peer_stats']
        as Map<String, dynamic>?;

    final current = torrents[hash] ??
        placeholder(id: hash, name: m['name'] as String? ?? hash, infoHash: hash)
            .copyWith(addedAt: _addedAt(hash));

    final fileProgress = (stats['file_progress'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList();
    final files = fileProgress == null
        ? current.files
        : [
            for (var i = 0; i < current.files.length; i++)
              _withProgress(current.files[i], i < fileProgress.length ? fileProgress[i] : 0),
          ];

    put(current.copyWith(
      name: m['name'] as String?,
      infoHash: hash,
      totalSize: total > 0 ? total : null,
      downloadedSize: done,
      uploadedSize: (stats['uploaded_bytes'] as num?)?.toInt(),
      progress: total > 0 ? done / total : 0,
      downloadSpeed: status == TorrentStatus.downloading ? mibToBytes(live?['download_speed']) : 0,
      uploadSpeed: mibToBytes(live?['upload_speed']),
      peers: (peerStats?['live'] as num?)?.toInt() ?? 0,
      seeds: (peerStats?['seen'] as num?)?.toInt() ?? 0,
      status: status,
      files: files,
      errorMessage: error,
      clearError: error == null,
    ));
  }

  TorrentFileEntity _withProgress(TorrentFileEntity f, int bytes) => f.copyWith(
        downloadedSize: bytes,
        contiguousDownloadedSize: bytes,
        bufferedSize: bytes,
        progress: f.size > 0 ? (bytes / f.size).clamp(0.0, 1.0) : 0,
      );

  Future<void> _loadFiles(String hash) async {
    _filesLoaded.add(hash);
    try {
      final r = await _dio.get<Map<String, dynamic>>('/torrents/$hash');
      final d = r.data ?? const {};
      final output = d['output_folder'] as String? ?? '';
      final rawFiles = d['files'] as List<dynamic>? ?? const [];
      if (rawFiles.isEmpty) {
        _filesLoaded.remove(hash);
        return;
      }
      final files = <TorrentFileEntity>[];
      for (var i = 0; i < rawFiles.length; i++) {
        final f = rawFiles[i] as Map<String, dynamic>;
        final components = (f['components'] as List<dynamic>? ?? const []).cast<String>();
        final name = f['name'] as String? ?? (components.isNotEmpty ? components.last : 'file $i');
        final path = [output, ...components].join(Platform.pathSeparator);
        files.add(TorrentFileEntity(
          id: '$hash-$i',
          name: components.isNotEmpty ? components.last : name,
          path: path,
          size: (f['length'] as num?)?.toInt() ?? 0,
          downloadedSize: 0,
          progress: 0,
          priority: f['included'] == false ? FilePriority.skip : FilePriority.normal,
        ));
      }
      update(hash, (t) => t.copyWith(files: files));
    } catch (_) {
      _filesLoaded.remove(hash);
    }
  }

  // ── ITorrentService ───────────────────────────────────────────────────────

  @override
  Future<TorrentEntity> addMagnet(String magnetLink) => _add(
        body: magnetLink,
        name: TorrentServiceUtils.nameFromMagnet(magnetLink),
        knownHash: TorrentServiceUtils.infoHashFromMagnet(magnetLink),
        magnetLink: magnetLink,
      );

  @override
  Future<TorrentEntity> addTorrentFile(String filePath) async => _add(
        body: await File(filePath).readAsBytes(),
        name: TorrentServiceUtils.nameFromTorrentPath(filePath),
        filePath: filePath,
      );

  Future<TorrentEntity> _add({
    required Object body,
    required String name,
    String? knownHash,
    String? magnetLink,
    String? filePath,
  }) async {
    await _ready;
    // Show the torrent immediately while rqbit resolves the metadata.
    final tempId = knownHash ?? 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final initial = placeholder(
      id: tempId,
      name: name,
      magnetLink: magnetLink,
      filePath: filePath,
      infoHash: knownHash,
    );
    _pendingAdds.add(tempId);
    put(initial);

    unawaited(() async {
      try {
        final r = await _dio.post<Map<String, dynamic>>(
          '/torrents',
          data: body is List<int> ? Stream.fromIterable([body]) : body,
          queryParameters: {'overwrite': 'true'},
          options: Options(
            receiveTimeout: const Duration(minutes: 5),
            contentType: 'application/octet-stream',
            headers: body is List<int> ? {Headers.contentLengthHeader: body.length} : null,
          ),
        );
        final details = r.data?['details'] as Map<String, dynamic>? ?? const {};
        final hash = (details['info_hash'] as String?)?.toLowerCase();
        if (hash != null) {
          await _rememberAddedAt(hash, initial.addedAt);
          if (hash != tempId) drop(tempId);
          await _refresh();
        }
      } catch (e) {
        update(
          tempId,
          (t) => t.copyWith(status: TorrentStatus.error, errorMessage: _describe(e)),
        );
      } finally {
        _pendingAdds.remove(tempId);
      }
    }());
    return initial;
  }

  @override
  Future<void> pause(String torrentId) async {
    await _dio.post<dynamic>('/torrents/$torrentId/pause');
    update(
      torrentId,
      (t) => t.copyWith(status: TorrentStatus.paused, downloadSpeed: 0, uploadSpeed: 0),
    );
  }

  @override
  Future<void> resume(String torrentId) async {
    await _dio.post<dynamic>('/torrents/$torrentId/start');
    update(
      torrentId,
      (t) => t.copyWith(status: TorrentStatus.downloading, clearError: true),
    );
  }

  @override
  Future<void> remove(String torrentId, {bool deleteFiles = false}) async {
    if (!torrentId.startsWith('pending-')) {
      try {
        await _dio.post<dynamic>(
            '/torrents/$torrentId/${deleteFiles ? 'delete' : 'forget'}');
      } on DioException catch (e) {
        // rqbit answers 500 when it cannot delete the files yet (torrent
        // still initialising, a file locked by Windows…) and 404 when the
        // torrent is already gone. Take it out of the session anyway so it
        // does not linger in the list.
        final status = e.response?.statusCode;
        if (status == 404) {
          // Already removed: nothing else to do.
        } else if (deleteFiles && status == 500) {
          try {
            await _dio.post<dynamic>('/torrents/$torrentId/forget');
          } on DioException catch (_) {}
        } else {
          rethrow;
        }
      }
    }
    drop(torrentId);
    _filesLoaded.remove(torrentId);
  }

  @override
  Future<List<TorrentFileEntity>> getFiles(String torrentId) async {
    if (torrents[torrentId]?.files.isEmpty ?? false) await _loadFiles(torrentId);
    return super.getFiles(torrentId);
  }

  @override
  Future<void> selectFileForStreaming(String torrentId, String fileId) async {
    final torrent = torrents[torrentId];
    if (torrent == null) return;
    final index = int.tryParse(fileId.split('-').last) ?? 0;
    final file = torrent.files.where((f) => f.id == fileId).firstOrNull;

    // Make sure the file is part of the download selection.
    if (file?.priority == FilePriority.skip) {
      final included = [
        for (var i = 0; i < torrent.files.length; i++)
          if (i == index || torrent.files[i].priority != FilePriority.skip) i,
      ];
      await _dio.post<dynamic>(
        '/torrents/$torrentId/update_only_files',
        data: {'only_files': included},
      );
    }
    if (torrent.status == TorrentStatus.paused) await resume(torrentId);

    final fileName = Uri.encodeComponent(file?.name ?? 'file');
    update(
      torrentId,
      (t) => t.copyWith(
        streamUrl: '$_base/torrents/$torrentId/stream/$index/$fileName',
        files: t.files
            .map((f) => f.copyWith(
                  priority: f.id == fileId ? FilePriority.high : f.priority,
                ))
            .toList(),
      ),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _process?.kill();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DateTime _addedAt(String hash) {
    final ms = _addedAtMap()[hash];
    return ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : DateTime.now();
  }

  Map<String, dynamic> _addedAtMap() {
    final raw = _prefs?.getString(_addedAtKey);
    if (raw == null) return {};
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _rememberAddedAt(String hash, DateTime at) async {
    final map = _addedAtMap()..[hash] = at.millisecondsSinceEpoch;
    await _prefs?.setString(_addedAtKey, json.encode(map));
  }

  String _describe(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['human_readable'] is String) return data['human_readable'] as String;
      if (data is String && data.isNotEmpty) return data;
      if (e.type == DioExceptionType.connectionError) {
        return 'El motor de torrents no está disponible.';
      }
      return e.message ?? 'Error de red';
    }
    return e.toString();
  }
}
