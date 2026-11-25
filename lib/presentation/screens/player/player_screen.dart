import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_size_formatter.dart';
import '../../../data/models/app_language.dart';
import '../../../domain/entities/torrent_file_entity.dart';
import '../../../domain/entities/torrent_entity.dart';
import '../../providers/settings_providers.dart';
import '../../providers/torrent_providers.dart';
import '../../widgets/loading_bar.dart';

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
    this.isLive = false,
    this.fallbackUrls = const [],
    this.httpHeaders = const {},
  });

  final String filePath;
  final String title;
  final String? torrentId;
  final String? selectedFileId;

  /// A live TV channel: no resume, no seek bar.
  final bool isLive;

  /// Other streams of the same live channel, tried in order when the
  /// current one fails.
  final List<String> fallbackUrls;

  /// HTTP headers the stream requires (from a Stremio addon's
  /// `behaviorHints.proxyHeaders`).
  final Map<String, String> httpHeaders;

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
  String? _openedSource;
  bool _userPickedSubtitle = false;

  // Resume position support.
  SharedPreferences? _prefs;
  bool _resumeChecked = false;
  // Computed while the widget is alive: `ref` must not be used in dispose().
  String? _positionKeyCache;
  DateTime _lastPositionSave = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _isStreamingMode => widget.torrentId != null;

  // ── Keyboard, mouse and on-screen feedback ────────────────────────────────

  static const _volumeKey = 'player_volume';
  double _volume = 100;
  double _volumeBeforeMute = 100;

  /// Short message shown in the middle of the video ("Volumen 70 %").
  String? _osdText;
  IconData? _osdIcon;
  Timer? _osdTimer;

  void _showOsd(IconData icon, String text) {
    _osdTimer?.cancel();
    setState(() {
      _osdIcon = icon;
      _osdText = text;
    });
    _osdTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _osdText = null);
    });
  }

  void _togglePlay() {
    unawaited(_player.playOrPause());
    final willPlay = !_player.state.playing;
    _showOsd(willPlay ? Icons.play_arrow_rounded : Icons.pause_rounded,
        willPlay ? 'Reproducir' : 'Pausa');
    setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  Future<void> _setVolume(double value) async {
    _volume = value.clamp(0, 100).roundToDouble();
    await _player.setVolume(_volume);
    _showOsd(
      _volume == 0
          ? Icons.volume_off_rounded
          : _volume < 50
              ? Icons.volume_down_rounded
              : Icons.volume_up_rounded,
      _volume == 0 ? 'Silencio' : 'Volumen ${_volume.round()} %',
    );
    unawaited((_prefs ?? await SharedPreferences.getInstance())
        .setDouble(_volumeKey, _volume));
  }

  void _toggleMute() {
    if (_volume > 0) {
      _volumeBeforeMute = _volume;
      unawaited(_setVolume(0));
    } else {
      unawaited(_setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 100));
    }
  }

  void _seekBy(Duration offset) {
    if (widget.isLive) return;
    unawaited(_seekRelative(offset));
    final seconds = offset.inSeconds;
    _showOsd(
      seconds < 0 ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded,
      '${seconds < 0 ? '−' : '+'}${seconds.abs() >= 60 ? '${seconds.abs() ~/ 60} min' : '${seconds.abs()} s'}',
    );
  }

  /// Player shortcuts. Ignored while a menu or dialog is open on top.
  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent || !mounted) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final step = Duration(seconds: shift ? 60 : 10);

    if (!repeat &&
        (key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.keyK ||
            key == LogicalKeyboardKey.mediaPlayPause)) {
      _togglePlay();
    } else if (!repeat && key == LogicalKeyboardKey.mediaPlay) {
      if (!_player.state.playing) _togglePlay();
    } else if (!repeat &&
        (key == LogicalKeyboardKey.mediaPause ||
            key == LogicalKeyboardKey.mediaStop)) {
      if (_player.state.playing) _togglePlay();
    } else if (!repeat &&
        (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.f11)) {
      unawaited(_toggleFullscreen());
    } else if (!repeat && key == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        unawaited(_toggleFullscreen());
      } else {
        context.pop();
      }
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyJ) {
      _seekBy(-step);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL) {
      _seekBy(step);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      unawaited(_setVolume(_volume + 5));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      unawaited(_setVolume(_volume - 5));
    } else if (!repeat && key == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else {
      return false;
    }
    return true;
  }

  /// Mouse wheel over the video: volume.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    unawaited(_setVolume(_volume + (dy < 0 ? 5 : -5)));
  }

  /// Moving the mouse brings the controls (and the cursor) back.
  void _onHover(PointerHoverEvent _) {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  /// Index into [_liveSources] of the stream being played.
  int _liveSourceIndex = 0;
  List<String> get _liveSources => [widget.filePath, ...widget.fallbackUrls];

  /// Switches a live channel to its next stream. Returns false when there
  /// are none left.
  bool _tryNextLiveSource() {
    if (!widget.isLive || _liveSourceIndex + 1 >= _liveSources.length) {
      return false;
    }
    _liveSourceIndex++;
    _initialized = false;
    _openedSource = null;
    unawaited(_initPlayer(_liveSources[_liveSourceIndex]));
    return true;
  }

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        // Larger demuxer cache: torrent throughput is bursty.
        bufferSize: 64 * 1024 * 1024,
      ),
    );
    _videoController = VideoController(_player);
    HardwareKeyboard.instance.addHandler(_onKey);
    unawaited(SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getDouble(_volumeKey);
      if (saved != null && mounted) {
        _volume = saved;
        _volumeBeforeMute = saved > 0 ? saved : 100;
        unawaited(_player.setVolume(saved));
      }
    }));
    _configureNetworkPlayback();
    _listenToPlayer();
    unawaited(SharedPreferences.getInstance().then((p) => _prefs = p));

    if (!_isStreamingMode) {
      unawaited(_initPlayer(widget.filePath));
    }
  }

  /// The local stream servers block until the needed pieces arrive, which can
  /// take a while on slow swarms; mpv must not give up on them too early.
  void _configureNetworkPlayback() {
    if (kIsWeb) return;
    // NativePlayer.setProperty is missing from media_kit's web stub, so it is
    // called dynamically to keep the web build compiling.
    if (_player.platform is! NativePlayer) return;
    final dynamic mpv = _player.platform;
    unawaited(() async {
      try {
        // Live channels fail over to their next stream instead of waiting.
        await mpv.setProperty('network-timeout', widget.isLive ? '15' : '300');
        await mpv.setProperty('cache', 'yes');
        await mpv.setProperty('cache-secs', '30');
        await mpv.setProperty('demuxer-readahead-secs', '30');
      } catch (_) {}
    }());
  }

  void _listenToPlayer() {
    void repaint(_) {
      if (mounted) setState(() {});
    }

    _subscriptions.addAll([
      _player.stream.playing.listen(repaint),
      _player.stream.position.listen((position) {
        _maybeSavePosition(position);
        repaint(null);
      }),
      _player.stream.duration.listen((duration) {
        unawaited(_maybeResume(duration));
        repaint(null);
      }),
      _player.stream.buffering.listen(repaint),
      _player.stream.bufferingPercentage.listen(repaint),
      _player.stream.tracks.listen((_) {
        unawaited(_applyTrackPreferences());
        repaint(null);
      }),
      _player.stream.track.listen(repaint),
      _player.stream.width.listen(repaint),
      _player.stream.height.listen(repaint),
      _player.stream.error.listen((message) {
        debugPrint('Player error: $message');
        // Only fatal before playback starts; mpv recovers from later hiccups.
        if (!_initialized && mounted && !_tryNextLiveSource()) {
          setState(() => _error = widget.isLive
              ? 'Este canal no está disponible ahora mismo.'
              : 'No se puede reproducir este archivo.\n$message');
        }
      }),
    ]);
  }

  Future<void> _initPlayer(String source) async {
    if (_initializingPlayer) return;
    final uri = _toMediaUri(source);
    if (uri == null) {
      setState(() => _error = 'No se puede reproducir este archivo: ubicación desconocida.');
      return;
    }
    _initializingPlayer = true;
    _openedSource = source;
    try {
      await _player.open(
        Media(
          uri,
          httpHeaders: widget.httpHeaders.isEmpty ? null : widget.httpHeaders,
        ),
        play: true,
      );
      await _player.setRate(_playbackSpeed);
      // Start without subtitles; preferences are applied once tracks load.
      if (!_userPickedSubtitle) await _player.setSubtitleTrack(SubtitleTrack.no());

      if (mounted) setState(() => _initialized = true);
      _scheduleHideControls();
      unawaited(_applyTrackPreferences());
    } catch (e) {
      _initializingPlayer = false;
      if (mounted && !_tryNextLiveSource()) {
        setState(() => _error = widget.isLive
            ? 'Este canal no está disponible ahora mismo.'
            : 'No se puede reproducir este archivo.\n$e');
      }
    } finally {
      _initializingPlayer = false;
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _initialized = false;
      _openedSource = null;
    });
    _liveSourceIndex = 0;
    if (!_isStreamingMode) await _initPlayer(widget.filePath);
  }

  String? _toMediaUri(String source) {
    final uri = Uri.tryParse(source);
    if (uri != null &&
        const ['http', 'https', 'content', 'file', 'blob'].contains(uri.scheme)) {
      return source;
    }
    // Absolute local paths (POSIX or Windows drive letters).
    if (source.startsWith('/')) return Uri.file(source).toString();
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(source)) {
      return Uri.file(source, windows: true).toString();
    }
    return null;
  }

  // ── Resume position ───────────────────────────────────────────────────────

  String _computePositionKey() {
    if (_isStreamingMode) {
      final torrent = ref.read(torrentByIdProvider(widget.torrentId!));
      final fileIndex = widget.selectedFileId?.split('-').last ?? '0';
      return 'playback_position:${torrent?.infoHash ?? widget.torrentId}:$fileIndex';
    }
    return 'playback_position:${widget.filePath}';
  }

  Future<void> _maybeResume(Duration duration) async {
    if (widget.isLive || _resumeChecked || duration <= Duration.zero) return;
    _resumeChecked = true;
    final key = _positionKeyCache = _computePositionKey();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final saved = Duration(milliseconds: prefs.getInt(key) ?? 0);
    if (saved > const Duration(seconds: 15) &&
        saved < duration - const Duration(seconds: 30)) {
      await _player.seek(saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Continuando en ${_formatDuration(saved)}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Desde el principio',
              onPressed: () => _player.seek(Duration.zero),
            ),
          ),
        );
      }
    }
  }

  void _maybeSavePosition(Duration position, {bool force = false}) {
    final prefs = _prefs;
    final key = _positionKeyCache;
    if (prefs == null || key == null) return;
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastPositionSave) < const Duration(seconds: 5)) {
      return;
    }
    _lastPositionSave = now;
    final duration = _player.state.duration;
    final nearEnd = duration > Duration.zero &&
        position > duration - const Duration(seconds: 60);
    if (nearEnd) {
      unawaited(prefs.remove(key));
    } else {
      unawaited(prefs.setInt(key, position.inMilliseconds));
    }
  }

  @override
  void dispose() {
    // Stop listening first so no player event can reach a disposed widget.
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _hideControlsTimer?.cancel();
    _osdTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (_isFullscreen) unawaited(defaultExitNativeFullscreen());
    try {
      _maybeSavePosition(_player.state.position, force: true);
    } catch (_) {}
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

  /// Real fullscreen: the native window on desktop (media_kit's helper),
  /// immersive landscape on phones.
  Future<void> _toggleFullscreen() async {
    final enter = !_isFullscreen;
    setState(() => _isFullscreen = enter);
    if (enter) {
      await defaultEnterNativeFullscreen();
    } else {
      await defaultExitNativeFullscreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final torrent = _isStreamingMode
        ? ref.watch(torrentByIdProvider(widget.torrentId!))
        : null;
    final selectedFile = _findSelectedFile(torrent);
    final streamUrl = (torrent?.streamUrl?.isNotEmpty ?? false)
        ? torrent!.streamUrl
        : widget.filePath.isNotEmpty
            ? widget.filePath
            : null;

    // Open the stream as soon as the engine has a URL: the local stream server
    // waits for the pieces itself, so there is no need to pre-buffer here.
    if (_isStreamingMode &&
        streamUrl != null &&
        streamUrl != _openedSource &&
        !_initializingPlayer &&
        _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && streamUrl != _openedSource && !_initializingPlayer) {
          _initialized = false;
          unawaited(_initPlayer(streamUrl));
        }
      });
    }

    final waiting = _error == null &&
        (!_initialized || (_isStreamingMode && _player.state.buffering));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerSignal: _onPointerSignal,
        child: MouseRegion(
          // The cursor hides with the controls while watching.
          cursor: _controlsVisible || _error != null
              ? MouseCursor.defer
              : SystemMouseCursors.none,
          onHover: _onHover,
          child: GestureDetector(
            onTap: _toggleControls,
            onDoubleTap: _toggleFullscreen,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildVideo(),
                if (waiting)
                  _buildBufferingOverlay(
                    torrent: torrent,
                    file: selectedFile,
                    hasStream: streamUrl != null,
                  ),
                if (_controlsVisible || _error != null)
                  _buildControlsOverlay(),
                if (_osdText != null)
                  IgnorePointer(
                    child: Center(
                      child: _Osd(icon: _osdIcon!, text: _osdText!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBufferingOverlay({
    required TorrentEntity? torrent,
    required TorrentFileEntity? file,
    required bool hasStream,
  }) {
    final speed = torrent?.downloadSpeed ?? 0;
    final peers = torrent?.peers ?? 0;
    // mpv reports how full its cache is while buffering; before the video
    // opens there is nothing to measure, so the bar just sweeps.
    final percent = _player.state.bufferingPercentage;
    final progress = _initialized && _player.state.buffering && percent > 0
        ? percent / 100
        : null;
    final headline = !hasStream
        ? 'Preparando la reproducción...'
        : _isStreamingMode && peers == 0
            ? 'Conectando con pares...'
            : _initialized
                ? 'Cargando...'
                : 'Cargando vídeo...';

    final details = <String>[
      if (_isStreamingMode) '$peers pares',
      if (_isStreamingMode) '${FileSizeFormatter.format(speed.round())}/s',
    ].join('  ·  ');

    return IgnorePointer(
      child: Container(
        color: _initialized ? Colors.black38 : Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              progress != null
                  ? '$headline ${(progress * 100).round()} %'
                  : headline,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.title,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 24),
            LoadingBar(value: progress),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                details,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
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
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) return const SizedBox.shrink();

    return Center(
      child: Video(
        controller: _videoController,
        controls: null,
        fit: BoxFit.contain,
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

  /// Picks the preferred audio track, then the subtitles that go with it.
  Future<void> _applyTrackPreferences() async {
    if (!mounted) return;
    final spanishAudio = await _applyPreferredAudioTrack();
    await _applyPreferredSubtitles(spanishAudio);
  }

  /// Selects the best Spanish (preferably Castilian) audio track.
  /// Returns whether the audio now playing is Spanish.
  Future<bool> _applyPreferredAudioTrack() async {
    final preferred = ref.read(audioLanguagePreferenceProvider);
    final tracks = _player.state.tracks.audio;
    if (preferred.isAny) {
      await _avoidUndecodableAudio();
      return _spanishScore(_player.state.track.audio.title,
              _player.state.track.audio.language) >
          0;
    }

    final ranked = tracks
        .where((track) => track.id != 'auto' && track.id != 'no')
        .map(
            (track) => (track: track, score: _audioTrackPreferenceScore(track)))
        .where((entry) => entry.score > 0)
        .toList()
      ..sort((a, b) {
        // Same language: a track the player can decode goes first.
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return (_undecodable(a.track) ? 1 : 0)
            .compareTo(_undecodable(b.track) ? 1 : 0);
      });

    if (ranked.isEmpty) {
      await _avoidUndecodableAudio();
      return false;
    }
    final best = ranked
            .where((e) =>
                e.score == ranked.first.score && !_undecodable(e.track))
            .firstOrNull ??
        ranked.first;
    if (_player.state.track.audio != best.track) {
      await _player.setAudioTrack(best.track);
    }
    return true;
  }

  /// Dolby TrueHD (and its MLP core) cannot be decoded by the bundled
  /// libmpv: such a track plays silent.
  static bool _undecodable(AudioTrack track) {
    final codec = (track.codec ?? '').toLowerCase();
    return codec.contains('truehd') || codec == 'mlp';
  }

  /// When the playing track is one the player cannot decode, switch to
  /// another of the same language (or any decodable one).
  Future<void> _avoidUndecodableAudio() async {
    final current = _player.state.track.audio;
    final real = _player.state.tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList();
    final playing = real.where((t) => t.id == current.id).firstOrNull ??
        (current.id == 'auto' ? real.firstOrNull : null);
    if (playing == null || !_undecodable(playing)) return;
    final alternative = real
            .where((t) => !_undecodable(t) && t.language == playing.language)
            .firstOrNull ??
        real.where((t) => !_undecodable(t)).firstOrNull;
    if (alternative != null) await _player.setAudioTrack(alternative);
  }

  /// Applies the subtitle setting unless the user already picked a track:
  /// - automatic: forced Spanish subtitles with Spanish audio, full Spanish
  ///   subtitles when there is no Spanish audio;
  /// - always: full Spanish subtitles; off: none.
  Future<void> _applyPreferredSubtitles(bool spanishAudio) async {
    if (_userPickedSubtitle) return;
    final mode = ref.read(subtitleModeProvider);

    final spanish = _player.state.tracks.subtitle
        .where((t) => t.id != 'auto' && t.id != 'no')
        .where((t) => _spanishScore(t.title, t.language) > 0)
        .toList()
      ..sort((a, b) => _spanishScore(b.title, b.language)
          .compareTo(_spanishScore(a.title, a.language)));
    final forced = spanish.where(_isForcedSubtitle).toList();
    final full = spanish.where((t) => !_isForcedSubtitle(t)).toList();

    final SubtitleTrack target = switch (mode) {
      SubtitleMode.off => SubtitleTrack.no(),
      SubtitleMode.always => full.firstOrNull ?? SubtitleTrack.no(),
      SubtitleMode.auto => spanishAudio
          ? (forced.firstOrNull ?? SubtitleTrack.no())
          : (full.firstOrNull ?? forced.firstOrNull ?? SubtitleTrack.no()),
    };
    if (_player.state.track.subtitle != target) {
      await _player.setSubtitleTrack(target);
    }
  }

  bool _isForcedSubtitle(SubtitleTrack track) {
    final text = _trackText(track.title, track.language, track.codec);
    return text.contains('forz') || text.contains('forced');
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
    _userPickedSubtitle = true;
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
    if (track.id == 'auto') return 'Automático';
    if (track.id == 'no') return 'Desactivado';
    return _trackLabel(
      title: track.title,
      language: track.language,
      codec: track.codec,
      fallback: 'Audio ${track.id}',
    );
  }

  int _audioTrackPreferenceScore(AudioTrack track) =>
      _spanishScore(track.title, track.language, codec: track.codec);

  /// > 0 when a track looks Spanish; Castilian scores highest, Latino lowest.
  int _spanishScore(String? title, String? language, {String? codec}) {
    final text = _trackText(title, language, codec);
    var score = 0;

    if (_containsTag(text, ['castellano', 'cast', 'es-es', 'españa'])) score += 1000;
    if (_languageCode(language) == 'es') score += 550;
    if (_containsTag(text, ['spanish', 'esp', 'spa', 'español'])) score += 400;
    if (_containsTag(text, ['latino', 'latin', 'latam', 'es-la', 'es-mx', 'es-419'])) {
      score -= 350;
    }

    return score;
  }


  String _subtitleTrackLabel(SubtitleTrack track) {
    if (track.id == 'auto') return 'Automático';
    if (track.id == 'no') return 'Desactivado';
    return _trackLabel(
      title: track.title,
      language: track.language,
      codec: track.codec,
      fallback: 'Subtítulo ${track.id}',
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
    if (widget.isLive) {
      return _ControlIconButton(
        tooltip: 'Pausa / reproducir (Espacio)',
        icon: _player.state.playing
            ? Icons.pause_circle_filled_rounded
            : Icons.play_circle_filled_rounded,
        size: 58,
        onPressed: () {
          unawaited(_player.playOrPause());
          setState(() {});
          _scheduleHideControls();
        },
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlIconButton(
            tooltip: 'Atrás 10 s (←)',
            icon: Icons.replay_10_rounded,
            onPressed: () => _seekRelative(const Duration(seconds: -10)),
          ),
          const SizedBox(width: 16),
          _ControlIconButton(
            tooltip: 'Pausa / reproducir (Espacio)',
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
            tooltip: 'Adelante 10 s (→)',
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
            if (widget.isLive)
              const Align(
                alignment: Alignment.centerLeft,
                child: _LiveBadge(),
              )
            else ...[
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
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: PopupMenuButton<AudioTrack>(
                    tooltip: 'Pista de audio',
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
                    tooltip: 'Subtítulos',
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
                    tooltip: 'Velocidad de reproducción',
                    icon: const Icon(Icons.speed_rounded, color: Colors.white),
                    iconSize: 26,
                    padding: EdgeInsets.zero,
                    color: AppTheme.surface,
                    onSelected: (speed) => _setPlaybackSpeed(speed),
                    itemBuilder: (_) => _playbackSpeedMenuItems(),
                  ),
                ),
                IconButton(
                  tooltip: _isFullscreen
                      ? 'Salir de pantalla completa (F o Esc)'
                      : 'Pantalla completa (F o doble clic)',
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
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
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

/// Red "EN DIRECTO" label shown instead of the seek bar for live TV.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'EN DIRECTO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// The brief feedback in the middle of the video (volume, seek, pause).
class _Osd extends StatelessWidget {
  const _Osd({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(170),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
