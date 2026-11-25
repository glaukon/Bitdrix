import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/stremio_addon.dart';
import '../providers/addon_providers.dart';

/// Loads the channel's streams; plays the only one directly, or lets the
/// user choose when there are several.
Future<void> openChannel(BuildContext context, StremioMeta meta) async {
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

class ChannelCard extends StatelessWidget {
  const ChannelCard({
    super.key,
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


/// A centred icon and message (with an optional action); scrollable so
/// pull-to-refresh still works on an empty list.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(32),
      children: [
        Icon(icon, size: 48, color: AppTheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.onSurface, fontSize: 15),
        ),
      ],
    );
  }
}
