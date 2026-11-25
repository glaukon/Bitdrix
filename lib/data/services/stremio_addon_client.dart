import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/stremio_addon.dart';

/// Talks to Stremio addons over their HTTP protocol: manifest, catalogs and
/// streams. It knows no addon in particular; the user installs them.
class StremioAddonClient {
  StremioAddonClient([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 25),
              // Addons answer JSON, sometimes labelled text/plain.
              responseType: ResponseType.plain,
            ));

  final Dio _dio;

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await _dio.get<String>(url);
    final body = response.data ?? '';
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('La respuesta del addon no es válida.');
    }
    return decoded;
  }

  /// Downloads the raw manifest at [url] (already normalised with
  /// [StremioAddon.normalizeManifestUrl]) and checks it is one.
  Future<Map<String, dynamic>> fetchManifestJson(String url) async {
    const notAnAddon = FormatException(
        'Esa dirección no devuelve un manifiesto de addon de Stremio.');
    final Map<String, dynamic> json;
    try {
      json = await _getJson(url);
    } on FormatException {
      throw notAnAddon;
    }
    if (json['id'] is! String || json['resources'] is! List) throw notAnAddon;
    return json;
  }

  /// Items of a catalog. [search] and [genre] are the catalog's extras.
  Future<List<StremioMeta>> getCatalog(
    StremioAddon addon,
    StremioCatalog catalog, {
    String? search,
    String? genre,
    int skip = 0,
  }) async {
    final extras = <String>[
      if (search != null && search.trim().isNotEmpty)
        'search=${Uri.encodeComponent(search.trim())}',
      if (genre != null && genre.isNotEmpty)
        'genre=${Uri.encodeComponent(genre)}',
      if (skip > 0) 'skip=$skip',
    ];
    final path = [
      'catalog',
      Uri.encodeComponent(catalog.type),
      Uri.encodeComponent(catalog.id),
      if (extras.isNotEmpty) extras.join('&'),
    ].join('/');
    final json = await _getJson('${addon.baseUrl}/$path.json');
    return [
      for (final m in json['metas'] as List<dynamic>? ?? [])
        if (m is Map<String, dynamic>) StremioMeta.fromJson(m),
    ].where((m) => m.id.isNotEmpty).toList();
  }

  /// Streams one addon offers for an item.
  Future<List<StremioStream>> getStreams(
    StremioAddon addon,
    String type,
    String id,
  ) async {
    final url = '${addon.baseUrl}/stream/${Uri.encodeComponent(type)}/'
        '${Uri.encodeComponent(id)}.json';
    final json = await _getJson(url);
    return [
      for (final s in json['streams'] as List<dynamic>? ?? [])
        if (s is Map<String, dynamic>) StremioStream.fromJson(addon.name, s),
    ];
  }
}
