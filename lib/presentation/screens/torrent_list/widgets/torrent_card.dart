import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/eta_calculator.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../../domain/entities/torrent_entity.dart';
import '../../../providers/torrent_providers.dart';
import '../../../widgets/speed_indicator.dart';
import '../../../widgets/status_badge.dart';

/// Card widget representing a single torrent in the list.
class TorrentCard extends ConsumerWidget {
  const TorrentCard({super.key, required this.torrent});

  final TorrentEntity torrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(torrent.id),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => ref
          .read(torrentsProvider.notifier)
          .remove(torrent.id),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          onTap: () {
            ref.read(selectedTorrentIdProvider.notifier).state = torrent.id;
            context.push('/torrents/${torrent.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                _buildProgressBar(),
                const SizedBox(height: 8),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildTypeIcon(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                torrent.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                FileSizeFormatter.format(torrent.totalSize),
                style: const TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        StatusBadge(status: torrent.status),
      ],
    );
  }

  Widget _buildTypeIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333348), width: 1),
      ),
      child: const Icon(
        Icons.downloading_rounded,
        color: AppTheme.primary,
        size: 20,
      ),
    );
  }

  Widget _buildProgressBar() {
    final percent = torrent.progress.clamp(0.0, 1.0);
    final progressColor = torrent.status == TorrentStatus.completed
        ? AppTheme.success
        : torrent.status == TorrentStatus.error
            ? AppTheme.error
            : AppTheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(percent * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: progressColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${FileSizeFormatter.format(torrent.downloadedSize)} / '
              '${FileSizeFormatter.format(torrent.totalSize)}',
              style: const TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearPercentIndicator(
          percent: percent,
          lineHeight: 5,
          padding: EdgeInsets.zero,
          backgroundColor: AppTheme.surfaceVariant,
          progressColor: progressColor,
          barRadius: const Radius.circular(3),
          animation: false,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final eta = torrent.status == TorrentStatus.downloading
        ? EtaCalculator.calculate(
            remainingBytes: torrent.remainingBytes,
            speedBytesPerSecond: torrent.downloadSpeed,
          )
        : null;

    return Row(
      children: [
        SpeedIndicator(
          downloadSpeed: torrent.downloadSpeed,
          uploadSpeed: torrent.uploadSpeed,
          compact: true,
        ),
        const Spacer(),
        if (eta != null && torrent.status == TorrentStatus.downloading)
          Text(
            'Restante: $eta',
            style: const TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        const SizedBox(width: 8),
        Text(
          '${torrent.seeds} semillas',
          style: const TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.error.withAlpha(26),
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        border: Border.all(color: AppTheme.error.withAlpha(77)),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 24),
          SizedBox(height: 4),
          Text(
            'Eliminar',
            style: TextStyle(
              color: AppTheme.error,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar torrent'),
        content: Text(
          '¿Quitar "${torrent.name}" de la lista?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
