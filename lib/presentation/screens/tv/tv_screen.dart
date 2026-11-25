import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/genre_labels.dart';
import '../../../data/models/stremio_addon.dart';
import '../../providers/addon_providers.dart';
import '../../widgets/horizontal_scroller.dart';
import '../../widgets/selectable_chip.dart';
import '../home/addons_section.dart';

/// Live TV from the user's Stremio addons: one chip per TV catalog the
/// installed addons offer, plus favourites.
class TvScreen extends ConsumerStatefulWidget {
  const TvScreen({super.key});

  @override
  ConsumerState<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends ConsumerState<TvScreen> {
  final _search = TextEditingController();

  /// Selected catalog, by `manifestUrl|type|id`; null shows favourites.
  String? _selected;
  bool _initialized = false;

  /// Category of the selected catalog; null shows all of them.
  String? _genre;

  static String _keyOf(AddonCatalog c) =>
      '${c.addon.manifestUrl}|${c.catalog.type}|${c.catalog.id}';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addonsAsync = ref.watch(installedAddonsProvider);
    if (addonsAsync.isLoading && !addonsAsync.hasValue) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    final catalogs = ref.watch(tvCatalogsProvider);
    final favorites = ref.watch(favoriteMetasProvider);
    if (catalogs.isEmpty) return const _NoTvAddons();

    // First visit: favourites if any, else the first catalog.
    if (!_initialized ||
        (_selected != null && !catalogs.any((c) => _keyOf(c) == _selected))) {
      _initialized = true;
      _selected = favorites.isNotEmpty ? null : _keyOf(catalogs.first);
    }
    final source = catalogs.where((c) => _keyOf(c) == _selected).firstOrNull;
    final query = _search.text.trim().toLowerCase();
    // Several addons can name their catalogs alike: tell them apart.
    final multipleAddons =
        catalogs.map((c) => c.addon.manifestUrl).toSet().length > 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: AppTheme.onBackground),
            decoration: InputDecoration(
              hintText: 'Buscar canal…',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppTheme.onSurfaceVariant),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      color: AppTheme.onSurfaceVariant,
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
        ),
        HorizontalScroller(
          height: 60,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          wheelScrollsSideways: true,
          itemCount: catalogs.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return SelectableChip(
                selected: _selected == null,
                onSelected: (_) => setState(() {
                  _selected = null;
                  _genre = null;
                }),
                avatar: const Icon(Icons.star_rounded, size: 18),
                label: 'Favoritos (${favorites.length})',
              );
            }
            final c = catalogs[i - 1];
            return SelectableChip(
              selected: _selected == _keyOf(c),
              onSelected: (_) => setState(() {
                if (_selected != _keyOf(c)) _genre = null;
                _selected = _keyOf(c);
              }),
              label: multipleAddons
                  ? '${c.catalog.name} · ${c.addon.name}'
                  : c.catalog.name,
            );
          },
        ),
        if (source != null && source.catalog.filterGenres.isNotEmpty)
          _GenreBar(
            genres: source.catalog.filterGenres,
            selected: _genre,
            onSelected: (g) => setState(() => _genre = g),
          ),
        Expanded(
          child: source == null
              ? _ChannelGrid(
                  items: _filter(favorites, query),
                  emptyMessage: favorites.isEmpty
                      ? 'Marca canales con la estrella para tenerlos aquí.'
                      : 'Ningún favorito se llama así.',
                )
              : _CatalogGrid(
                  source: source,
                  genre: _genre,
                  query: query,
                  filter: _filter,
                ),
        ),
      ],
    );
  }

  static List<StremioMeta> _filter(List<StremioMeta> items, String query) =>
      query.isEmpty
          ? items
          : items.where((m) => m.name.toLowerCase().contains(query)).toList();
}

/// The categories of the selected catalog (Stremio's genre filter).
class _GenreBar extends StatelessWidget {
  const _GenreBar({
    required this.genres,
    required this.selected,
    required this.onSelected,
  });

  final List<String> genres;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return HorizontalScroller(
      height: 52,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      wheelScrollsSideways: true,
      itemCount: genres.length + 1,
      itemBuilder: (_, i) => i == 0
          ? SelectableChip(
              selected: selected == null,
              onSelected: (_) => onSelected(null),
              avatar: const Icon(Icons.filter_list_rounded, size: 18),
              label: 'Todas',
            )
          : SelectableChip(
              selected: selected == genres[i - 1],
              onSelected: (_) => onSelected(genres[i - 1]),
              label: genreLabel(genres[i - 1]),
            ),
    );
  }
}

/// The channels of one addon catalog.
class _CatalogGrid extends ConsumerWidget {
  const _CatalogGrid({
    required this.source,
    required this.genre,
    required this.query,
    required this.filter,
  });

