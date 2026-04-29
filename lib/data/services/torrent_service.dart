import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../domain/entities/torrent_entity.dart';
import '../../domain/entities/torrent_file_entity.dart';

// ── Interface ──────────────────────────────────────────────────────────────────

/// Contract for torrent engine operations.
///
/// Phase 4 will replace [MockTorrentService] with a real libtorrent/DHT
/// implementation. All callers depend only on this interface.
abstract class ITorrentService {
  /// Adds a torrent via its magnet link and starts downloading.
  Future<TorrentEntity> addMagnet(String magnetLink);

  /// Adds a torrent from a local .torrent file and starts downloading.
  Future<TorrentEntity> addTorrentFile(String filePath);

  /// Pauses an active download.
  Future<void> pause(String torrentId);

  /// Resumes a paused or errored download.
  Future<void> resume(String torrentId);

  /// Removes a torrent, optionally deleting downloaded files.
  Future<void> remove(String torrentId, {bool deleteFiles = false});

  /// Returns a stream that emits the latest snapshot of [torrentId].
  Stream<TorrentEntity> getStatus(String torrentId);

  /// Returns a snapshot list of files for [torrentId].
  Future<List<TorrentFileEntity>> getFiles(String torrentId);

  /// Prioritises a specific file for playback/streaming within a torrent.
  Future<void> selectFileForStreaming(String torrentId, String fileId);

  /// Returns a stream that emits the full torrent list whenever it changes.
  Stream<List<TorrentEntity>> get allTorrentsStream;

  /// Returns the current in-memory list of torrents (synchronous snapshot).
  List<TorrentEntity> get currentTorrents;

  /// Disposes internal resources.
  void dispose();
}

// ── Mock implementation ────────────────────────────────────────────────────────

/// Simulates a torrent engine without any real network activity.
///
/// Each torrent starts in [TorrentStatus.queued], transitions to
/// [TorrentStatus.downloading] after a short delay, and progresses toward
/// [TorrentStatus.completed] with realistic-looking speed fluctuations.
class MockTorrentService implements ITorrentService {
  MockTorrentService() {
    _startGlobalTick();
  }

  static const _uuid = Uuid();
  final _random = Random();

  /// In-memory store of all torrents.
  final Map<String, TorrentEntity> _torrents = {};

  /// Per-torrent stream controllers for [getStatus].
  final Map<String, StreamController<TorrentEntity>> _statusControllers = {};

  /// Broadcast controller for [allTorrentsStream].
  final _allController =
      StreamController<List<TorrentEntity>>.broadcast();

