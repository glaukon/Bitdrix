import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/tmdb_constants.dart';
import '../../core/theme/app_theme.dart';
import '../providers/settings_providers.dart';

/// Lets the user paste their TMDB API key (v3) or Read Access Token (v4).
Future<void> showTmdbKeyDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController(text: ref.read(tmdbApiKeyProvider));
  final saved = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Clave de API de TMDB'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Descubrir usa The Movie Database. Pega tu clave de API o '
            'token de acceso de lectura desde:',
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const SelectableText(
            TmdbConstants.apiSettingsUrl,
            style: TextStyle(color: AppTheme.primary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Clave de API o token',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.pop(ctx, value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (saved != null) {
    await ref.read(tmdbApiKeyProvider.notifier).setKey(saved);
  }
}