  final AddonCatalog source;
  final String? genre;
  final String query;
  final List<StremioMeta> Function(List<StremioMeta>, String) filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (source: source, genre: genre);
    final itemsAsync = ref.watch(catalogItemsProvider(args));
    return itemsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
      error: (_, _) => _Message(
        icon: Icons.cloud_off_rounded,
        text: 'El addon ${source.addon.name} no ha respondido.',
        action: TextButton.icon(
          onPressed: () => ref.invalidate(catalogItemsProvider(args)),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      ),
      data: (items) => RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        onRefresh: () => ref.refresh(catalogItemsProvider(args).future),
        child: _ChannelGrid(
          items: filter(items, query),
          emptyMessage: query.isNotEmpty
              ? 'Ningún canal se llama así.'
              : genre != null
                  ? 'No hay canales en esta categoría.'
                  : 'Este catálogo está vacío.',
        ),
      ),
    );
  }
}

class _ChannelGrid extends ConsumerWidget {
  const _ChannelGrid({required this.items, required this.emptyMessage});

  final List<StremioMeta> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return _Message(icon: Icons.live_tv_rounded, text: emptyMessage);
    }
    ref.watch(favoriteMetasProvider);
    final favorites = ref.read(favoriteMetasProvider.notifier);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        childAspectRatio: 0.95,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _ChannelCard(
        meta: items[i],
        favorite: favorites.isFavorite(items[i]),
        onTap: () => _openChannel(context, items[i]),
        onToggleFavorite: () => favorites.toggle(items[i]),
      ),
    );
  }
}

/// Loads the channel's streams; plays the only one directly, or lets the
/// user choose when there are several.
Future<void> _openChannel(BuildContext context, StremioMeta meta) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    builder: (_) => _StreamsSheet(meta: meta),
  );
}

class _StreamsSheet extends ConsumerStatefulWidget {
  const _StreamsSheet({required this.meta});

  final StremioMeta meta;

  @override
  ConsumerState<_StreamsSheet> createState() => _StreamsSheetState();
}

class _StreamsSheetState extends ConsumerState<_StreamsSheet> {
  bool _autoPlayed = false;

  ({String type, String id}) get _item =>
      (type: widget.meta.type, id: widget.meta.id);

  Future<void> _play(StremioStream stream) async {
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    if (stream.isPlayableUrl) {
      navigator.pop();
      await router.push('/player', extra: {
        'filePath': stream.url!,
        'title': widget.meta.name,
        'isLive': true,
        'httpHeaders': stream.headers,
      });
      return;
    }
    final external = stream.externalUrl ??
        (stream.ytId != null
            ? 'https://www.youtube.com/watch?v=${stream.ytId}'
            : null);
    if (external != null) {
      navigator.pop();
      await launchUrl(Uri.parse(external),
          mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final streamsAsync = ref.watch(itemStreamsProvider(_item));
    final streams = (streamsAsync.value ?? const [])
        .where((s) =>
            s.isPlayableUrl || s.externalUrl != null || s.ytId != null)
        .toList();

    // A single stream: no point in asking.
    if (streamsAsync.hasValue && streams.length == 1 && !_autoPlayed) {
      _autoPlayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play(streams.single);
      });
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                widget.meta.name,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: streamsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                ),
                error: (_, _) => const _Message(
                  icon: Icons.cloud_off_rounded,
                  text: 'No se han podido cargar las emisiones.',
                ),
                data: (_) => streams.isEmpty
                    ? const _Message(
                        icon: Icons.signal_wifi_off_rounded,
                        text: 'Este canal no tiene emisiones ahora mismo.',
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: streams.length,
                        itemBuilder: (_, i) {
                          final s = streams[i];
                          return ListTile(
                            leading: Icon(
                              s.isPlayableUrl
                                  ? Icons.play_circle_outline_rounded
                                  : Icons.open_in_new_rounded,
                              color: AppTheme.primary,
                            ),
                            title: Text(
                              s.label.isEmpty ? 'Emisión ${i + 1}' : s.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              s.addonName,
                              style: const TextStyle(
                                color: AppTheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => _play(s),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.meta,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final StremioMeta meta;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final initials = Center(
      child: Text(
        meta.name.characters.take(3).toString().toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final image = meta.imageUrl;
    return Material(
      color: AppTheme.cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF222233)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: image == null
                        ? initials
                        : Image.network(
                            image,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => initials,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Text(
                    meta.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: favorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
                iconSize: 20,
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: favorite ? Colors.amber : AppTheme.onSurfaceVariant,
                ),
                onPressed: onToggleFavorite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when no installed addon offers TV catalogs.
class _NoTvAddons extends StatelessWidget {
  const _NoTvAddons();

  @override
  Widget build(BuildContext context) {
    return _Message(
      icon: Icons.live_tv_rounded,
      text: 'Añade un addon de Stremio con canales de TV para verlos aquí.\n'
          'Se gestionan en Ajustes › Addons de Stremio.',
      action: FilledButton.icon(
        onPressed: () => showInstallAddonDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir addon'),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // A scrollable so pull-to-refresh still works when empty.
    return ListView(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(icon, size: 56, color: AppTheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.onSurface, fontSize: 15),
        ),
        if (action != null) ...[
          const SizedBox(height: 20),
          Center(child: action),
        ],
      ],
    );
  }
}
