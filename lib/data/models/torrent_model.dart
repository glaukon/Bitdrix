import '../../domain/entities/torrent_entity.dart';
import '../../domain/entities/torrent_file_entity.dart';
import 'torrent_file_model.dart';

/// Data-layer model for [TorrentEntity] with JSON serialisation.
class TorrentModel extends TorrentEntity {
  const TorrentModel({
    required super.id,
    required super.name,
    super.magnetLink,
    super.filePath,
    required super.totalSize,
    required super.downloadedSize,
    required super.uploadedSize,
    required super.downloadSpeed,
    required super.uploadSpeed,
    required super.progress,
    required super.status,
    required super.files,
    required super.addedAt,
    required super.peers,
    required super.seeds,
    super.errorMessage,
    super.streamUrl,
  });

  /// Deserialises a [TorrentModel] from a JSON map.
  factory TorrentModel.fromJson(Map<String, dynamic> json) {
    return TorrentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      magnetLink: json['magnetLink'] as String?,
      filePath: json['filePath'] as String?,
      totalSize: (json['totalSize'] as num).toInt(),
      downloadedSize: (json['downloadedSize'] as num).toInt(),
      uploadedSize: (json['uploadedSize'] as num).toInt(),
      downloadSpeed: (json['downloadSpeed'] as num).toDouble(),
      uploadSpeed: (json['uploadSpeed'] as num).toDouble(),
      progress: (json['progress'] as num).toDouble(),
      status: TorrentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TorrentStatus.queued,
      ),
      files: (json['files'] as List<dynamic>)
          .map((f) => TorrentFileModel.fromJson(f as Map<String, dynamic>))
          .toList(),
      addedAt: DateTime.parse(json['addedAt'] as String),
      peers: (json['peers'] as num).toInt(),
      seeds: (json['seeds'] as num).toInt(),
      errorMessage: json['errorMessage'] as String?,
      streamUrl: json['streamUrl'] as String?,
    );
  }

  /// Serialises this model to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'magnetLink': magnetLink,
      'filePath': filePath,
      'totalSize': totalSize,
      'downloadedSize': downloadedSize,
      'uploadedSize': uploadedSize,
      'downloadSpeed': downloadSpeed,
      'uploadSpeed': uploadSpeed,
      'progress': progress,
      'status': status.name,
      'files':
          files.map((f) => TorrentFileModel.fromEntity(f).toJson()).toList(),
      'addedAt': addedAt.toIso8601String(),
      'peers': peers,
      'seeds': seeds,
      'errorMessage': errorMessage,
      'streamUrl': streamUrl,
    };
  }

  /// Creates a [TorrentModel] from a domain entity.
  factory TorrentModel.fromEntity(TorrentEntity entity) {
    return TorrentModel(
      id: entity.id,
      name: entity.name,
      magnetLink: entity.magnetLink,
      filePath: entity.filePath,
      totalSize: entity.totalSize,
      downloadedSize: entity.downloadedSize,
      uploadedSize: entity.uploadedSize,
      downloadSpeed: entity.downloadSpeed,
      uploadSpeed: entity.uploadSpeed,
      progress: entity.progress,
      status: entity.status,
      files: entity.files,
      addedAt: entity.addedAt,
      peers: entity.peers,
      seeds: entity.seeds,
      errorMessage: entity.errorMessage,
      streamUrl: entity.streamUrl,
    );
  }

  @override
  TorrentModel copyWith({
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
    return TorrentModel(
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
}
