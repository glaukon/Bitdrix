import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_size_formatter.dart';
import '../../../data/models/app_language.dart';
import '../../../domain/entities/torrent_file_entity.dart';
import '../../../domain/entities/torrent_entity.dart';
import '../../providers/settings_providers.dart';
import '../../providers/torrent_providers.dart';

/// Full-screen video player with optional streaming-mode support.
///
/// media_kit is used instead of video_player so MKV files can expose selectable
/// audio & subtitle tracks from Dart.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.filePath,
    required this.title,
    this.torrentId,
    this.selectedFileId,
  });

  final String filePath;
  final String title;
  final String? torrentId;
  final String? selectedFileId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _initialized = false;
  bool _initializingPlayer = false;
  bool _controlsVisible = true;
  bool _isFullscreen = false;
  double _playbackSpeed = 1.0;
  Timer? _hideControlsTimer;
  String? _error;

  static const double _bufferThreshold = 0.02;
  static const int _minBufferBytes = 1 * 1024 * 1024;

  bool get _isStreamingMode => widget.torrentId != null;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _listenToPlayer();

    if (!_isStreamingMode) {
      unawaited(_initPlayer(widget.filePath));
    }
  }

  void _listenToPlayer() {
    void repaint(_) {
      if (mounted) setState(() {});
    }

    _subscriptions.addAll([
      _player.stream.playing.listen(repaint),
      _player.stream.position.listen(repaint),
      _player.stream.duration.listen(repaint),
      _player.stream.buffering.listen(repaint),
      _player.stream.tracks.listen((_) {
        _applyPreferredAudioTrack();
        _disableSubtitlesByDefault();
        repaint(null);
      }),
      _player.stream.track.listen(repaint),
      _player.stream.width.listen(repaint),
      _player.stream.height.listen(repaint),
    ]);
  }

  Future<void> _initPlayer(String source) async {
    if (_initializingPlayer || _initialized) return;
    _initializingPlayer = true;
    try {
      final uri = _toMediaUri(source);
      await _player.open(Media(uri), play: true);
      await _player.setRate(_playbackSpeed);
      await _disableSubtitlesByDefault();

      if (mounted) setState(() => _initialized = true);
      _scheduleHideControls();
      unawaited(_applyPreferredAudioTrack());
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not play this file.\n$e');
    } finally {
      _initializingPlayer = false;
    }
  }

  String _toMediaUri(String source) {
    final uri = Uri.tryParse(source);
    if (uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'content' ||
            uri.scheme == 'file')) {
      return source;
    }
    if (source.startsWith('/')) {
      return Uri.file(source).toString();
    }
    return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/'
        'sample/BigBuckBunny.mp4';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    if (!_player.state.playing) return;
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHideControls();
  }

  Future<void> _seekRelative(Duration offset) async {
    await _seekTo(_player.state.position + offset);
  }

  Future<void> _seekTo(Duration target) async {
    final duration = _player.state.duration;
    final maxMs = duration.inMilliseconds;
    if (maxMs <= 0) return;
    final clampedMs = target.inMilliseconds.clamp(0, maxMs);
    await _player.seek(Duration(milliseconds: clampedMs));
    _scheduleHideControls();
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    setState(() => _isFullscreen = !_isFullscreen);
  }

  @override
  Widget build(BuildContext context) {
    final torrent = _isStreamingMode
        ? ref.watch(torrentByIdProvider(widget.torrentId!))
        : null;
    final selectedFile = _findSelectedFile(torrent);

    final downloadProgress = selectedFile?.progress ?? torrent?.progress ?? 0.0;
    final downloadedBytes = selectedFile?.bufferedSize ??
        selectedFile?.downloadedSize ??
        torrent?.downloadedSize ??
        0;
    final playableBytes = selectedFile?.contiguousDownloadedSize ??
        selectedFile?.downloadedSize ??
        torrent?.downloadedSize ??
        0;
    final requiredBufferBytes =
        selectedFile == null ? 0 : _requiredBufferBytes(selectedFile.size);
    final streamUrl = (torrent?.streamUrl?.isNotEmpty ?? false)
        ? torrent!.streamUrl
        : widget.filePath.isNotEmpty
            ? widget.filePath
            : null;

    if (_isStreamingMode &&
        !_initialized &&
        !_initializingPlayer &&
        _error == null &&
        streamUrl != null &&
        _hasEnoughBuffer(selectedFile, downloadProgress, playableBytes)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_initPlayer(streamUrl));
      });
    }

    final isBuffering = _error == null &&
        _isStreamingMode &&
        (streamUrl == null ||
            !_hasEnoughBuffer(selectedFile, downloadProgress, playableBytes));

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: isBuffering ? null : _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!isBuffering) _buildVideo(),
            if (isBuffering)
              _buildBufferingOverlay(
                downloadProgress,
                downloadedBytes,
                requiredBufferBytes,
              ),
            if (!isBuffering && _controlsVisible) _buildControlsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBufferingOverlay(
    double progress,
    int downloadedBytes,
    int requiredBufferBytes,
  ) {
    final torrent = _isStreamingMode
        ? ref.read(torrentByIdProvider(widget.torrentId!))
        : null;
    final hasStreamUrl = torrent?.streamUrl != null;
    final bufferFraction = requiredBufferBytes > 0
        ? (downloadedBytes / requiredBufferBytes).clamp(0.0, 1.0)
        : (progress / _bufferThreshold).clamp(0.0, 1.0);
    final bufferPct = (bufferFraction * 100).toStringAsFixed(0);
    final downloadPct = (progress * 100).toStringAsFixed(1);

    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: bufferFraction,
                  strokeWidth: 4,
                  backgroundColor: Colors.white12,
                  color: AppTheme.primary,
                ),
                const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white54,
                  size: 32,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            hasStreamUrl ? 'Buffering $bufferPct%' : 'Connecting to peers...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: bufferFraction,
                backgroundColor: Colors.white12,
                color: AppTheme.primary,
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _bufferingDetailText(
              hasStreamUrl: hasStreamUrl,
              downloadPct: downloadPct,
              downloadedBytes: downloadedBytes,
              requiredBufferBytes: requiredBufferBytes,
            ),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _bufferingDetailText({
    required bool hasStreamUrl,
    required String downloadPct,
    required int downloadedBytes,
    required int requiredBufferBytes,
  }) {
    if (!hasStreamUrl) return 'Searching for peers...';
    if (requiredBufferBytes <= 0) return 'Downloaded $downloadPct%';
    return 'Buffer ${FileSizeFormatter.format(downloadedBytes)} / '
        '${FileSizeFormatter.format(requiredBufferBytes)}';
  }

  Widget _buildVideo() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppTheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
        ),
      );
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Video(
            controller: _videoController,
            controls: null,
            fit: BoxFit.contain,
          ),
          if (_player.state.buffering)
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0, 0.25, 0.75, 1],
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          const Spacer(),
          if (_initialized) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<AudioTrack>> _audioTrackMenuItems() {
    final selected = _player.state.track.audio;
    final tracks = _player.state.tracks.audio;
    return tracks
        .map(
          (track) => PopupMenuItem<AudioTrack>(
            value: track,
            child: _TrackMenuItem(
              icon: Icons.volume_up_rounded,
              label: _audioTrackLabel(track),
              selected: track == selected,
            ),
          ),
        )
        .toList();
  }

  List<PopupMenuEntry<SubtitleTrack>> _subtitleTrackMenuItems() {
    final selected = _player.state.track.subtitle;
    final tracks = _player.state.tracks.subtitle;
    return tracks
        .map(
          (track) => PopupMenuItem<SubtitleTrack>(
            value: track,
            child: _TrackMenuItem(
              icon: Icons.subtitles_rounded,
              label: _subtitleTrackLabel(track),
              selected: track == selected,
            ),
          ),
        )
        .toList();
  }

  List<PopupMenuEntry<double>> _playbackSpeedMenuItems() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return speeds
        .map(
          (speed) => PopupMenuItem<double>(
            value: speed,
            child: _TrackMenuItem(
              icon: Icons.speed_rounded,
              label: '${_formatSpeed(speed)}x',
              selected: speed == _playbackSpeed,
            ),
          ),
        )
        .toList();
  }

  Future<void> _applyPreferredAudioTrack() async {
    final preferred = ref.read(audioLanguagePreferenceProvider);
    if (preferred.isAny) return;

    final tracks = _player.state.tracks.audio;
    final ranked = tracks
        .where((track) => track.id != 'auto' && track.id != 'no')
        .map(
            (track) => (track: track, score: _audioTrackPreferenceScore(track)))
        .where((entry) => entry.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (ranked.isNotEmpty) {
      await _player.setAudioTrack(ranked.first.track);
    }
  }

  Future<void> _disableSubtitlesByDefault() async {
    if (_player.state.track.subtitle.id == 'no') return;
    await _player.setSubtitleTrack(SubtitleTrack.no());
  }

  Future<void> _selectAudioTrack(AudioTrack track) async {
    await _player.setAudioTrack(track);
    final lang = _languageForCode(track.language);
    if (lang != null) {
      await ref
          .read(audioLanguagePreferenceProvider.notifier)
          .setLanguage(lang);
    }
    if (mounted) setState(() {});
    _scheduleHideControls();
  }

  Future<void> _selectSubtitleTrack(SubtitleTrack track) async {
    await _player.setSubtitleTrack(track);
    if (mounted) setState(() {});
    _scheduleHideControls();
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    setState(() => _playbackSpeed = speed);
    await _player.setRate(speed);
    _scheduleHideControls();
  }

  String _formatSpeed(double speed) {
    if (speed == speed.roundToDouble()) return speed.toStringAsFixed(0);
    return speed.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  }

  String _audioTrackLabel(AudioTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.id == 'no') return 'Off';
    return _trackLabel(
      title: track.title,
      language: track.language,
      codec: track.codec,
      fallback: 'Audio ${track.id}',
    );
  }

  int _audioTrackPreferenceScore(AudioTrack track) {
    final text = _trackText(track.title, track.language, track.codec);
    var score = 0;

    if (_containsTag(text, ['castellano', 'cast', 'es-es'])) score += 1000;
    if (_languageCode(track.language) == 'es') score += 550;
    if (_containsTag(text, ['spanish', 'esp', 'spa'])) score += 400;
    if (_containsTag(text, ['latino', 'latin', 'latam', 'es-la', 'es-mx'])) {
      score -= 350;
    }

    return score;
  }

  String _subtitleTrackLabel(SubtitleTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.id == 'no') return 'Off';
    return _trackLabel(
      title: track.title,
      language: track.language,
      codec: track.codec,
      fallback: 'Subtitle ${track.id}',
    );
  }

  String _trackLabel({
    required String? title,
    required String? language,
    required String? codec,
    required String fallback,
  }) {
    final parts = [
      title,
      language?.toUpperCase(),
      codec?.toUpperCase(),
    ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();
    final label = parts.join(' · ');
    return label.isNotEmpty ? label : fallback;
  }

  String? _languageCode(String? language) {
    if (language == null || language.trim().isEmpty) return null;
    return language.toLowerCase().split('-').first;
  }

  AppLanguage? _languageForCode(String? language) {
    final code = _languageCode(language);
    if (code == null) return null;
    for (final item in kAppLanguages) {
      if (!item.isAny && item.code == code) return item;
    }
    return null;
  }

  String _trackText(String? title, String? language, String? codec) {
    return ' ${title ?? ''} ${language ?? ''} ${codec ?? ''} '.toLowerCase();
  }

  bool _containsTag(String text, List<String> tags) {
    return tags.any((tag) {
      final escaped = RegExp.escape(tag.trim());
      final pattern = RegExp(r'(^|[^a-z0-9])' + escaped + r'([^a-z0-9]|$)');
      return pattern.hasMatch(text);
    });
  }

  Widget _buildTransportControls() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlIconButton(
            icon: Icons.replay_10_rounded,
            onPressed: () => _seekRelative(const Duration(seconds: -10)),
          ),
          const SizedBox(width: 16),
          _ControlIconButton(
            icon: _player.state.playing
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded,
            size: 58,
            onPressed: () {
              unawaited(_player.playOrPause());
              setState(() {});
              _scheduleHideControls();
            },
          ),
          const SizedBox(width: 16),
          _ControlIconButton(
            icon: Icons.forward_10_rounded,
            onPressed: () => _seekRelative(const Duration(seconds: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final position = _player.state.position;
    final duration = _player.state.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppTheme.primary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 3,
              ),
              child: Slider(
                value: progress,
                onChangeStart: (_) => _hideControlsTimer?.cancel(),
                onChangeEnd: (_) => _scheduleHideControls(),
                onChanged: duration.inMilliseconds <= 0
                    ? null
                    : (v) {
                        _seekTo(Duration(
                          milliseconds: (v * duration.inMilliseconds).round(),
                        ));
                      },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: PopupMenuButton<AudioTrack>(
                    tooltip: 'Audio track',
                    icon: const Icon(
                      Icons.audiotrack_rounded,
                      color: Colors.white,
                    ),
                    iconSize: 26,
                    padding: EdgeInsets.zero,
                    color: AppTheme.surface,
                    onSelected: (track) => _selectAudioTrack(track),
                    itemBuilder: (_) => _audioTrackMenuItems(),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: PopupMenuButton<SubtitleTrack>(
                    tooltip: 'Subtitles',
                    icon: const Icon(
                      Icons.subtitles_rounded,
                      color: Colors.white,
                    ),
                    iconSize: 26,
                    padding: EdgeInsets.zero,
                    color: AppTheme.surface,
                    onSelected: (track) => _selectSubtitleTrack(track),
                    itemBuilder: (_) => _subtitleTrackMenuItems(),
                  ),
                ),
                Expanded(child: _buildTransportControls()),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: PopupMenuButton<double>(
                    tooltip: 'Playback speed',
                    icon: const Icon(Icons.speed_rounded, color: Colors.white),
                    iconSize: 26,
                    padding: EdgeInsets.zero,
                    color: AppTheme.surface,
                    onSelected: (speed) => _setPlaybackSpeed(speed),
                    itemBuilder: (_) => _playbackSpeedMenuItems(),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: Colors.white,
                  ),
                  onPressed: _toggleFullscreen,
                  iconSize: 26,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  TorrentFileEntity? _findSelectedFile(TorrentEntity? torrent) {
    final fileId = widget.selectedFileId;
    if (torrent == null || fileId == null) return null;
    try {
      return torrent.files.firstWhere((file) => file.id == fileId);
    } catch (_) {
      return null;
    }
  }

  bool _hasEnoughBuffer(
    TorrentFileEntity? selectedFile,
    double progress,
    int downloadedBytes,
  ) {
    if (selectedFile == null) return progress >= _bufferThreshold;
    return downloadedBytes >= _requiredBufferBytes(selectedFile.size);
  }

  int _requiredBufferBytes(int fileSize) {
    if (fileSize <= _minBufferBytes) return fileSize;
    final percentBytes = (fileSize * _bufferThreshold).round();
    return percentBytes.clamp(_minBufferBytes, 8 * 1024 * 1024).toInt();
  }
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: size),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}

class _TrackMenuItem extends StatelessWidget {
  const _TrackMenuItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          selected ? Icons.check_rounded : icon,
          color: selected ? AppTheme.primary : AppTheme.onSurfaceVariant,
          size: 18,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  selected ? AppTheme.onBackground : AppTheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
