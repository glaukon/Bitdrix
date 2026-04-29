import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/stream_source_model.dart';

/// Service for fetching torrent stream sources from the Torrentio Stremio add-on.
///
/// API reference: https://torrentio.strem.fun/configure
class TorrentioService {
  TorrentioService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://torrentio.strem.fun',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
  }

  late final Dio _dio;

  /// Fetches available torrent streams for a movie or TV show.
  ///
  /// - [imdbId]    — IMDB identifier, e.g. `'tt1375666'`.
  /// - [mediaType] — `'movie'` or `'tv'`.
  /// - [season]    — required for TV; ignored for movies.
  /// - [episode]   — required for TV; ignored for movies.
  ///
  /// Network errors are allowed to bubble up so the UI can distinguish a failed
  /// request from a valid "no streams found" response.
  Future<List<StreamSourceModel>> getSources(
    String imdbId,
    String mediaType, {
    int? season,
    int? episode,
  }) async {
    final String path;
    if (mediaType == 'tv' && season != null && episode != null) {
      path = '/stream/series/$imdbId:$season:$episode.json';
    } else {
      path = '/stream/movie/$imdbId.json';
    }

    final response = await _dio.get(path);
    final data = _asMap(response.data);
    final streams = data['streams'] as List<dynamic>? ?? [];

    return streams
        .map(_sourceFromJson)
        .whereType<StreamSourceModel>()
        .where((s) => s.resolvedMagnetUrl != null)
        .toList();
  }

  Map<String, dynamic> _asMap(dynamic data) {
    final decoded = data is String ? jsonDecode(data) : data;
    return Map<String, dynamic>.from(decoded as Map);
  }

  StreamSourceModel? _sourceFromJson(dynamic raw) {
    try {
      return StreamSourceModel.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
    } catch (_) {
      return null;
    }
  }
}
