import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/catalog_labels.dart';
import '../../../core/utils/genre_labels.dart';
import '../../../data/models/stremio_addon.dart';
import '../../providers/addon_providers.dart';
import '../../widgets/channel_widgets.dart';
import '../../widgets/horizontal_scroller.dart';
import '../../widgets/selectable_chip.dart';
import '../home/addons_section.dart';

/// Live TV from the user's Stremio addons: a tab per addon (plus
/// Favoritos), then that addon's catalogs and their categories.
class TvScreen extends ConsumerStatefulWidget {
  const TvScreen({super.key});

  @override
  ConsumerState<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends ConsumerState<TvScreen> {
  final _search = TextEditingController();

  /// Selected addon tab, by manifest URL; null is the Favoritos tab.
  String? _addonUrl;

  /// Selected catalog of that addon, by `type|id`.
  String? _catalogKey;

  /// Category of the selected catalog; null shows all of them.
  String? _genre;

  bool _initialized = false;

  static String _catalogKeyOf(StremioCatalog c) => '${c.type}|${c.id}';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _selectAddon(String? url) => setState(() {
        if (_addonUrl != url) {
          _catalogKey = null;
          _genre = null;
        }
        _addonUrl = url;
      });

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

    // Addons with TV catalogs, in install order, each with its catalogs.
    final byAddon = <String, List<AddonCatalog>>{};
    for (final c in catalogs) {
      byAddon.putIfAbsent(c.addon.manifestUrl, () => []).add(c);
    }
    final addons = [for (final list in byAddon.values) list.first.addon];

    // First visit: favourites if any, else the first addon. A removed addon
    // falls back the same way.
    if (!_initialized ||
        (_addonUrl != null && !byAddon.containsKey(_addonUrl))) {
      _initialized = true;
      _addonUrl = favorites.isNotEmpty ? null : addons.first.manifestUrl;
      _catalogKey = null;
      _genre = null;
    }

    final addonCatalogs = _addonUrl == null ? null : byAddon[_addonUrl]!;
    final source = addonCatalogs == null
        ? null
        : addonCatalogs
                .where((c) => _catalogKeyOf(c.catalog) == _catalogKey)
                .firstOrNull ??
            addonCatalogs.first;
    final query = _search.text.trim().toLowerCase();

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
        _AddonTabs(
          addons: addons,
          selected: _addonUrl,
          favoritesCount: favorites.length,
          onSelected: _selectAddon,
        ),
        if (source != null && addonCatalogs!.length > 1)
          HorizontalScroller(
            height: 56,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            wheelScrollsSideways: true,
            showScrollbar: false,
            itemCount: addonCatalogs.length,
            itemBuilder: (_, i) {
              final c = addonCatalogs[i];
              return SelectableChip(
                selected: identical(c, source),
                onSelected: (_) => setState(() {
                  _catalogKey = _catalogKeyOf(c.catalog);
                  _genre = null;
                }),
                label: catalogLabel(c.catalog.name, c.addon.name),
              );
            },
          ),
        if (source != null && source.catalog.filterGenres.isNotEmpty)
          _GenreBar(
            genres: source.catalog.filterGenres,
            selected: _genre,
            onSelected: (g) => setState(() => _genre = g),
          ),
        const SizedBox(height: 4),
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

/// One tab per addon with TV catalogs, plus Favoritos at the end.
class _AddonTabs extends StatelessWidget {
  const _AddonTabs({
    required this.addons,
    required this.selected,
    required this.favoritesCount,
    required this.onSelected,
  });

  final List<StremioAddon> addons;

  /// Manifest URL of the selected addon; null for Favoritos.
  final String? selected;
  final int favoritesCount;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final tabs = <({String? url, String label, Widget? icon})>[
      for (final a in addons)
        (
          url: a.manifestUrl,
          label: addonLabel(a.name),
          icon: a.logoUrl == null
              ? null
              : ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    a.logoUrl!,
                    width: 18,
                    height: 18,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
        ),
      (
        url: null,
        label: 'Favoritos ($favoritesCount)',
        icon: const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF222233))),
      ),
      child: HorizontalScroller(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        spacing: 0,
        wheelScrollsSideways: true,
        showScrollbar: false,
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final tab = tabs[i];
          final active = tab.url == selected;
          return InkWell(
            onTap: () => onSelected(tab.url),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? AppTheme.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tab.icon != null) ...[tab.icon!, const SizedBox(width: 8)],
                  Text(
                    tab.label,
                    style: TextStyle(
                      color: active
                          ? AppTheme.onBackground
                          : AppTheme.onSurfaceVariant,
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
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
      height: 56,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
    final layout = channelLayoutFor(items);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: channelGridDelegate(layout),
      itemCount: items.length,
      itemBuilder: (_, i) => ChannelCard(
        layout: layout,
        meta: items[i],
        favorite: favorites.isFavorite(items[i]),
        onTap: () => openChannel(context, items[i]),
        onToggleFavorite: () => favorites.toggle(items[i]),
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
