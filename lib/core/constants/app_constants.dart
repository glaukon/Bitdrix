/// Application-wide constants for Bitdrix.
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'BitDrix';
  /// Keep in step with `version:` in pubspec.yaml (a test checks it): the
  /// update check compares it with the latest GitHub release.
  static const String appVersion = '1.0.0';

  /// GitHub repository whose releases carry the updates.
  static const String githubRepo = 'glaukon/Bitdrix';

  // Navigation routes
  static const String routeHome = '/';
  static const String routeTorrents = '/torrents';
  static const String routeAddTorrent = '/torrents/add';
  static const String routeTorrentDetail = '/torrents/:id';
  static const String routeFiles = '/files';
  static const String routePlayer = '/player';

  // Storage keys
  static const String keyTorrents = 'bitdrix_torrents';
  static const String keySettings = 'bitdrix_settings';
  static const String keyDownloadPath = 'bitdrix_download_path';

  // Mock simulation
  static const Duration mockUpdateInterval = Duration(seconds: 1);
  static const double mockMaxDownloadSpeed = 5 * 1024 * 1024; // 5 MB/s
  static const double mockMaxUploadSpeed = 1 * 1024 * 1024;   // 1 MB/s

  // File size thresholds
  static const int bytesInKb = 1024;
  static const int bytesInMb = 1024 * 1024;
  static const int bytesInGb = 1024 * 1024 * 1024;

  // UI
  static const double cardBorderRadius = 12.0;
  static const double screenPadding = 16.0;
  static const double fabBottomPadding = 80.0;

  // Supported video extensions for in-app playback
  static const List<String> videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v',
  ];

  // Magnet link prefix
  static const String magnetPrefix = 'magnet:?';
}
