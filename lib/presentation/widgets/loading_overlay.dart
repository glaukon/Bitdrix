import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Semi-transparent overlay with a progress indicator and optional message.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    this.message,
    this.child,
    this.isLoading = true,
  });

  final String? message;

  /// When wrapping a child widget, the overlay is drawn on top when loading.
  final Widget? child;

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (child != null) {
      return Stack(
        children: [
          child!,
          if (isLoading) _overlay(),
        ],
      );
    }
    return _overlay();
  }

  Widget _overlay() {
    return Container(
      color: Colors.black.withAlpha(153),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primary.withAlpha(51),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: const TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
