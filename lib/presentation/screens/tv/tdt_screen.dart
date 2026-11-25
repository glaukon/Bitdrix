import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/tv_channel.dart';
import '../../providers/tv_providers.dart';
import '../../widgets/horizontal_scroller.dart';
import '../../widgets/selectable_chip.dart';

/// NOT WIRED IN (kept while the addon-based TV tab is tried out).
/// Live TV: Spain's free official channels from TDTChannels, by category,
/// with the user's region and favourites.
class TdtScreen extends ConsumerStatefulWidget {
  const TdtScreen({super.key});

  @override
  ConsumerState<TdtScreen> createState() => _TvScreenState();
}

/// What the channel grid shows.
sealed class _TvView {
  const _TvView();
}

class _FavoritesView extends _TvView {
  const _FavoritesView();
}

class _GroupView extends _TvView {
  const _GroupView(this.name);
  final String name;
}

/// The chosen autonomous community.
class _RegionView extends _TvView {
  const _RegionView();
}

class _TvScreenState extends ConsumerState<TdtScreen> {
  final _search = TextEditingController();
  _TvView? _view;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickRegion(List<TvChannelGroup> regions) async {
    final current = ref.read(tvRegionProvider);
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Tu comunidad',
                style: TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final r in regions)
              ListTile(
                title: Text(r.name),
                subtitle: Text('${r.channels.length} canales'),
                trailing: r.name == current
                    ? const Icon(Icons.check_rounded, color: AppTheme.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(r.name),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(tvRegionProvider.notifier).set(picked);
    setState(() => _view = const _RegionView());
  }

  Future<void> _open(TvChannel channel) async {
    if (channel.kind != TvChannelKind.playable) {
      final opened = await launchUrl(
        Uri.parse(channel.externalUrl!),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido abrir el canal.')),
        );
      }
      return;
    }
    context.push('/player', extra: {
      'filePath': channel.streams.first,
      'title': channel.name,
      'isLive': true,
      'fallbackUrls': channel.streams.skip(1).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(tvGroupsProvider);
    return groupsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
      error: (_, _) => _TvError(onRetry: () => ref.invalidate(tvGroupsProvider)),
      data: _buildContent,
    );
  }

  Widget _buildContent(List<TvChannelGroup> groups) {
    final favorites = ref.watch(favoriteChannelsProvider);
    final region = ref.watch(tvRegionProvider);
    final national = groups.where((g) => !g.isRegion).toList();
    final regions = groups.where((g) => g.isRegion).toList();
    final allChannels = [for (final g in groups) ...g.channels];
    final favoriteChannels =
        allChannels.where((c) => favorites.contains(c.id)).toList();
    final regionGroup = regions.where((g) => g.name == region).firstOrNull;

    // Default view: favourites when there are any, else the main channels.
    final view = _view ??
        (favoriteChannels.isNotEmpty
            ? const _FavoritesView()
            : _GroupView(national.isNotEmpty ? national.first.name : ''));

    final query = _search.text.trim().toLowerCase();
    final List<TvChannel> channels;
    if (query.isNotEmpty) {
      channels = allChannels
          .where((c) => c.name.toLowerCase().contains(query))
          .toList();
    } else {
      channels = switch (view) {
        _FavoritesView() => favoriteChannels,
        _RegionView() => regionGroup?.channels ?? const [],
        _GroupView(:final name) =>
          groups.where((g) => g.name == name).firstOrNull?.channels ??
              const [],
      };
    }

    final chips = <Widget>[
      SelectableChip(
        selected: view is _FavoritesView,
        onSelected: (_) => setState(() => _view = const _FavoritesView()),
        avatar: const Icon(Icons.star_rounded, size: 18),
        label: 'Favoritos (${favoriteChannels.length})',
      ),
      for (final g in national)
        SelectableChip(
          selected: view is _GroupView && view.name == g.name,
          onSelected: (_) => setState(() => _view = _GroupView(g.name)),
          label: g.name,
        ),
      SelectableChip(
        selected: view is _RegionView,
        onSelected: (_) => regionGroup == null
            ? _pickRegion(regions)
            : setState(() => _view = const _RegionView()),
        avatar: const Icon(Icons.place_rounded, size: 18),
        label: regionGroup?.name ?? 'Mi comunidad',
      ),
    ];

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
        if (query.isEmpty)
          Row(
            children: [
              Expanded(
                child: HorizontalScroller(
                  height: 60,
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                  wheelScrollsSideways: true,
                  itemCount: chips.length,
                  itemBuilder: (_, i) => chips[i],
                ),
              ),
              if (view is _RegionView)
                IconButton(
                  tooltip: 'Cambiar de comunidad',
                  icon: const Icon(Icons.edit_location_alt_rounded),
                  color: AppTheme.onSurfaceVariant,
                  onPressed: () => _pickRegion(regions),
                ),
              const SizedBox(width: 8),
            ],
          ),
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            onRefresh: () => ref.refresh(tvGroupsProvider.future),
            child: channels.isEmpty
                ? _EmptyChannels(
                    message: query.isNotEmpty
                        ? 'Ningún canal se llama así.'
                        : view is _FavoritesView
                            ? 'Marca canales con la estrella para tenerlos aquí.'
                            : 'No hay canales disponibles.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 170,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (_, i) => _ChannelCard(
                      channel: channels[i],
                      favorite: favorites.contains(channels[i].id),
                      onTap: () => _open(channels[i]),
                      onToggleFavorite: () => ref
                          .read(favoriteChannelsProvider.notifier)
                          .toggle(channels[i].id),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.channel,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final TvChannel channel;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
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
                    child: _ChannelLogo(channel: channel),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Text(
                    channel.name,
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
            if (channel.kind != TvChannelKind.playable)
              Positioned(
                top: 8,
                left: 8,
                child: _ExternalBadge(kind: channel.kind),
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

/// Marks a channel that opens outside the app, and where.
class _ExternalBadge extends StatelessWidget {
  const _ExternalBadge({required this.kind});

  final TvChannelKind kind;

  @override
  Widget build(BuildContext context) {
    final youtube = kind == TvChannelKind.youtube;
    final color = youtube ? const Color(0xFFFF4E45) : AppTheme.onSurfaceVariant;
    return Tooltip(
      message: youtube ? 'Se abre en YouTube' : 'Se abre en la web de la cadena',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(140)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new_rounded, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              youtube ? 'YouTube' : 'Web',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.channel});

  final TvChannel channel;

  @override
  Widget build(BuildContext context) {
    final initials = Center(
      child: Text(
        channel.name.characters.take(3).toString().toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final logo = channel.logoUrl;
    if (logo == null) return initials;
    return Image.network(
      logo,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => initials,
    );
  }
}

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    // A scrollable so pull-to-refresh still works on an empty list.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.live_tv_rounded,
            size: 56, color: AppTheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.onSurface, fontSize: 15),
        ),
      ],
    );
  }
}

class _TvError extends StatelessWidget {
  const _TvError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 56, color: AppTheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text(
            'No se ha podido cargar la lista de canales.',
            style: TextStyle(color: AppTheme.onSurface, fontSize: 15),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
