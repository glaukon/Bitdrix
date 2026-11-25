import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import '../../data/repositories/torrent_repository_impl.dart';
import '../../data/services/native_torrent_service.dart';
import '../../data/services/rqbit_torrent_service.dart';
import '../../data/services/torrent_service.dart';
import '../../data/services/webtorrent_service.dart'
    if (dart.library.io) '../../data/services/webtorrent_service_stub.dart';
import '../../domain/entities/torrent_entity.dart';
import '../../domain/repositories/torrent_repository.dart';
import '../../domain/usecases/add_magnet_usecase.dart';
import '../../domain/usecases/add_torrent_file_usecase.dart';
import '../../domain/usecases/get_torrents_usecase.dart';
import '../../domain/usecases/pause_torrent_usecase.dart';
import '../../domain/usecases/remove_torrent_usecase.dart';
import '../../domain/usecases/resume_torrent_usecase.dart';

// ── Service / Repository ───────────────────────────────────────────────────────

/// Singleton torrent service:
/// - Web → WebTorrentService (WebTorrent via JS interop)
/// - Android → NativeTorrentService (libtorrent4j via platform channel)
/// - Windows → RqbitTorrentService (bundled rqbit engine over local HTTP)
/// - Other platforms → MockTorrentService (simulation, no engine yet)
final torrentServiceProvider = Provider<ITorrentService>((ref) {
  final ITorrentService service;
  if (kIsWeb) {
    service = WebTorrentService();
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    service = NativeTorrentService();
  } else if (defaultTargetPlatform == TargetPlatform.windows) {
    service = RqbitTorrentService();
  } else {
    service = MockTorrentService();
  }
  ref.onDispose(service.dispose);
  return service;
});

/// Singleton [TorrentRepository] backed by the service.
final torrentRepositoryProvider = Provider<TorrentRepository>((ref) {
  return TorrentRepositoryImpl(ref.watch(torrentServiceProvider));
});

// ── Use cases ──────────────────────────────────────────────────────────────────

final addMagnetUseCaseProvider = Provider<AddMagnetUseCase>(
  (ref) => AddMagnetUseCase(ref.watch(torrentRepositoryProvider)),
);

final addTorrentFileUseCaseProvider = Provider<AddTorrentFileUseCase>(
  (ref) => AddTorrentFileUseCase(ref.watch(torrentRepositoryProvider)),
);

final pauseTorrentUseCaseProvider = Provider<PauseTorrentUseCase>(
  (ref) => PauseTorrentUseCase(ref.watch(torrentRepositoryProvider)),
);

final resumeTorrentUseCaseProvider = Provider<ResumeTorrentUseCase>(
  (ref) => ResumeTorrentUseCase(ref.watch(torrentRepositoryProvider)),
);

final removeTorrentUseCaseProvider = Provider<RemoveTorrentUseCase>(
  (ref) => RemoveTorrentUseCase(ref.watch(torrentRepositoryProvider)),
);

final getTorrentsUseCaseProvider = Provider<GetTorrentsUseCase>(
  (ref) => GetTorrentsUseCase(ref.watch(torrentRepositoryProvider)),
);

// ── State notifier ─────────────────────────────────────────────────────────────

/// Manages the live list of torrents and exposes actions.
class TorrentNotifier extends Notifier<List<TorrentEntity>> {
  @override
  List<TorrentEntity> build() {
    // Subscribe to the service stream and update state on every emission.
    final useCase = ref.watch(getTorrentsUseCaseProvider);
    ref.listen<AsyncValue<List<TorrentEntity>>>(
      _allTorrentsStreamProvider,
      (_, next) {
        next.whenData((list) => state = list);
      },
    );
    return useCase.getAll();
  }

  Future<String> addMagnet(String magnetLink) async {
    final torrent = await ref.read(addMagnetUseCaseProvider).call(magnetLink);
    return torrent.id;
  }

