import '../entities/torrent_entity.dart';
import '../repositories/torrent_repository.dart';

/// Validates and adds a torrent from a local .torrent file.
class AddTorrentFileUseCase {
  const AddTorrentFileUseCase(this._repository);

  final TorrentRepository _repository;

  /// Executes the use case.
  ///
  /// Throws [ArgumentError] if [filePath] is empty or does not end in .torrent.
  Future<TorrentEntity> call(String filePath) {
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('File path must not be empty.');
    }
    if (!trimmed.toLowerCase().endsWith('.torrent')) {
      throw ArgumentError('File must have a .torrent extension.');
    }
    return _repository.addTorrentFile(trimmed);
  }
}
