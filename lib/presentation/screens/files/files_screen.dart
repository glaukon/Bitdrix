import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_size_formatter.dart';
import '../../../domain/entities/torrent_entity.dart';
import '../../../domain/entities/torrent_file_entity.dart';
import '../../providers/torrent_providers.dart';
import '../../widgets/empty_state.dart';

class FilesScreen extends ConsumerWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(completedTorrentsProvider);

    if (completed.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open_rounded,
        title: 'No hay descargas completadas',
        subtitle:
            'Aquí aparecerán los torrents terminados. Empieza una descarga para ver tus archivos.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: completed.length,
      itemBuilder: (ctx, i) => _TorrentFolder(torrent: completed[i]),
    );
  }
}

class _TorrentFolder extends StatefulWidget {
  const _TorrentFolder({required this.torrent});
  final TorrentEntity torrent;

  @override
  State<_TorrentFolder> createState() => _TorrentFolderState();
}

class _TorrentFolderState extends State<_TorrentFolder> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // A Material (not a decorated Container) so the file ListTiles can paint
    // their ink on it.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: AppTheme.cardColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF222233)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            if (_expanded) _buildFileList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.success.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.folder_rounded,
                color: AppTheme.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.torrent.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.torrent.files.length} archivo(s) · '
                    '${FileSizeFormatter.format(widget.torrent.totalSize)}',
                    style: const TextStyle(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: AppTheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return Column(
      children: [
        const Divider(
          height: 1,
          color: Color(0xFF222233),
          indent: 14,
          endIndent: 14,
        ),
        ...widget.torrent.files.map((file) => _FileItem(
              file: file,
              torrentName: widget.torrent.name,
            )),
      ],
    );
  }
}

class _FileItem extends StatelessWidget {
  const _FileItem({required this.file, required this.torrentName});
  final TorrentFileEntity file;
  final String torrentName;

  @override
  Widget build(BuildContext context) {
    final isVideo = AppConstants.videoExtensions.contains(file.extension);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isVideo ? Icons.movie_outlined : Icons.insert_drive_file_outlined,
          color: isVideo ? AppTheme.accent : AppTheme.onSurfaceVariant,
          size: 18,
        ),
      ),
      title: Text(
        file.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.onBackground,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        FileSizeFormatter.format(file.size),
        style: const TextStyle(
          color: AppTheme.onSurfaceVariant,
          fontSize: 11,
        ),
      ),
      trailing: isVideo
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
              onPressed: () => context.push(
                '/player',
                extra: {'filePath': file.path, 'title': file.name},
              ),
            )
          : null,
    );
  }
}
