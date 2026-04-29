import '../entities/torrent_entity.dart';
import '../entities/torrent_file_entity.dart';

/// Domain-layer contract for all torrent data operations.
///
/// Concrete implementations live in the data layer and are injected via
/// dependency injection (Riverpod providers).
abstract class TorrentRepository {
  /// Adds a torrent from a magnet link.
  Future<TorrentEntity> addMagnet(String magnetLink);

  /// Adds a torrent from a local .torrent file path.
  Future<TorrentEntity> addTorrentFile(String filePath);

  /// Pauses the torrent with the given [id].
  Future<void> pause(String id);

  /// Resumes the paused/errored torrent with the given [id].
  Future<void> resume(String id);

  /// Removes the torrent with the given [id].
  ///
  /// Set [deleteFiles] to true to also remove downloaded data from disk.
  Future<void> remove(String id, {bool deleteFiles = false});

  /// Returns a stream of live status updates for a single torrent.
  Stream<TorrentEntity> watchTorrent(String id);

  /// Returns a stream of the complete torrent list.
  Stream<List<TorrentEntity>> watchAllTorrents();

  /// Returns the current in-memory list (synchronous).
  List<TorrentEntity> getAllTorrents();

  /// Returns the list of files for a given torrent [id].
  Future<List<TorrentFileEntity>> getFiles(String id);

  /// Prioritises a specific file so it can be played while downloading.
  Future<void> selectFileForStreaming(String torrentId, String fileId);
}
