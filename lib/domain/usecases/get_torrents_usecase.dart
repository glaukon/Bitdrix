import '../entities/torrent_entity.dart';
import '../repositories/torrent_repository.dart';

/// Provides access to the live torrent list and individual torrent streams.
class GetTorrentsUseCase {
  const GetTorrentsUseCase(this._repository);

  final TorrentRepository _repository;

  /// Returns a stream that emits the full torrent list on every change.
  Stream<List<TorrentEntity>> watchAll() => _repository.watchAllTorrents();

  /// Returns a stream of live updates for the torrent identified by [id].
  Stream<TorrentEntity> watchOne(String id) => _repository.watchTorrent(id);

  /// Returns the current torrent list synchronously.
  List<TorrentEntity> getAll() => _repository.getAllTorrents();
}
