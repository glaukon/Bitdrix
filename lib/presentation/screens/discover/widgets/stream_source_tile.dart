import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/stream_source_model.dart';

/// A list tile that displays one torrent stream source.
///
/// Layout:
/// - Left:   quality badge (color-coded)
/// - Middle: filename + seeder count
/// - Right:  "Add" icon button
class StreamSourceTile extends StatelessWidget {
  const StreamSourceTile({
    super.key,
    required this.source,
    required this.onAdd,
  });

  final StreamSourceModel source;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _QualityBadge(quality: source.quality),
              const SizedBox(width: 12),
              Expanded(child: _InfoColumn(source: source)),
              const SizedBox(width: 8),
              _AddButton(onTap: onAdd),
            ],
          ),
        ),
        const Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: Color(0xFF222233),
        ),
      ],
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.quality});

  final String quality;

  Color get _color {
    switch (quality) {
      case '4K':
        return const Color(0xFFFFD700); // gold
      case '1080p':
        return AppTheme.accent;
      case '720p':
        return AppTheme.success;
      default:
        return AppTheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withAlpha(128), width: 1),
      ),
      child: Text(
        quality,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.source});

  final StreamSourceModel source;

  @override
  Widget build(BuildContext context) {
    final filename = source.behaviorHintsFilename ?? source.name;
    final seeders = source.seeders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filename,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        if (seeders != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 13,
                color: AppTheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Text(
                '$seeders seeders',
                style: const TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
        if (source.audioBadges.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: source.audioBadges
                .map((badge) => _AudioBadge(label: badge))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _AudioBadge extends StatelessWidget {
  const _AudioBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'CAST' => AppTheme.success,
      'ESP' => AppTheme.warning,
      'LAT' => AppTheme.paused,
      _ => AppTheme.accent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.add_circle_outline_rounded),
      color: AppTheme.accent,
      iconSize: 28,
      tooltip: 'Add to downloads',
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.accent.withAlpha(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(6),
      ),
    );
  }
}
