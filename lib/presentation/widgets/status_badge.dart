import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/torrent_entity.dart';

/// A compact pill-shaped badge that displays a [TorrentStatus].
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final TorrentStatus status;

  /// When true, shows only a coloured dot instead of the full label.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    final label = _labelForStatus(status);

    if (compact) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(128),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForStatus(TorrentStatus status) {
    switch (status) {
      case TorrentStatus.downloading:
        return AppTheme.accent;
      case TorrentStatus.completed:
        return AppTheme.success;
      case TorrentStatus.paused:
        return AppTheme.paused;
      case TorrentStatus.error:
        return AppTheme.error;
      case TorrentStatus.queued:
        return AppTheme.queued;
    }
  }

  String _labelForStatus(TorrentStatus status) {
    switch (status) {
      case TorrentStatus.downloading:
        return 'Downloading';
      case TorrentStatus.completed:
        return 'Completed';
      case TorrentStatus.paused:
        return 'Paused';
      case TorrentStatus.error:
        return 'Error';
      case TorrentStatus.queued:
        return 'Queued';
    }
  }
}
