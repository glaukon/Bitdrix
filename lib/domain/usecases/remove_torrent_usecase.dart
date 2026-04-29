import '../repositories/torrent_repository.dart';

/// Removes a torrent from the download queue.
class RemoveTorrentUseCase {
  const RemoveTorrentUseCase(this._repository);

  final TorrentRepository _repository;

  /// Executes the use case.
  ///
  /// Set [deleteFiles] to `true` to also remove downloaded data from disk.
  Future<void> call(String id, {bool deleteFiles = false}) {
    if (id.trim().isEmpty) throw ArgumentError('Torrent id must not be empty.');
    return _repository.remove(id, deleteFiles: deleteFiles);
  }
}
