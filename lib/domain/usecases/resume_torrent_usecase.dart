import '../repositories/torrent_repository.dart';

/// Resumes a paused or errored torrent.
class ResumeTorrentUseCase {
  const ResumeTorrentUseCase(this._repository);

  final TorrentRepository _repository;

  /// Executes the use case for the torrent identified by [id].
  Future<void> call(String id) {
    if (id.trim().isEmpty) throw ArgumentError('Torrent id must not be empty.');
    return _repository.resume(id);
  }
}
