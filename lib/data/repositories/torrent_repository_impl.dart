import '../../domain/entities/torrent_entity.dart';
import '../../domain/entities/torrent_file_entity.dart';
import '../../domain/repositories/torrent_repository.dart';
import '../services/torrent_service.dart';

/// Concrete implementation of [TorrentRepository] that delegates to
/// [ITorrentService].
class TorrentRepositoryImpl implements TorrentRepository {
  const TorrentRepositoryImpl(this._service);

  final ITorrentService _service;

  @override
  Future<TorrentEntity> addMagnet(String magnetLink) =>
      _service.addMagnet(magnetLink);

  @override
  Future<TorrentEntity> addTorrentFile(String filePath) =>
      _service.addTorrentFile(filePath);

  @override
  Future<void> pause(String id) => _service.pause(id);

  @override
  Future<void> resume(String id) => _service.resume(id);

  @override
  Future<void> remove(String id, {bool deleteFiles = false}) =>
      _service.remove(id, deleteFiles: deleteFiles);

  @override
  Stream<TorrentEntity> watchTorrent(String id) => _service.getStatus(id);

  @override
  Stream<List<TorrentEntity>> watchAllTorrents() =>
      _service.allTorrentsStream;

  @override
  List<TorrentEntity> getAllTorrents() => _service.currentTorrents;

  @override
  Future<List<TorrentFileEntity>> getFiles(String id) =>
      _service.getFiles(id);

  @override
  Future<void> selectFileForStreaming(String torrentId, String fileId) =>
      _service.selectFileForStreaming(torrentId, fileId);
}
