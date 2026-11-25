import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/update_service.dart';

/// "Buscar actualizaciones" in Ajustes › Acerca de: asks GitHub for the
/// latest release and offers to download it.
class UpdateCheckTile extends StatefulWidget {
  const UpdateCheckTile({super.key, this.service});

  /// For tests; a real [UpdateService] otherwise.
  final UpdateService? service;

  @override
  State<UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<UpdateCheckTile> {
  bool _checking = false;

  /// What the last check found, shown under the title.
  String _status = 'Comprueba si hay una versión nueva';

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = 'Buscando…';
    });
    try {
      final update = await (widget.service ?? UpdateService()).check();
      if (!mounted) return;
      if (update == null) {
        setState(
          () =>
              _status = 'Tienes la última versión (${AppConstants.appVersion})',
        );
      } else {
        setState(() => _status = 'Versión ${update.version} disponible');
        await _showUpdate(update);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'No se ha podido comprobar. Revisa la conexión a internet.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _showUpdate(AppUpdate update) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.system_update_rounded,
          color: AppTheme.primary,
          size: 36,
        ),
        title: Text('BitDrix ${update.version} disponible'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tienes la versión ${AppConstants.appVersion}.',
                style: const TextStyle(color: AppTheme.onSurfaceVariant),
              ),
              if (update.notes?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                const Text(
                  'Novedades',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    child: Text(
                      update.notes!,
                      style: const TextStyle(height: 1.45),
                    ),
                  ),
                ),
              ],
              if (update.downloadName != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Se descargará ${update.downloadName}.',
                  style: const TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ahora no'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              launchUrl(
                Uri.parse(update.downloadUrl ?? update.pageUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(Icons.download_rounded),
            label: Text(
              update.downloadUrl != null ? 'Descargar' : 'Ver en GitHub',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: _checking ? null : _check,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.primary.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _checking
            ? const Padding(
                padding: EdgeInsets.all(9),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              )
            : const Icon(
                Icons.system_update_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
      ),
      title: const Text(
        'Buscar actualizaciones',
        style: TextStyle(
          color: AppTheme.onBackground,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _status,
        style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.onSurfaceVariant,
      ),
    );
  }
}
