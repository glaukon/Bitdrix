import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'addons_section.dart';
import 'update_check_tile.dart';

import '../../widgets/tmdb_key_dialog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_size_formatter.dart';
import '../../../data/models/app_language.dart';
import '../../providers/settings_providers.dart';
import '../../providers/torrent_providers.dart';

/// Ajustes, opened from the gear in [HomeScreen]'s top bar.
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final torrents = ref.watch(torrentsProvider);
    final cacheBytes = torrents.fold<int>(0, (sum, t) => sum + t.downloadedSize);
    final currentLang = ref.watch(languagePreferenceProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 4),
        _buildAppInfo(),
        const SizedBox(height: 20),
        _buildSection(
          title: 'Preferencias',
          children: [
            _LanguageTile(
              current: currentLang,
              onTap: () => _showLanguagePicker(context, ref),
            ),
            InkWell(
              onTap: () => _showSubtitleModePicker(context, ref),
              child: _SettingsTile(
                icon: Icons.subtitles_rounded,
                title: 'Subtítulos',
                subtitle: switch (ref.watch(subtitleModeProvider)) {
                  SubtitleMode.auto =>
                    'Automáticos: forzados con audio en castellano, completos si no lo hay',
                  SubtitleMode.off => 'Desactivados',
                  SubtitleMode.always => 'Siempre en castellano',
                },
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
            InkWell(
              onTap: () => showTmdbKeyDialog(context, ref),
              child: _SettingsTile(
                icon: Icons.vpn_key_rounded,
                title: 'Clave de API de TMDB',
                subtitle: ref.watch(tmdbApiKeyProvider).isEmpty
                    ? 'Sin configurar: necesaria para Cine y Series'
                    : 'Configurada',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const AddonsSection(),
        const SizedBox(height: 20),
        _buildSection(
          title: 'Almacenamiento',
          children: [
            InkWell(
              onTap: torrents.isEmpty ? null : () => _freeSpace(context, ref),
              child: _SettingsTile(
                icon: Icons.cleaning_services_rounded,
                title: 'Liberar espacio',
                subtitle: torrents.isEmpty
                    ? 'No hay vídeos guardados'
                    : 'Borra los vídeos guardados para ver al momento '
                        '(${FileSizeFormatter.format(cacheBytes)}). Los de '
                        'más de 7 días se borran solos.',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: 'Acerca de',
          children: [
            const _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'Versión',
              subtitle: AppConstants.appVersion,
              trailing: Text(
                AppConstants.appVersion,
                style: TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
            const UpdateCheckTile(),
            const _SettingsTile(
              icon: Icons.code_rounded,
              title: 'Hecho con Flutter',
              subtitle: 'Flutter · media_kit · addons de Stremio',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _freeSpace(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Liberar espacio?'),
        content: const Text(
          'Se borrarán los vídeos guardados. Lo que estés viendo se '
          'volverá a cargar la próxima vez que lo abras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(torrentsProvider.notifier).removeEverything();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Espacio liberado.')),
      );
    }
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LanguagePickerSheet(
        current: ref.read(languagePreferenceProvider),
        onSelected: (lang) {
          ref.read(languagePreferenceProvider.notifier).setLanguage(lang);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _showSubtitleModePicker(
      BuildContext context, WidgetRef ref) async {
    final current = ref.read(subtitleModeProvider);
    final picked = await showDialog<SubtitleMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Subtítulos'),
        children: [
          for (final mode in SubtitleMode.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, mode),
              child: Row(
                children: [
                  Icon(
                    mode == current
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(mode.label),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(subtitleModeProvider.notifier).set(picked);
    }
  }

  Widget _buildAppInfo() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(77),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.downloading_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            AppConstants.appName,
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cliente de torrents moderno',
            style: TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        // A Material (not a decorated Container) so the ListTiles inside can
        // paint their ink splashes on it.
        Material(
          color: AppTheme.cardColor,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF222233)),
          ),
          child: Column(
            children: children
                .expand((w) => [
                      w,
                      if (w != children.last)
                        const Divider(
                          height: 1,
                          indent: 52,
                          color: Color(0xFF222233),
                        ),
                    ])
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ── Language tile ─────────────────────────────────────────────────────────────

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.current, required this.onTap});

  final AppLanguage current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.primary.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.language_rounded,
            color: AppTheme.primary, size: 18),
      ),
      title: const Text(
        'Idioma preferido',
        style: TextStyle(
          color: AppTheme.onBackground,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: const Text(
        'Prioriza las fuentes en este idioma',
        style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            current.name,
            style: const TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

// ── Language picker bottom sheet ──────────────────────────────────────────────

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({
    required this.current,
    required this.onSelected,
  });

  final AppLanguage current;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.onSurfaceVariant.withAlpha(102),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(
            'Idioma preferido',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Divider(height: 1),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kAppLanguages.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFF222233),
          ),
          itemBuilder: (_, i) {
            final lang = kAppLanguages[i];
            final isSelected = lang.code == current.code;
            return ListTile(
              onTap: () => onSelected(lang),
              leading: Icon(
                Icons.language_rounded,
                color:
                    isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
                size: 20,
              ),
              title: Text(
                lang.name,
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.onBackground,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: AppTheme.primary, size: 20)
                  : null,
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Settings tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.primary.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.onBackground,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: trailing,
    );
  }
}
