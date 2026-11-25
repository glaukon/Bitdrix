import 'dart:convert';
import 'dart:io';


import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/torrent_providers.dart';
import '../../widgets/loading_overlay.dart';

class AddTorrentScreen extends ConsumerStatefulWidget {
  const AddTorrentScreen({super.key});

  @override
  ConsumerState<AddTorrentScreen> createState() => _AddTorrentScreenState();
}

class _AddTorrentScreenState extends ConsumerState<AddTorrentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _magnetController = TextEditingController();
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _magnetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Añadiendo torrent...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Añadir torrent'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.link_rounded, size: 18),
                text: 'Enlace magnet',
              ),
              Tab(
                icon: Icon(Icons.file_open_rounded, size: 18),
                text: 'Archivo torrent',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMagnetTab(),
            _buildFileTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMagnetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Pega tu enlace magnet aquí',
            style: TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _magnetController,
            maxLines: 4,
            minLines: 4,
            style: const TextStyle(
              color: AppTheme.onBackground,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            decoration: const InputDecoration(
              hintText: 'magnet:?xt=urn:btih:...',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 56),
                child: Icon(Icons.link_rounded, color: AppTheme.primary),
              ),
            ),
            onChanged: (_) {
              if (_errorMessage != null) {
                setState(() => _errorMessage = null);
              }
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addMagnet,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Añadir magnet'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Elige un archivo .torrent de tu dispositivo',
            style: TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedFilePath != null
                      ? AppTheme.primary
                      : const Color(0xFF333348),
                  width: _selectedFilePath != null ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFilePath != null
                        ? Icons.check_circle_outline_rounded
                        : Icons.upload_file_rounded,
                    color: _selectedFilePath != null
                        ? AppTheme.success
                        : AppTheme.onSurfaceVariant,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFilePath != null
                        ? (_selectedFileName ??
                            _selectedFilePath!.split('/').last.split('\\').last)
                        : 'Toca para buscar archivos .torrent',
                    style: TextStyle(
                      color: _selectedFilePath != null
                          ? AppTheme.onBackground
                          : AppTheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: _selectedFilePath != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedFilePath == null) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Solo archivos .torrent',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_selectedFilePath != null) ...[
            ElevatedButton.icon(
              onPressed: _addFile,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir archivo torrent'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() {
                _selectedFilePath = null;
                _selectedFileName = null;
                _errorMessage = null;
              }),
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Quitar selección'),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Buscar archivos'),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() => _errorMessage = null);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['torrent'],
      );
      if (picked == null) return;
      final String path;
      if (kIsWeb) {
        // The browser exposes no file paths, only the bytes.
        path = 'data:application/x-bittorrent;'
            'name=${Uri.encodeComponent(picked.name)};'
            'base64,${base64Encode(await picked.readAsBytes())}';
      } else if (picked.path != null) {
        path = picked.path!;
      } else {
        // Android may hand back a content:// URI with no file path: copy the
        // bytes to a temporary file the engine can open.
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}${Platform.pathSeparator}${picked.name}');
        await file.writeAsBytes(await picked.readAsBytes());
        path = file.path;
      }
      setState(() {
        _selectedFileName = picked.name;
        _selectedFilePath = path;
      });
    } catch (e) {
      setState(() => _errorMessage = 'No se ha podido abrir el selector de archivos: $e');
    }
  }

  Future<void> _addMagnet() async {
    final link = _magnetController.text.trim();
    if (link.isEmpty) {
      setState(() => _errorMessage = 'Introduce un enlace magnet.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(torrentsProvider.notifier).addMagnet(link);
      if (mounted) {
        _showSuccess('¡Torrent añadido!');
        context.pop();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addFile() async {
    if (_selectedFilePath == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(torrentsProvider.notifier)
          .addTorrentFile(_selectedFilePath!);
      if (mounted) {
        _showSuccess('¡Archivo torrent añadido!');
        context.pop();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.success, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
