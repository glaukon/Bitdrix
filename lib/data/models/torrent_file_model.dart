import '../../domain/entities/torrent_file_entity.dart';

/// Data-layer model for [TorrentFileEntity] with JSON serialisation.
class TorrentFileModel extends TorrentFileEntity {
  const TorrentFileModel({
    required super.id,
    required super.name,
    required super.path,
    required super.size,
    required super.downloadedSize,
    super.contiguousDownloadedSize,
    super.bufferedSize,
    required super.progress,
    required super.priority,
  });

  /// Deserialises a [TorrentFileModel] from a JSON map.
  factory TorrentFileModel.fromJson(Map<String, dynamic> json) {
    return TorrentFileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      size: (json['size'] as num).toInt(),
      downloadedSize: (json['downloadedSize'] as num).toInt(),
      contiguousDownloadedSize:
          (json['contiguousDownloadedSize'] as num?)?.toInt() ?? 0,
      bufferedSize: (json['bufferedSize'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num).toDouble(),
      priority: FilePriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => FilePriority.normal,
      ),
    );
  }

  /// Serialises this model to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'size': size,
      'downloadedSize': downloadedSize,
      'contiguousDownloadedSize': contiguousDownloadedSize,
      'bufferedSize': bufferedSize,
      'progress': progress,
      'priority': priority.name,
    };
  }

  /// Creates a [TorrentFileModel] from a domain entity.
  factory TorrentFileModel.fromEntity(TorrentFileEntity entity) {
    return TorrentFileModel(
      id: entity.id,
      name: entity.name,
      path: entity.path,
      size: entity.size,
      downloadedSize: entity.downloadedSize,
      contiguousDownloadedSize: entity.contiguousDownloadedSize,
      bufferedSize: entity.bufferedSize,
      progress: entity.progress,
      priority: entity.priority,
    );
  }

  @override
  TorrentFileModel copyWith({
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
    return TorrentFileModel(
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
}
