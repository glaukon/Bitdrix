/// Priority level for an individual file within a torrent.
enum FilePriority {
  /// File will not be downloaded.
  skip,

  /// Normal download priority.
  normal,

  /// Download this file before others.
  high,
}

/// Represents a single file contained within a torrent.
class TorrentFileEntity {
  const TorrentFileEntity({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.downloadedSize,
    this.contiguousDownloadedSize = 0,
    this.bufferedSize = 0,
    required this.progress,
    required this.priority,
  });

  /// Unique identifier for this file entry.
  final String id;

  /// Display name of the file (filename only, not full path).
  final String name;

  /// Relative path within the torrent's directory structure.
  final String path;

  /// Total size of this file in bytes.
  final int size;

  /// Number of bytes already downloaded for this file.
  final int downloadedSize;

  /// Number of verified contiguous bytes from the beginning of the file.
  final int contiguousDownloadedSize;

  /// Number of contiguous or actively downloading bytes from the beginning.
  final int bufferedSize;

  /// Download progress as a value between 0.0 and 1.0.
  final double progress;

  /// Download priority for this file.
  final FilePriority priority;

  /// Whether this file has been fully downloaded.
  bool get isCompleted => progress >= 1.0;

  /// Extension of the file (lowercase, without the leading dot).
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  TorrentFileEntity copyWith({
    String? id,
    String? name,
    String? path,
    int? size,
    int? downloadedSize,
    int? contiguousDownloadedSize,
    int? bufferedSize,
    double? progress,
    FilePriority? priority,
  }) {
    return TorrentFileEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      downloadedSize: downloadedSize ?? this.downloadedSize,
      contiguousDownloadedSize:
          contiguousDownloadedSize ?? this.contiguousDownloadedSize,
      bufferedSize: bufferedSize ?? this.bufferedSize,
      progress: progress ?? this.progress,
      priority: priority ?? this.priority,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TorrentFileEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TorrentFileEntity(id: $id, name: $name, progress: ${(progress * 100).toStringAsFixed(1)}%)';
}
