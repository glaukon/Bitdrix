import 'file_size_formatter.dart';

/// Formats transfer speeds (bytes per second) into human-readable strings.
class SpeedFormatter {
  SpeedFormatter._();

  /// Returns a string like "3.2 MB/s", "512 KB/s", or "0 B/s".
  static String format(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    return '${FileSizeFormatter.format(bytesPerSecond.round())}/s';
  }

  /// Returns only the numeric portion without the unit.
  static String formatValue(double bytesPerSecond) {
    final full = format(bytesPerSecond);
    final parts = full.split(' ');
    return parts.isNotEmpty ? parts[0] : '0';
  }

  /// Returns only the unit portion (e.g. "MB/s").
  static String formatUnit(double bytesPerSecond) {
    final full = format(bytesPerSecond);
    final parts = full.split(' ');
    return parts.length > 1 ? parts[1] : 'B/s';
  }
}
