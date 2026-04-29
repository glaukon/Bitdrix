import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/eta_calculator.dart';
import '../../../core/utils/file_size_formatter.dart';
import '../../../core/utils/speed_formatter.dart';
import '../../../domain/entities/torrent_entity.dart';
import '../../../domain/entities/torrent_file_entity.dart';
import '../../providers/torrent_providers.dart';
import '../../widgets/status_badge.dart';

class TorrentDetailScreen extends ConsumerWidget {
  const TorrentDetailScreen({super.key, required this.torrentId});

  final String torrentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final torrent = ref.watch(torrentByIdProvider(torrentId));

    if (torrent == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Torrent Detail')),
        body: const Center(
          child: Text(
            'Torrent not found.',
            style: TextStyle(color: AppTheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          torrent.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Remove torrent',
            onPressed: () => _confirmRemove(context, ref, torrent),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProgressSection(torrent),
          const SizedBox(height: 16),
          _buildStatsGrid(torrent),
          const SizedBox(height: 16),
          _buildControlButtons(context, ref, torrent),
          const SizedBox(height: 20),
          _buildFilesSection(context, ref, torrent),
        ],
      ),
    );
  }

  Widget _buildProgressSection(TorrentEntity torrent) {
    final percent = torrent.progress.clamp(0.0, 1.0);
    final progressColor = torrent.status == TorrentStatus.completed
        ? AppTheme.success
        : torrent.status == TorrentStatus.error
            ? AppTheme.error
            : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222233)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircularPercentIndicator(
                radius: 52,
                lineWidth: 7,
                percent: percent,
                animation: true,
                animateFromLastPercent: true,
                center: Text(
                  '${(percent * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                progressColor: progressColor,
                backgroundColor: AppTheme.surfaceVariant,
                circularStrokeCap: CircularStrokeCap.round,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge(status: torrent.status),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'Downloaded',
                      value: FileSizeFormatter.format(torrent.downloadedSize),
                    ),
                    const SizedBox(height: 6),
                    _InfoRow(
                      label: 'Total Size',
                      value: FileSizeFormatter.format(torrent.totalSize),
                    ),
                    const SizedBox(height: 6),
                    _InfoRow(
                      label: 'Uploaded',
                      value: FileSizeFormatter.format(torrent.uploadedSize),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (torrent.status == TorrentStatus.downloading) ...[
            const SizedBox(height: 16),
            Text(
              'ETA: ${EtaCalculator.calculate(
                remainingBytes: torrent.remainingBytes,
                speedBytesPerSecond: torrent.downloadSpeed,
              )}',
              style: const TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid(TorrentEntity torrent) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: [
        _StatCard(
          icon: Icons.arrow_downward_rounded,
          color: AppTheme.accent,
          label: 'Download',
          value: SpeedFormatter.format(torrent.downloadSpeed),
        ),
        _StatCard(
          icon: Icons.arrow_upward_rounded,
          color: AppTheme.success,
          label: 'Upload',
          value: SpeedFormatter.format(torrent.uploadSpeed),
        ),
        _StatCard(
          icon: Icons.people_outline_rounded,
          color: AppTheme.primary,
          label: 'Peers',
          value: torrent.peers.toString(),
        ),
        _StatCard(
          icon: Icons.cloud_done_outlined,
          color: AppTheme.primaryLight,
          label: 'Seeds',
          value: torrent.seeds.toString(),
        ),
      ],
    );
  }

  Widget _buildControlButtons(
    BuildContext context,
    WidgetRef ref,
    TorrentEntity torrent,
  ) {
    final notifier = ref.read(torrentsProvider.notifier);
    return Row(
      children: [
        if (torrent.status == TorrentStatus.downloading)
          Expanded(
            child: _ControlButton(
              icon: Icons.pause_rounded,
              label: 'Pause',
              color: AppTheme.warning,
              onPressed: () => notifier.pause(torrent.id),
            ),
          ),
        if (torrent.canResume)
          Expanded(
            child: _ControlButton(
              icon: Icons.play_arrow_rounded,
              label: 'Resume',
              color: AppTheme.success,
              onPressed: () => notifier.resume(torrent.id),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: _ControlButton(
            icon: Icons.delete_outline_rounded,
            label: 'Remove',
            color: AppTheme.error,
            onPressed: () => _confirmRemove(context, ref, torrent),
          ),
        ),
      ],
    );
  }

  Widget _buildFilesSection(
    BuildContext context,
    WidgetRef ref,
    TorrentEntity torrent,
  ) {
    if (torrent.files.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF222233)),
        ),
        child: Text(
          torrent.status == TorrentStatus.error
              ? 'Could not load real files for this torrent.'
              : 'Loading real files from torrent metadata…',
          style: const TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Files',
          style: TextStyle(
            color: AppTheme.onBackground,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...torrent.files.map((file) => _FileRow(
              file: file,
              onPlay: AppConstants.videoExtensions.contains(file.extension)
                  ? () => _streamFile(context, ref, torrent, file)
                  : null,
            )),
      ],
    );
  }

  Future<void> _streamFile(
    BuildContext context,
    WidgetRef ref,
    TorrentEntity torrent,
    TorrentFileEntity file,
  ) async {
    try {
      await ref
          .read(torrentsProvider.notifier)
          .selectFileForStreaming(torrent.id, file.id);

      if (!context.mounted) return;

      context.push('/player', extra: {
        'filePath': '',
        'title': file.name,
        'torrentId': torrent.id,
        'selectedFileId': file.id,
      });
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not prepare this file for playback.'),
        ),
      );
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    TorrentEntity torrent,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Torrent'),
        content: Text('Remove "${torrent.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (result == true && context.mounted) {
      await ref.read(torrentsProvider.notifier).remove(torrent.id);
      if (context.mounted) context.pop();
    }
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.onBackground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222233)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withAlpha(26),
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(77)),
        minimumSize: const Size(0, 46),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, this.onPlay});
  final TorrentFileEntity file;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF222233)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForExtension(file.extension),
                color: AppTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onPlay != null)
                GestureDetector(
                  onTap: onPlay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: AppTheme.primary, size: 16),
                        SizedBox(width: 3),
                        Text(
                          file.isCompleted ? 'Play' : 'Stream',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearPercentIndicator(
                  percent: file.progress.clamp(0.0, 1.0),
                  lineHeight: 4,
                  padding: EdgeInsets.zero,
                  backgroundColor: AppTheme.surfaceVariant,
                  progressColor: file.isCompleted
                      ? AppTheme.success
                      : AppTheme.primary,
                  barRadius: const Radius.circular(2),
                  animation: false,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${FileSizeFormatter.format(file.downloadedSize)} / '
                '${FileSizeFormatter.format(file.size)}',
                style: const TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForExtension(String ext) {
    if (AppConstants.videoExtensions.contains(ext)) {
      return Icons.movie_outlined;
    }
    if (['mp3', 'flac', 'aac', 'ogg', 'wav'].contains(ext)) {
      return Icons.audio_file_outlined;
    }
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return Icons.image_outlined;
    }
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }
}
