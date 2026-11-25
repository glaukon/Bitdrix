import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';

/// A slim rounded progress bar used while a video loads.
///
/// With a [value] (0–1) it shows real progress and eases between updates;
/// without one it shows an indeterminate sweep.
class LoadingBar extends StatelessWidget {
  const LoadingBar({super.key, this.value, this.width = 280});

  final double? value;
  final double width;

  @override
  Widget build(BuildContext context) {
    const height = 6.0;
    final radius = BorderRadius.circular(height / 2);
    final target = value?.clamp(0.0, 1.0);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: target == null
            ? const LinearProgressIndicator(
                minHeight: height,
                color: AppTheme.primary,
                backgroundColor: Colors.white12,
              )
            : TweenAnimationBuilder<double>(
                tween: Tween(end: target),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: height,
                  color: AppTheme.primary,
                  backgroundColor: Colors.white12,
                ),
              ),
      ),
    );
  }
}
