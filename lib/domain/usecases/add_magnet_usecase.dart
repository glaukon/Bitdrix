import '../entities/torrent_entity.dart';
import '../repositories/torrent_repository.dart';

/// Validates and adds a torrent via a magnet link.
class AddMagnetUseCase {
  const AddMagnetUseCase(this._repository);

  final TorrentRepository _repository;

  /// Executes the use case.
  ///
  /// Throws [ArgumentError] if [magnetLink] is empty or not a valid magnet URI.
  Future<TorrentEntity> call(String magnetLink) {
    final trimmed = magnetLink.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Magnet link must not be empty.');
    }
    if (!trimmed.startsWith('magnet:?')) {
      throw ArgumentError(
        'Invalid magnet link. Must start with "magnet:?".',
      );
    }
    return _repository.addMagnet(trimmed);
  }
}
