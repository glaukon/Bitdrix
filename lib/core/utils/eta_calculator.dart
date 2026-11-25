/// Calculates estimated time of arrival (ETA) for a download.
class EtaCalculator {
  EtaCalculator._();

  /// Returns a human-readable ETA string given remaining bytes and speed.
  ///
  /// Returns '--' when the speed is zero or the download is complete.
  static String calculate({
    required int remainingBytes,
    required double speedBytesPerSecond,
  }) {
    if (remainingBytes <= 0) return 'Terminado';
    if (speedBytesPerSecond <= 0) return '--';

    final seconds = (remainingBytes / speedBytesPerSecond).round();
    return _formatDuration(Duration(seconds: seconds));
  }

  /// Formats a [Duration] into a compact string like "2h 15m", "45m 30s", "10s".
  static String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';

    if (d.inMinutes < 60) {
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return s > 0 ? '${m}m ${s}s' : '${m}m';
    }

    if (d.inHours < 24) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }

    final days = d.inDays;
    final h = d.inHours % 24;
    return h > 0 ? '${days}d ${h}h' : '${days}d';
  }

  /// Returns the raw [Duration] from remaining bytes and speed, or null.
  static Duration? calculateDuration({
    required int remainingBytes,
    required double speedBytesPerSecond,
  }) {
    if (remainingBytes <= 0 || speedBytesPerSecond <= 0) return null;
    final seconds = (remainingBytes / speedBytesPerSecond).round();
    return Duration(seconds: seconds);
  }
}
