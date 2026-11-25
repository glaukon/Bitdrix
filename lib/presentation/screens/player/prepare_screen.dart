import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_size_formatter.dart';
import '../../../domain/entities/torrent_entity.dart';
import '../../../domain/entities/torrent_file_entity.dart';
import '../../providers/torrent_providers.dart';
import '../../widgets/loading_bar.dart';

/// Full-screen "getting ready" page shown between choosing a source and
/// playback. It waits for the torrent metadata, picks the video file, asks the
/// engine to stream it and then replaces itself with the player — the user
/// never sees the download screen.
class PrepareScreen extends ConsumerStatefulWidget {
  const PrepareScreen({
    super.key,
    required this.torrentId,
    required this.title,
    this.backdropUrl,
    this.posterUrl,
    this.preferredFileName,
  });

  final String torrentId;
  final String title;
  final String? backdropUrl;
  final String? posterUrl;

  /// File name hinted by the source (e.g. the episode inside a season pack).
  final String? preferredFileName;

  @override
  ConsumerState<PrepareScreen> createState() => _PrepareScreenState();
}

class _PrepareScreenState extends ConsumerState<PrepareScreen> {
  static const _slowAfter = Duration(seconds: 45);

  bool _starting = false;
  bool _slow = false;
  String? _error;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(_slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  // ── Flow ──────────────────────────────────────────────────────────────────

  void _maybeStart(TorrentEntity torrent) {
    if (_starting || _error != null || torrent.files.isEmpty) return;
    final file = _pickFile(torrent.files);
    if (file == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _error = 'Este torrent no tiene ningún vídeo reproducible.');
        }
      });
      return;
    }
    _starting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start(torrent, file));
  }

  Future<void> _start(TorrentEntity torrent, TorrentFileEntity file) async {
    try {
      await ref
          .read(torrentsProvider.notifier)
          .selectFileForStreaming(torrent.id, file.id);
      if (!mounted) return;
      context.pushReplacement('/player', extra: {
        'filePath': '',
        'title': widget.title,
        'torrentId': torrent.id,
        'selectedFileId': file.id,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = 'No se ha podido preparar el vídeo.\n$e';
      });
    }
  }

  TorrentFileEntity? _pickFile(List<TorrentFileEntity> files) {
    final videos = files
        .where((f) => AppConstants.videoExtensions.contains(f.extension))
        .toList();
    if (videos.isEmpty) return null;

    final hint = widget.preferredFileName?.toLowerCase();
    if (hint != null && hint.isNotEmpty) {
      for (final f in videos) {
        final name = f.name.toLowerCase();
        if (name == hint || name.contains(hint) || hint.contains(name)) return f;
      }
    }
    // Otherwise the biggest video: the feature, not a sample or extra.
    videos.sort((a, b) => b.size.compareTo(a.size));
    return videos.first;
  }

  Future<void> _cancel() async {
    // The torrent was only added to watch it now: drop it and its data.
    // Leaving must never depend on that working.
    try {
      await ref
          .read(torrentsProvider.notifier)
          .remove(widget.torrentId, deleteFiles: true);
    } catch (e) {
      debugPrint('Could not remove torrent ${widget.torrentId}: $e');
    }
    if (mounted) context.pop();
  }

  void _retry() {
    setState(() {
      _error = null;
      _slow = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(_slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
    ref.read(torrentsProvider.notifier).resume(widget.torrentId);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final torrent = ref.watch(torrentByIdProvider(widget.torrentId));
    if (torrent != null) _maybeStart(torrent);

    final engineError = torrent?.status == TorrentStatus.error
        ? (torrent?.errorMessage ?? 'La descarga ha fallado.')
        : null;
    final error = _error ?? engineError;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.backdropUrl != null || widget.posterUrl != null)
              Image.network(
                widget.backdropUrl ?? widget.posterUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0xE6000000), Colors.black],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      tooltip: 'Cancelar',
                      onPressed: _cancel,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: error != null
                        ? _buildError(error, torrent)
                        : _buildProgress(torrent),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(TorrentEntity? torrent) {
    final peers = torrent?.peers ?? 0;
    final hasFiles = torrent?.files.isNotEmpty ?? false;
    final step = _starting
        ? 'Iniciando reproducción...'
        : hasFiles
            ? 'Preparando el vídeo...'
            : peers > 0
                ? 'Obteniendo información del vídeo...'
                : 'Buscando fuentes...';
    final speed = torrent?.downloadSpeed ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 32),
        const LoadingBar(),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            step,
            key: ValueKey(step),
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          peers > 0
              ? '$peers pares · ${FileSizeFormatter.format(speed.round())}/s'
              : ' ',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        if (_slow) ...[
          const SizedBox(height: 28),
          const Text(
            'Está tardando más de lo normal. Puede que la fuente tenga pocas '
            'semillas: prueba con otra.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _cancel,
            child: const Text('Elegir otra fuente'),
          ),
        ],
      ],
    );
  }

  Widget _buildError(String message, TorrentEntity? torrent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 48),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton(onPressed: _cancel, child: const Text('Volver')),
            if (torrent != null && _error == null)
              FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
          ],
        ),
      ],
    );
  }
}
