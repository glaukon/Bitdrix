import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/media_model.dart';
import '../providers/discover_providers.dart';
import '../screens/discover/widgets/media_card.dart';
import 'horizontal_scroller.dart';

/// Width of a poster card in the horizontal rows.
const double kRowCardWidth = 140;

/// A row's title, shared by every horizontal row of the app.
class RowTitle extends StatelessWidget {
  const RowTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A titled, horizontally scrolling row of posters; [items] null shows a
/// spinner while they load.
class MediaRow extends StatelessWidget {
  const MediaRow({super.key, required this.title, required this.items});

  final String title;
  final List<MediaModel>? items;

  static const posterHeight = kRowCardWidth * 3 / 2;

  @override
  Widget build(BuildContext context) {
    final items = this.items;
    // Room for a two-line title, at whatever text size the page uses.
    final rowHeight =
        posterHeight + MediaQuery.textScalerOf(context).scale(44);
    if (items != null && items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RowTitle(title),
        items == null
            ? SizedBox(
                height: rowHeight,
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              )
            : HorizontalScroller(
                height: rowHeight,
                spacing: 12,
                itemCount: items.length,
                itemBuilder: (_, i) => SizedBox(
                  width: kRowCardWidth,
                  child: MediaCard(media: items[i]),
                ),
              ),
      ],
    );
  }
}

/// A [MediaRow] filled from one of TMDB's lists. Rows that fail or come back
/// empty are left out.
class CatalogListRow extends ConsumerWidget {
  const CatalogListRow({super.key, required this.list, this.title});

  final CatalogList list;

  /// Overrides the list's own title (e.g. "Tendencias en cine" on Inicio).
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(catalogListProvider(list));
    if (async.hasError) return const SizedBox.shrink();
    return MediaRow(title: title ?? list.title, items: async.value);
  }
}

/// The top trending title, large, with its backdrop and synopsis.
class FeaturedBanner extends StatelessWidget {
  const FeaturedBanner({super.key, required this.media});

  final MediaModel media;

  @override
  Widget build(BuildContext context) {
    void open() => context.push('/discover/${media.id}', extra: media);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: AppTheme.cardColor,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    media.backdropUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xF00A0A12), Color(0x000A0A12)],
                        stops: [0.0, 0.75],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'DESTACADO HOY',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FractionallySizedBox(
                          widthFactor: 0.6,
                          child: Text(
                            media.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (media.overview?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: 0.6,
                            child: Text(
                              media.overview!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: open,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Ver fuentes'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

