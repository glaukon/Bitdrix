import '../repositories/torrent_repository.dart';

/// Pauses an active torrent download.
class PauseTorrentUseCase {
  const PauseTorrentUseCase(this._repository);

  final TorrentRepository _repository;

  /// Executes the use case for the torrent identified by [id].
  Future<void> call(String id) {
    if (id.trim().isEmpty) throw ArgumentError('Torrent id must not be empty.');
    return _repository.pause(id);
  }
}
