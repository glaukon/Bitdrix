import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/media_model.dart';

/// A poster-format card representing a movie or TV show.
///
/// Aspect ratio is 2:3 (portrait). Shows:
/// - Poster image with loading/error placeholder
/// - Title below the poster
/// - Year badge overlay (bottom-left)
/// - Media type badge (top-right)
class MediaCard extends StatelessWidget {
  const MediaCard({super.key, required this.media});

  final MediaModel media;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/discover/${media.id}', extra: media);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PosterImage(media: media),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              media.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.media});

  final MediaModel media;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster
            _buildPoster(),

            // Gradient scrim for overlays
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 56,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Year badge — bottom-left
            if (media.displayYear != null)
              Positioned(
                bottom: 6,
                left: 6,
                child: _Badge(
                  text: media.displayYear!,
                  color: AppTheme.surface.withAlpha(200),
                  textColor: AppTheme.onSurface,
                ),
              ),

            // Media type badge — top-right
            Positioned(
              top: 6,
              right: 6,
              child: _Badge(
                text: media.mediaType == 'tv' ? 'TV' : 'Película',
                color: media.mediaType == 'tv'
                    ? AppTheme.accent.withAlpha(200)
                    : AppTheme.primary.withAlpha(200),
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoster() {
    final url = media.posterUrl;

    if (url == null) {
      return _Placeholder(title: media.displayTitle);
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const _LoadingPlaceholder();
      },
      errorBuilder: (_, _, _) => _Placeholder(title: media.displayTitle),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceVariant,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceVariant,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: AppTheme.onSurfaceVariant,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
