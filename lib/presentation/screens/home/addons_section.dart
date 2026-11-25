import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/stremio_addon.dart';
import '../../providers/addon_providers.dart';

/// Settings section listing the installed Stremio addons, with install and
/// uninstall.
class AddonsSection extends ConsumerWidget {
  const AddonsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addons = ref.watch(installedAddonsProvider).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'ADDONS DE STREMIO',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Material(
          color: AppTheme.cardColor,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF222233)),
          ),
          child: Column(
            children: [
              for (final addon in addons) ...[
                _AddonTile(addon: addon),
                const Divider(height: 1, indent: 52, color: Color(0xFF222233)),
              ],
              ListTile(
                onTap: () => showInstallAddonDialog(context),
                leading: const Icon(Icons.add_circle_outline_rounded,
                    color: AppTheme.primary),
                title: const Text(
                  'Añadir addon',
                  style: TextStyle(
                    color: AppTheme.onBackground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Pega la URL de su manifest.json',
                  style: TextStyle(color: AppTheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddonTile extends ConsumerWidget {
  const _AddonTile({required this.addon});

  final StremioAddon addon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tvCatalogs =
        addon.catalogs.where((c) => tvTypes.contains(c.type)).length;
    final details = [
      if (addon.version.isNotEmpty) 'v${addon.version}',
      if (tvCatalogs > 0) '$tvCatalogs catálogos de TV',
      if (addon.resources.any((r) => r.name == 'stream')) 'fuentes',
    ].join(' · ');

    return ListTile(
      leading: SizedBox(
        width: 36,
        height: 36,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: addon.logoUrl == null
              ? const ColoredBox(
                  color: AppTheme.surfaceVariant,
                  child: Icon(Icons.extension_rounded,
                      color: AppTheme.primary, size: 20),
                )
              : Image.network(
                  addon.logoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.extension_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
        ),
      ),
      title: Text(
        addon.name,
        style: const TextStyle(
          color: AppTheme.onBackground,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        details,
        style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: IconButton(
        tooltip: 'Quitar addon',
        icon: const Icon(Icons.delete_outline_rounded),
        color: AppTheme.onSurfaceVariant,
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('¿Quitar ${addon.name}?'),
              content: const Text(
                  'Dejarán de aparecer sus canales y fuentes. Puedes volver '
                  'a añadirlo cuando quieras.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Quitar'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await ref
                .read(installedAddonsProvider.notifier)
                .remove(addon.manifestUrl);
          }
        },
      ),
    );
  }
}

/// Asks for an addon URL and installs it.
Future<void> showInstallAddonDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _InstallAddonDialog(),
  );
}

class _InstallAddonDialog extends ConsumerStatefulWidget {
  const _InstallAddonDialog();

  @override
  ConsumerState<_InstallAddonDialog> createState() =>
      _InstallAddonDialogState();
}

class _InstallAddonDialogState extends ConsumerState<_InstallAddonDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final addon = await ref
          .read(installedAddonsProvider.notifier)
          .install(_controller.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${addon.name} añadido.')),
      );
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error =
          'No se ha podido conectar con el addon. Revisa la dirección.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir addon de Stremio'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pega la dirección del manifiesto del addon. Sirven también los '
              'enlaces stremio:// de "Instalar".',
              style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_busy,
              onSubmitted: (_) => _install(),
              decoration: InputDecoration(
                hintText: 'https://…/manifest.json',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _install,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Añadir'),
        ),
      ],
    );
  }
}
