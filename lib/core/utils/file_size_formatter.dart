import '../constants/app_constants.dart';

/// Formats raw byte counts into human-readable strings.
class FileSizeFormatter {
  FileSizeFormatter._();

  /// Returns a string like "4.2 GB", "512 MB", "1.3 KB", or "800 B".
  static String format(int bytes, {int decimals = 1}) {
    if (bytes < 0) return '0 B';
    if (bytes < AppConstants.bytesInKb) return '$bytes B';
    if (bytes < AppConstants.bytesInMb) {
      final kb = bytes / AppConstants.bytesInKb;
      return '${kb.toStringAsFixed(decimals)} KB';
    }
    if (bytes < AppConstants.bytesInGb) {
      final mb = bytes / AppConstants.bytesInMb;
      return '${mb.toStringAsFixed(decimals)} MB';
    }
    final gb = bytes / AppConstants.bytesInGb;
    return '${gb.toStringAsFixed(decimals)} GB';
  }

  /// Parses a formatted size string back to bytes (best effort).
  static int parse(String formatted) {
    final parts = formatted.trim().split(' ');
    if (parts.length != 2) return 0;
    final value = double.tryParse(parts[0]) ?? 0;
    switch (parts[1].toUpperCase()) {
      case 'KB':
        return (value * AppConstants.bytesInKb).round();
      case 'MB':
        return (value * AppConstants.bytesInMb).round();
      case 'GB':
        return (value * AppConstants.bytesInGb).round();
      default:
        return value.round();
    }
  }
}