  Future<String> addTorrentFile(String filePath) async {
    final torrent = await ref.read(addTorrentFileUseCaseProvider).call(filePath);
    return torrent.id;
  }

  Future<void> pause(String id) async {
    await ref.read(pauseTorrentUseCaseProvider).call(id);
  }

  Future<void> resume(String id) async {
    await ref.read(resumeTorrentUseCaseProvider).call(id);
  }

  Future<void> remove(String id, {bool deleteFiles = false}) async {
    await ref.read(removeTorrentUseCaseProvider).call(id, deleteFiles: deleteFiles);
  }

  /// Deletes, with their files, the torrents added more than [age] ago.
  /// Downloads are a hidden cache, so this is what keeps it from growing.
  Future<int> removeOlderThan(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    return _removeAll(state.where((t) => t.addedAt.isBefore(cutoff)));
  }

  /// Deletes every torrent and its files ("Liberar espacio").
  Future<int> removeEverything() => _removeAll(List.of(state));

  Future<int> _removeAll(Iterable<TorrentEntity> torrents) async {
    var removed = 0;
    for (final t in torrents.toList()) {
      try {
        await remove(t.id, deleteFiles: true);
        removed++;
      } catch (_) {
        // A torrent the engine cannot drop now is retried next time.
      }
    }
    return removed;
  }

  Future<void> selectFileForStreaming(String torrentId, String fileId) async {
    await ref
        .read(torrentRepositoryProvider)
        .selectFileForStreaming(torrentId, fileId);
  }
}

/// The primary provider for the torrent list state.
final torrentsProvider =
    NotifierProvider<TorrentNotifier, List<TorrentEntity>>(TorrentNotifier.new);

// ── Stream helper ──────────────────────────────────────────────────────────────

/// Internal stream provider that bridges the service stream into Riverpod.
final _allTorrentsStreamProvider =
    StreamProvider<List<TorrentEntity>>((ref) {
  return ref.watch(getTorrentsUseCaseProvider).watchAll();
});

// ── Selected torrent ───────────────────────────────────────────────────────────

/// The currently selected torrent id (set by navigation).
final selectedTorrentIdProvider =
    NotifierProvider<SelectedTorrentIdNotifier, String?>(
  SelectedTorrentIdNotifier.new,
);

class SelectedTorrentIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

/// Returns the [TorrentEntity] for the currently selected id, or null.
final selectedTorrentProvider = Provider<TorrentEntity?>((ref) {
  final id = ref.watch(selectedTorrentIdProvider);
  if (id == null) return null;
  final torrents = ref.watch(torrentsProvider);
  try {
    return torrents.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
});

/// Watches a single torrent by id.
final torrentByIdProvider =
    Provider.family<TorrentEntity?, String>((ref, id) {
  final torrents = ref.watch(torrentsProvider);
  try {
    return torrents.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
});

// ── Statistics ─────────────────────────────────────────────────────────────────

/// Aggregated download speed across all active torrents.
final totalDownloadSpeedProvider = Provider<double>((ref) {
  return ref
      .watch(torrentsProvider)
      .where((t) => t.status == TorrentStatus.downloading)
      .fold(0.0, (sum, t) => sum + t.downloadSpeed);
});

/// Aggregated upload speed across all torrents.
final totalUploadSpeedProvider = Provider<double>((ref) {
  return ref
      .watch(torrentsProvider)
      .fold(0.0, (sum, t) => sum + t.uploadSpeed);
});

/// Number of active (downloading) torrents.
final activeCountProvider = Provider<int>((ref) {
  return ref
      .watch(torrentsProvider)
      .where((t) => t.status == TorrentStatus.downloading)
      .length;
});

/// List of completed torrents (for the Files screen).
final completedTorrentsProvider = Provider<List<TorrentEntity>>((ref) {
  return ref
      .watch(torrentsProvider)
      .where((t) => t.status == TorrentStatus.completed)
      .toList();
});
