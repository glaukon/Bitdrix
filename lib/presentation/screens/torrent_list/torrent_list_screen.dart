import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/speed_formatter.dart';
import '../../../domain/entities/torrent_entity.dart';
import '../../providers/torrent_providers.dart';
import '../../widgets/empty_state.dart';
import 'widgets/torrent_card.dart';

class TorrentListScreen extends ConsumerWidget {
  const TorrentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final torrents = ref.watch(torrentsProvider);
    final dlSpeed = ref.watch(totalDownloadSpeedProvider);
    final ulSpeed = ref.watch(totalUploadSpeedProvider);
    final activeCount = ref.watch(activeCountProvider);

    return Scaffold(
      body: Column(
        children: [
          if (torrents.isNotEmpty) _buildStatsBar(dlSpeed, ulSpeed, activeCount),
          Expanded(
            child: torrents.isEmpty
                ? EmptyState(
                    icon: Icons.downloading_rounded,
                    title: 'No Torrents Yet',
                    subtitle:
                        'Add a magnet link or open a .torrent file to get started.',
                    actionLabel: 'Add Torrent',
                    onAction: () => context.push('/torrents/add'),
                  )
                : _buildList(torrents),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/torrents/add'),
        tooltip: 'Add torrent',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildStatsBar(double dl, double ul, int active) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.arrow_downward_rounded,
            color: AppTheme.accent,
            value: SpeedFormatter.format(dl),
            label: 'Download',
          ),
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.arrow_upward_rounded,
            color: AppTheme.success,
            value: SpeedFormatter.format(ul),
            label: 'Upload',
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withAlpha(77),
                width: 1,
              ),
            ),
            child: Text(
              '$active active',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<TorrentEntity> torrents) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 90),
      itemCount: torrents.length,
      itemBuilder: (ctx, i) => TorrentCard(torrent: torrents[i]),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
