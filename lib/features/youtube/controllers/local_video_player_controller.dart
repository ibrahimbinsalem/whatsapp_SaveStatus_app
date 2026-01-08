import 'dart:async';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class LocalVideoPlayerController extends GetxController
    with GetSingleTickerProviderStateMixin {
  LocalVideoPlayerController({
    required this.filePath,
    required this.title,
    this.playlist,
    this.initialIndex = 0,
    this.coverPath,
    this.coverUrl,
  });

  final String filePath;
  final String title;
  final List<Map<String, String>>? playlist;
  final int initialIndex;
  final String? coverPath;
  final String? coverUrl;

  bool get mounted => !isClosed;

  void setState(VoidCallback fn) {
    if (isClosed) {
      return;
    }
    fn();
    update();
  }

  static final AudioPlayer _sharedAudioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isAudio = false;
  bool _initialized = false;
  bool _showControls = true;
  Timer? _hideTimer;
  String? _errorMessage;
  double _playbackSpeed = 1.0;
  late final AnimationController _pulseController;
  bool _isFullscreen = false;
  bool _isLocked = false;

  static const List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5, 2.0];
  List<Map<String, String>> get _audioQueue => playlist ?? const [];
  bool get _hasQueue => _audioQueue.length > 1;

  @override
  void onInit() {
    super.onInit();
    _isAudio = _isAudioFile(filePath);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (_isAudio) {
        final player = _sharedAudioPlayer;
        _audioPlayer = player;
        await player.stop();
        if (_audioQueue.isNotEmpty) {
          final sources = _audioQueue.map((item) {
            final path = item['path'] ?? '';
            final title = item['title'] ?? 'Audio';
            final coverPath = item['coverPath'];
            final coverUrl = item['coverUrl'];
            final artUri = _resolveArtUri(coverPath, coverUrl);
            return AudioSource.file(
              path,
              tag: audio_service.MediaItem(
                id: path,
                title: title,
                artUri: artUri,
              ),
            );
          }).toList();
          final playlistSource = ConcatenatingAudioSource(children: sources);
          await player.setAudioSource(
            playlistSource,
            initialIndex: initialIndex,
          );
        } else {
          final artUri = _resolveArtUri(coverPath, coverUrl);
          await player.setAudioSource(
            AudioSource.file(
              filePath,
              tag: audio_service.MediaItem(
                id: filePath,
                title: title,
                artUri: artUri,
              ),
            ),
          );
        }
        await player.setSpeed(_playbackSpeed);
        await player.play();
      } else {
        final controller = VideoPlayerController.file(File(filePath));
        await controller.initialize();
        await controller.play();
        _videoController = controller;
        _startHideTimer();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Failed to load media';
      });
    }
  }

  Uri? _resolveArtUri(String? coverPath, String? coverUrl) {
    if (coverPath != null &&
        coverPath.isNotEmpty &&
        File(coverPath).existsSync()) {
      return Uri.file(coverPath);
    }
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return Uri.parse(coverUrl);
    }
    return null;
  }

  @override
  void onClose() {
    _hideTimer?.cancel();
    _videoController?.dispose();
    _audioPlayer?.stop();
    _pulseController.dispose();
    _exitFullscreen();
    super.onClose();
  }

  bool _isAudioFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    const audioExtensions = {
      'mp3',
      'm4a',
      'aac',
      'wav',
      'ogg',
      'opus',
      'flac',
      'wma',
      'mka',
      'aiff',
      'alac',
      'webm',
    };
    return audioExtensions.contains(extension);
  }

  void _toggleControls() {
    if (_isAudio) {
      return;
    }
    if (_isLocked) {
      return;
    }
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    }
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      await _exitFullscreen();
    } else {
      await _enterFullscreen();
    }
  }

  Future<void> _enterFullscreen() async {
    _isFullscreen = true;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _exitFullscreen() async {
    if (!_isFullscreen) {
      return;
    }
    _isFullscreen = false;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _toggleLock() {
    if (_isAudio) {
      return;
    }
    setState(() {
      _isLocked = !_isLocked;
      _showControls = !_isLocked;
    });
  }

  Future<void> _shareCurrentFile() async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
    } catch (_) {}
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _videoController?.value.isPlaying == true) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_isAudio) {
      if (_audioPlayer == null) {
        return;
      }
      if (_audioPlayer!.playing) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.play();
      }
      return;
    }
    final controller = _videoController;
    if (controller == null) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    _startHideTimer();
  }

  Future<void> _seekBy(Duration offset) async {
    if (_isAudio) {
      final player = _audioPlayer;
      if (player == null) {
        return;
      }
      final position = player.position + offset;
      final duration = player.duration ?? Duration.zero;
      final target = position < Duration.zero
          ? Duration.zero
          : (position > duration ? duration : position);
      await player.seek(target);
      return;
    }
    final controller = _videoController;
    if (controller == null) {
      return;
    }
    final position = controller.value.position + offset;
    final duration = controller.value.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : (position > duration ? duration : position);
    await controller.seekTo(target);
    _startHideTimer();
  }

  Future<void> _toggleShuffle() async {
    final player = _audioPlayer;
    if (player == null || !_hasQueue) {
      return;
    }
    final enable = !player.shuffleModeEnabled;
    if (enable) {
      await player.shuffle();
    }
    await player.setShuffleModeEnabled(enable);
  }

  Future<void> _cycleLoopMode() async {
    final player = _audioPlayer;
    if (player == null) {
      return;
    }
    final current = player.loopMode;
    final next = current == LoopMode.off
        ? LoopMode.all
        : (current == LoopMode.all ? LoopMode.one : LoopMode.off);
    await player.setLoopMode(next);
  }

  void _cycleSpeed() {
    final nextIndex =
        (_speedOptions.indexOf(_playbackSpeed) + 1) % _speedOptions.length;
    _playbackSpeed = _speedOptions[nextIndex];
    _audioPlayer?.setSpeed(_playbackSpeed);
    _videoController?.setPlaybackSpeed(_playbackSpeed);
    setState(() {});
  }

  Future<void> _skipToNext() async {
    final player = _audioPlayer;
    if (player == null) {
      return;
    }
    if (player.hasNext) {
      await player.seekToNext();
    }
  }

  Future<void> _skipToPrevious() async {
    final player = _audioPlayer;
    if (player == null) {
      return;
    }
    if (player.hasPrevious) {
      await player.seekToPrevious();
    }
  }

  Future<void> _seekToIndex(int index) async {
    final player = _audioPlayer;
    if (player == null) {
      return;
    }
    final sequence = player.sequence;
    if (sequence == null || sequence.isEmpty) {
      return;
    }
    if (index < 0 || index >= sequence.length) {
      return;
    }
    await player.seek(Duration.zero, index: index);
    await player.play();
  }

  Future<void> _playNext() async {
    final player = _audioPlayer;
    if (player == null) {
      return;
    }
    if (player.hasNext) {
      await player.seekToNext();
      await player.play();
    }
  }

  Future<void> _playPrevious() async {
    final player = _audioPlayer;
    if (player == null) {
      return;
    }
    if (player.hasPrevious) {
      await player.seekToPrevious();
      await player.play();
    }
  }

  void _setSpeed(double speed) {
    _playbackSpeed = speed;
    _audioPlayer?.setSpeed(_playbackSpeed);
    _videoController?.setPlaybackSpeed(_playbackSpeed);
    setState(() {});
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  
  VideoPlayerController? get videoController => _videoController;

  AudioPlayer? get audioPlayer => _audioPlayer;

  bool get isAudio => _isAudio;

  bool get initialized => _initialized;

  bool get showControls => _showControls;

  String? get errorMessage => _errorMessage;

  double get playbackSpeed => _playbackSpeed;

  AnimationController get pulseController => _pulseController;

  bool get isFullscreen => _isFullscreen;

  bool get isLocked => _isLocked;

  List<double> get speedOptions => _speedOptions;

  List<Map<String, String>> get audioQueue => _audioQueue;

  bool get hasQueue => _hasQueue;

  String formatDuration(Duration duration) => _formatDuration(duration);

  void toggleControls() => _toggleControls();

  Future<void> toggleFullscreen() => _toggleFullscreen();

  void toggleLock() => _toggleLock();

  void cycleSpeed() => _cycleSpeed();

  Future<void> shareCurrentFile() => _shareCurrentFile();

  void startHideTimer() => _startHideTimer();

  Future<void> togglePlayback() => _togglePlayback();

  Future<void> seekBy(Duration offset) => _seekBy(offset);

  Future<void> toggleShuffle() => _toggleShuffle();

  Future<void> cycleLoopMode() => _cycleLoopMode();

  Future<void> seekToIndex(int index) => _seekToIndex(index);

  Future<void> playNext() => _playNext();

  Future<void> playPrevious() => _playPrevious();

  void setSpeed(double speed) => _setSpeed(speed);
}
