import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';

/// A newer version published on GitHub.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.pageUrl,
    this.notes,
    this.downloadUrl,
    this.downloadName,
  });

  final String version;

  /// The release page on GitHub.
  final String pageUrl;

  /// The release description (what is new), in Markdown.
  final String? notes;

  /// The installer for this platform, when the release has one.
  final String? downloadUrl;
  final String? downloadName;
}

/// Looks for a newer BitDrix in the repository's GitHub releases.
///
/// Releases are tagged with the version (`v1.2.0` or `1.2.0`); drafts and
/// pre-releases are ignored by GitHub's "latest" endpoint.
class UpdateService {
  UpdateService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.github.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/vnd.github+json'},
            ),
          );

  final Dio _dio;

  /// The newer version, or null when [currentVersion] is the latest (or
  /// nothing has been published yet). Throws on network errors.
  Future<AppUpdate?> check({
    String currentVersion = AppConstants.appVersion,
  }) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(
        '/repos/${AppConstants.githubRepo}/releases/latest',
      );
    } on DioException catch (e) {
      // No release published yet.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
    final release = response.data ?? const {};
    final tag = release['tag_name'] as String? ?? '';
    if (compareVersions(tag, currentVersion) <= 0) return null;

    final assets = [
      for (final a in release['assets'] as List<dynamic>? ?? [])
        if (a is Map<String, dynamic> &&
            a['name'] is String &&
            a['browser_download_url'] is String)
          (name: a['name'] as String, url: a['browser_download_url'] as String),
    ];
    final asset = pickAsset(assets, defaultTargetPlatform, isWeb: kIsWeb);
    return AppUpdate(
      version: normalizeVersion(tag),
      pageUrl:
          release['html_url'] as String? ??
          'https://github.com/${AppConstants.githubRepo}/releases',
      notes: (release['body'] as String?)?.trim(),
      downloadUrl: asset?.url,
      downloadName: asset?.name,
    );
  }

  /// "v1.2.0" → "1.2.0"; build suffixes ("+3", "-beta") are dropped.
  static String normalizeVersion(String version) => version
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[+-]'))
      .first;

  /// Negative when [a] is older than [b], 0 when equal, positive when newer.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => [
      for (final p in normalizeVersion(v).split('.')) int.tryParse(p) ?? 0,
    ];
    final pa = parts(a);
    final pb = parts(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  /// The release file for this platform: an .exe/.msix/.zip for Windows,
  /// an .apk for Android. Null on the web (it always serves the latest) or
  /// when the release has none.
  static ({String name, String url})? pickAsset(
    List<({String name, String url})> assets,
    TargetPlatform platform, {
    bool isWeb = false,
  }) {
    if (isWeb) return null;
    bool has(String name, List<String> endings) =>
        endings.any((e) => name.toLowerCase().endsWith(e));
    switch (platform) {
      case TargetPlatform.windows:
        final windows =
            assets
                .where((a) => has(a.name, const ['.exe', '.msix', '.zip']))
                .toList()
              // An installer beats a zip; a file that names Windows beats others.
              ..sort((a, b) {
                int rank(String n) =>
                    (has(n, const ['.exe', '.msix']) ? 0 : 2) +
                    (n.toLowerCase().contains('win') ? 0 : 1);
                return rank(a.name).compareTo(rank(b.name));
              });
        return windows.firstOrNull;
      case TargetPlatform.android:
        return assets.where((a) => has(a.name, const ['.apk'])).firstOrNull;
      default:
        return null;
    }
  }
}
