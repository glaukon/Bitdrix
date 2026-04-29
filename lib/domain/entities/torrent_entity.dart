import 'torrent_file_entity.dart';

/// Lifecycle state of a torrent.
enum TorrentStatus {
  /// Waiting to start downloading.
  queued,

  /// Actively downloading data.
  downloading,

  /// Download has been manually paused.
  paused,

  /// All data has been downloaded successfully.
  completed,

  /// An error occurred and the download cannot continue.
  error,
}

/// Core domain entity representing a torrent.
class TorrentEntity {
  const TorrentEntity({
    required this.id,
    required this.name,
    this.magnetLink,
    this.filePath,
    required this.totalSize,
    required this.downloadedSize,
    required this.uploadedSize,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.progress,
    required this.status,
    required this.files,
    required this.addedAt,
    required this.peers,
    required this.seeds,
    this.errorMessage,
    this.streamUrl,
  });

  /// Unique identifier (UUID).
  final String id;

  /// Human-readable torrent name.
  final String name;

  /// Magnet link used to add this torrent, if applicable.
  final String? magnetLink;

  /// Path to the .torrent file on disk, if applicable.
  final String? filePath;

  /// Total size of all files in this torrent (bytes).
  final int totalSize;

  /// Number of bytes that have been downloaded so far.
  final int downloadedSize;

  /// Number of bytes that have been uploaded to peers.
  final int uploadedSize;

  /// Current download speed in bytes per second.
  final double downloadSpeed;

  /// Current upload speed in bytes per second.
  final double uploadSpeed;

  /// Overall download progress as a value between 0.0 and 1.0.
  final double progress;

  /// Current lifecycle status of the torrent.
  final TorrentStatus status;

  /// List of individual files contained in this torrent.
  final List<TorrentFileEntity> files;

  /// Date and time when this torrent was added.
  final DateTime addedAt;

  /// Number of peers currently connected.
  final int peers;

  /// Number of seeders available in the swarm.
  final int seeds;

  /// Error description when [status] is [TorrentStatus.error].
  final String? errorMessage;

  /// HTTP streaming URL provided by the torrent engine (e.g. WebTorrent server).
  final String? streamUrl;

  // ── Derived helpers ────────────────────────────────────────────────────────

  /// Remaining bytes to download.
  int get remainingBytes => totalSize - downloadedSize;

  /// Whether the torrent is actively transferring data.
  bool get isActive => status == TorrentStatus.downloading;

  /// Whether the torrent has finished downloading.
  bool get isCompleted => status == TorrentStatus.completed;

  /// Whether the torrent can be resumed (was paused or errored).
  bool get canResume =>
      status == TorrentStatus.paused || status == TorrentStatus.error;

  /// Ratio of uploaded to downloaded bytes.
  double get ratio {
    if (downloadedSize == 0) return 0.0;
    return uploadedSize / downloadedSize;
  }

  TorrentEntity copyWith({
    String? id,
    String? name,
    String? magnetLink,
    String? filePath,
    int? totalSize,
    int? downloadedSize,
    int? uploadedSize,
    double? downloadSpeed,
    double? uploadSpeed,
    double? progress,
    TorrentStatus? status,
    List<TorrentFileEntity>? files,
    DateTime? addedAt,
    int? peers,
    int? seeds,
    String? errorMessage,
    String? streamUrl,
  }) {
    return TorrentEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      magnetLink: magnetLink ?? this.magnetLink,
      filePath: filePath ?? this.filePath,
      totalSize: totalSize ?? this.totalSize,
      downloadedSize: downloadedSize ?? this.downloadedSize,
      uploadedSize: uploadedSize ?? this.uploadedSize,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      files: files ?? this.files,
      addedAt: addedAt ?? this.addedAt,
      peers: peers ?? this.peers,
      seeds: seeds ?? this.seeds,
      errorMessage: errorMessage ?? this.errorMessage,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TorrentEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          status == other.status &&
          progress == other.progress &&
          downloadSpeed == other.downloadSpeed &&
          uploadSpeed == other.uploadSpeed &&
          downloadedSize == other.downloadedSize &&
          uploadedSize == other.uploadedSize &&
          totalSize == other.totalSize &&
          peers == other.peers &&
          seeds == other.seeds &&
          errorMessage == other.errorMessage &&
          streamUrl == other.streamUrl;

  @override
  int get hashCode => Object.hash(id, status, progress);

  @override
  String toString() =>
      'TorrentEntity(id: $id, name: $name, status: $status, '
      'progress: ${(progress * 100).toStringAsFixed(1)}%)';
}
