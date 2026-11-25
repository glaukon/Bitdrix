import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/speed_formatter.dart';

/// Displays a download and/or upload speed with directional arrow icons.
class SpeedIndicator extends StatelessWidget {
  const SpeedIndicator({
    super.key,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.showUpload = true,
    this.compact = false,
  });

  final double downloadSpeed;
  final double uploadSpeed;

  /// Whether to also show the upload speed.
  final bool showUpload;

  /// When true, uses a smaller text style.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 11.0 : 13.0;
    final iconSize = compact ? 12.0 : 14.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SpeedItem(
          icon: Icons.arrow_downward_rounded,
          color: AppTheme.accent,
          speed: downloadSpeed,
          fontSize: fontSize,
          iconSize: iconSize,
        ),
        if (showUpload) ...[
          SizedBox(width: compact ? 8 : 12),
          _SpeedItem(
            icon: Icons.arrow_upward_rounded,
            color: AppTheme.success,
            speed: uploadSpeed,
            fontSize: fontSize,
            iconSize: iconSize,
          ),
        ],
      ],
    );
  }
}

class _SpeedItem extends StatelessWidget {
  const _SpeedItem({
    required this.icon,
    required this.color,
    required this.speed,
    required this.fontSize,
    required this.iconSize,
  });

  final IconData icon;
  final Color color;
  final double speed;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: iconSize),
        const SizedBox(width: 2),
        Text(
          SpeedFormatter.format(speed),
          style: TextStyle(
            color: AppTheme.onSurface,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
