import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      message: 'Adding torrent...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Torrent'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.link_rounded, size: 18),
                text: 'Magnet Link',
              ),
              Tab(
                icon: Icon(Icons.file_open_rounded, size: 18),
                text: 'Torrent File',
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
            'Paste your magnet link below',
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
            label: const Text('Add Magnet'),
          ),
          const SizedBox(height: 16),
          _buildSampleMagnetHint(),
        ],
      ),
    );
  }

  Widget _buildSampleMagnetHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333348)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppTheme.accent, size: 16),
              SizedBox(width: 6),
              Text(
                'Demo tip',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'In demo mode any magnet link is accepted. Paste any text '
            'starting with "magnet:?" to simulate a download.',
            style: TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _magnetController.text =
                'magnet:?xt=urn:btih:DEMO0000000000000000000000000000000000000'
                '&dn=Big+Buck+Bunny+1080p&tr=udp://tracker.example.com:1337',
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Tap to fill demo magnet',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
            'Select a .torrent file from your device',
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
                        ? _selectedFilePath!.split('/').last.split('\\').last
                        : 'Tap to browse .torrent files',
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
                      '.torrent files only',
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
              label: const Text('Add Torrent File'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() {
                _selectedFilePath = null;
                _errorMessage = null;
              }),
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Clear selection'),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Browse Files'),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() => _errorMessage = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['torrent'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() => _selectedFilePath = result.files.single.path);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not open file picker: $e');
    }
  }

  Future<void> _addMagnet() async {
    final link = _magnetController.text.trim();
    if (link.isEmpty) {
      setState(() => _errorMessage = 'Please enter a magnet link.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(torrentsProvider.notifier).addMagnet(link);
      if (mounted) {
        _showSuccess('Torrent added successfully!');
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
        _showSuccess('Torrent file added!');
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