  Timer? _globalTimer;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  void _startGlobalTick() {
    _globalTimer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (_) => _tick(),
    );
  }

  void _tick() {
    var anyChanged = false;

    for (final entry in _torrents.entries.toList()) {
      final torrent = entry.value;
      if (torrent.status != TorrentStatus.downloading) continue;

      // Simulate fluctuating speed: 200 KB/s – 4 MB/s down, 50 KB/s – 800 KB/s up.
      final dl = _randomSpeed(200 * 1024, 4 * 1024 * 1024);
      final ul = _randomSpeed(50 * 1024, 800 * 1024);

      final newDownloaded =
          min(torrent.downloadedSize + dl.toInt(), torrent.totalSize);
      final newUploaded = torrent.uploadedSize + ul.toInt();
      final newProgress = newDownloaded / torrent.totalSize;

      final newStatus = newDownloaded >= torrent.totalSize
          ? TorrentStatus.completed
          : TorrentStatus.downloading;

      // Update files proportionally.
      final updatedFiles = _updateFiles(torrent.files, newProgress);

      final updated = torrent.copyWith(
        downloadedSize: newDownloaded,
        uploadedSize: newUploaded,
        downloadSpeed: newStatus == TorrentStatus.completed ? 0.0 : dl,
        uploadSpeed: ul,
        progress: newStatus == TorrentStatus.completed ? 1.0 : newProgress,
        status: newStatus,
        files: updatedFiles,
        peers: _random.nextInt(50) + 5,
        seeds: _random.nextInt(200) + 10,
      );

      _torrents[entry.key] = updated;
      _statusControllers[entry.key]?.add(updated);
      anyChanged = true;
    }

    if (anyChanged) {
      _allController.add(currentTorrents);
    }
  }

  double _randomSpeed(int minBytes, int maxBytes) {
    return minBytes + _random.nextDouble() * (maxBytes - minBytes);
  }

  List<TorrentFileEntity> _updateFiles(
    List<TorrentFileEntity> files,
    double overallProgress,
  ) {
    return files.map((f) {
      // Each file progresses slightly differently from the overall torrent.
      final fileProgress = (overallProgress +
              (_random.nextDouble() - 0.5) * 0.1)
          .clamp(0.0, 1.0);
      final downloaded = (f.size * fileProgress).round();
      return f.copyWith(
        downloadedSize: downloaded,
        progress: fileProgress,
      );
    }).toList();
  }

  // ── ITorrentService ──────────────────────────────────────────────────────────

  @override
  Future<TorrentEntity> addMagnet(String magnetLink) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final torrent = _buildMockTorrent(
      magnetLink: magnetLink,
      name: _extractNameFromMagnet(magnetLink),
    );
    _register(torrent);
    _scheduleStart(torrent.id);
    return torrent;
  }

  @override
  Future<TorrentEntity> addTorrentFile(String filePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final fileName = filePath.split('/').last.split('\\').last;
    final name = fileName.endsWith('.torrent')
        ? fileName.substring(0, fileName.length - 8)
        : fileName;
    final torrent = _buildMockTorrent(filePath: filePath, name: name);
    _register(torrent);
    _scheduleStart(torrent.id);
    return torrent;
  }

  @override
  Future<void> pause(String torrentId) async {
    final t = _torrents[torrentId];
    if (t == null) return;
    if (t.status != TorrentStatus.downloading) return;

    final updated = t.copyWith(
      status: TorrentStatus.paused,
      downloadSpeed: 0.0,
      uploadSpeed: 0.0,
    );
    _torrents[torrentId] = updated;
    _statusControllers[torrentId]?.add(updated);
    _allController.add(currentTorrents);
  }

  @override
  Future<void> resume(String torrentId) async {
    final t = _torrents[torrentId];
    if (t == null) return;
    if (!t.canResume) return;

    final updated = t.copyWith(status: TorrentStatus.downloading);
    _torrents[torrentId] = updated;
    _statusControllers[torrentId]?.add(updated);
    _allController.add(currentTorrents);
  }

  @override
  Future<void> remove(String torrentId, {bool deleteFiles = false}) async {
    _torrents.remove(torrentId);
    final ctrl = _statusControllers.remove(torrentId);
    ctrl?.close();
    _allController.add(currentTorrents);
  }

  @override
  Stream<TorrentEntity> getStatus(String torrentId) {
    // Ensure a broadcast controller exists for this torrent.
    _statusControllers.putIfAbsent(
      torrentId,
      () => StreamController<TorrentEntity>.broadcast(),
    );

    final current = _torrents[torrentId];
    final broadcastStream = _statusControllers[torrentId]!.stream;

    if (current == null) return broadcastStream;

    // Emit the current snapshot immediately, then forward all subsequent
    // updates from the broadcast controller.
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
  Future<List<TorrentFileEntity>> getFiles(String torrentId) async {
    return _torrents[torrentId]?.files ?? [];
  }

  @override
  Future<void> selectFileForStreaming(String torrentId, String fileId) async {
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

    final updated = torrent.copyWith(
      files: updatedFiles,
      streamUrl: selected?.path,
    );
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
    _globalTimer?.cancel();
    for (final ctrl in _statusControllers.values) {
      ctrl.close();
    }
    _allController.close();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _register(TorrentEntity torrent) {
    _torrents[torrent.id] = torrent;
    _statusControllers[torrent.id] =
        StreamController<TorrentEntity>.broadcast();
    _allController.add(currentTorrents);
  }

  /// Transitions a torrent from [TorrentStatus.queued] to
  /// [TorrentStatus.downloading] after a short simulated metadata-fetch delay.
  void _scheduleStart(String torrentId) {
    Future<void>.delayed(
      Duration(milliseconds: 500 + _random.nextInt(1500)),
      () {
        final t = _torrents[torrentId];
        if (t == null || t.status != TorrentStatus.queued) return;
        final updated = t.copyWith(status: TorrentStatus.downloading);
        _torrents[torrentId] = updated;
        _statusControllers[torrentId]?.add(updated);
        _allController.add(currentTorrents);
      },
    );
  }

  TorrentEntity _buildMockTorrent({
    String? magnetLink,
    String? filePath,
    required String name,
  }) {
    final id = _uuid.v4();
    final totalSize = _randomTotalSize();
    final files = _generateMockFiles(name, totalSize);

    return TorrentEntity(
      id: id,
      name: name.isNotEmpty ? name : 'Unknown Torrent',
      magnetLink: magnetLink,
      filePath: filePath,
      totalSize: totalSize,
      downloadedSize: 0,
      uploadedSize: 0,
      downloadSpeed: 0,
      uploadSpeed: 0,
      progress: 0,
      status: TorrentStatus.queued,
      files: files,
      addedAt: DateTime.now(),
      peers: 0,
      seeds: _random.nextInt(500) + 20,
    );
  }

  int _randomTotalSize() {
    // Sizes between 200 MB and 15 GB.
    final sizeMb = 200 + _random.nextInt(15000 - 200);
    return sizeMb * 1024 * 1024;
  }

  List<TorrentFileEntity> _generateMockFiles(String torrentName, int totalSize) {
    final fileCount = 1 + _random.nextInt(5);
    final files = <TorrentFileEntity>[];
    var remaining = totalSize;

    for (var i = 0; i < fileCount; i++) {
      final isLast = i == fileCount - 1;
      final fileSize = isLast
          ? remaining
          : (remaining * (0.1 + _random.nextDouble() * 0.5)).round();
      remaining -= fileSize;

      final ext = _randomVideoExt();
      final fileName = fileCount == 1
          ? '$torrentName.$ext'
          : '$torrentName.part${i + 1}.$ext';

      files.add(TorrentFileEntity(
        id: const Uuid().v4(),
        name: fileName,
        path: '$torrentName/$fileName',
        size: fileSize,
        downloadedSize: 0,
        progress: 0,
        priority: FilePriority.normal,
      ));
    }

    return files;
  }

  String _randomVideoExt() {
    const exts = ['mp4', 'mkv', 'avi', 'mp4', 'mkv'];
    return exts[_random.nextInt(exts.length)];
  }

  String _extractNameFromMagnet(String magnet) {
    final dnMatch = RegExp(r'[&?]dn=([^&]+)').firstMatch(magnet);
    if (dnMatch != null) {
      return Uri.decodeComponent(dnMatch.group(1)!.replaceAll('+', ' '));
    }
    return 'Magnet Torrent ${DateTime.now().millisecondsSinceEpoch % 10000}';
  }
}
