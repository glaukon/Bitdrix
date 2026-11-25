import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../files/files_screen.dart';
import '../torrent_list/torrent_list_screen.dart';

/// The Descargas tab: the torrent list and the downloaded files, as two
/// sub-tabs.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: AppTheme.primary,
            indicatorColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.onSurfaceVariant,
            tabs: [
              Tab(icon: Icon(Icons.downloading_rounded), text: 'Torrents'),
              Tab(icon: Icon(Icons.folder_rounded), text: 'Archivos'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                TorrentListScreen(),
                FilesScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
