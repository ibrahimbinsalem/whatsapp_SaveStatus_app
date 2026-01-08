import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:just_audio/just_audio.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../controllers/local_video_player_controller.dart';

const Color _ytRed = Color(0xFFE53935);
const Color _ytDark = Color(0xFF0F0F0F);
const Color _ytSurface = Color(0xFF1C1C1C);

class LocalVideoPlayerScreen extends StatefulWidget {
  final String filePath;
  final String title;
  final List<Map<String, String>>? playlist;
  final int initialIndex;
  final String? coverPath;
  final String? coverUrl;

  const LocalVideoPlayerScreen({
    super.key,
    required this.filePath,
    required this.title,
    this.playlist,
    this.initialIndex = 0,
    this.coverPath,
    this.coverUrl,
  });

  @override
  State<LocalVideoPlayerScreen> createState() => _LocalVideoPlayerScreenState();
}

class _LocalVideoPlayerScreenState extends State<LocalVideoPlayerScreen> {
  late final String _tag;
  late final LocalVideoPlayerController _controller;

  VideoPlayerController? get _videoController => _controller.videoController;
  AudioPlayer? get _audioPlayer => _controller.audioPlayer;
  bool get _isAudio => _controller.isAudio;
  bool get _initialized => _controller.initialized;
  bool get _showControls => _controller.showControls;
  String? get _errorMessage => _controller.errorMessage;
  double get _playbackSpeed => _controller.playbackSpeed;
  AnimationController get _pulseController => _controller.pulseController;
  bool get _isFullscreen => _controller.isFullscreen;
  bool get _isLocked => _controller.isLocked;
  List<double> get _speedOptions => _controller.speedOptions;
  List<Map<String, String>> get _audioQueue => _controller.audioQueue;
  bool get _hasQueue => _controller.hasQueue;

  @override
  void initState() {
    super.initState();
    _tag = '${widget.filePath}_${widget.initialIndex}';
    _controller = Get.put(
      LocalVideoPlayerController(
        filePath: widget.filePath,
        title: widget.title,
        playlist: widget.playlist,
        initialIndex: widget.initialIndex,
        coverPath: widget.coverPath,
        coverUrl: widget.coverUrl,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<LocalVideoPlayerController>(tag: _tag);
    super.dispose();
  }

  void _toggleControls() => _controller.toggleControls();

  Future<void> _toggleFullscreen() => _controller.toggleFullscreen();

  void _toggleLock() => _controller.toggleLock();

  void _cycleSpeed() => _controller.cycleSpeed();

  Future<void> _shareCurrentFile() => _controller.shareCurrentFile();

  Future<void> _togglePlayback() => _controller.togglePlayback();

  Future<void> _seekBy(Duration offset) => _controller.seekBy(offset);

  Future<void> _toggleShuffle() => _controller.toggleShuffle();

  Future<void> _cycleLoopMode() => _controller.cycleLoopMode();

  Future<void> _playNext() => _controller.playNext();

  Future<void> _playPrevious() => _controller.playPrevious();

  Future<void> _skipToNext() => _controller.playNext();

  Future<void> _skipToPrevious() => _controller.playPrevious();

  void _setSpeed(double speed) => _controller.setSpeed(speed);

  String _formatDuration(Duration duration) => _controller.formatDuration(duration);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocalVideoPlayerController>(
      tag: _tag,
      builder: (_) {
        return Scaffold(
          backgroundColor: _ytDark,
          body: _isAudio ? _buildAudioBody() : _buildVideoBody(),
        );
      },
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F0F0F), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildTopBar({required String type}) {
    return Row(
      children: [
        _IconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            type,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        _IconButton(icon: Icons.share_rounded, onTap: _shareCurrentFile),
      ],
    );
  }

  Widget _buildVideoBody() {
    if (_isFullscreen) {
      return Stack(
        fit: StackFit.expand,
        children: [_buildVideoCard(fullscreen: true)],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackground(),
        Positioned(
          top: -120,
          right: -80,
          child: _GlowBubble(size: 220, color: _ytRed.withOpacity(0.18)),
        ),
        Positioned(
          bottom: -140,
          left: -90,
          child: _GlowBubble(
            size: 260,
            color: const Color(0xFFFF6D6D).withOpacity(0.16),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
            child: Column(
              children: [
                _buildTopBar(type: 'VIDEO'),
                SizedBox(height: 16.h),
                Expanded(child: _buildVideoCard()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard({bool fullscreen = false}) {
    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!);
    }
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(fullscreen ? 0 : 22.r),
            child: Container(
              color: Colors.black,
              child: _initialized && _videoController != null
                  ? FittedBox(
                      fit: fullscreen ? BoxFit.contain : BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: _ytRed),
                    ),
            ),
          ),
          if (_initialized && _videoController != null)
            Positioned.fill(child: _buildVideoOverlay()),
        ],
      ),
    );
  }

  Widget _buildVideoOverlay() {
    if (_isLocked) {
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: _ControlButton(
            icon: Icons.lock_open_rounded,
            onTap: _toggleLock,
          ),
        ),
      );
    }
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !_showControls,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black54,
                Colors.transparent,
                Colors.transparent,
                Colors.black87,
              ],
              stops: [0.0, 0.25, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Center(child: _buildPlaybackControls(isAudio: false)),
              Positioned(
                top: 12.h,
                left: 12.w,
                child: _ControlButton(
                  icon: Icons.lock_outline_rounded,
                  onTap: _toggleLock,
                ),
              ),
              Positioned(
                top: 12.h,
                right: 12.w,
                child: Row(
                  children: [
                    _SpeedChip(
                      label: '${_playbackSpeed.toStringAsFixed(2)}x',
                      onTap: _cycleSpeed,
                    ),
                    SizedBox(width: 8.w),
                    _ControlButton(
                      icon: _isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      onTap: _toggleFullscreen,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildVideoProgress(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoProgress() {
    final controller = _videoController;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, VideoPlayerValue value, child) {
          final duration = value.duration;
          final position = value.position;
          final max = duration.inMilliseconds
              .toDouble()
              .clamp(1.0, double.infinity)
              .toDouble();
          final current = position.inMilliseconds
              .toDouble()
              .clamp(0.0, max)
              .toDouble();

          return Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _ytRed,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: _ytRed,
                  overlayColor: _ytRed.withOpacity(0.2),
                  trackHeight: 3.h,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r),
                ),
                child: Slider(
                  value: current,
                  max: max,
                  onChanged: (value) {
                    controller.seekTo(Duration(milliseconds: value.round()));
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAudioBody() {
    if (_errorMessage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: _ErrorState(message: _errorMessage!),
            ),
          ),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackground(),
        Positioned(
          top: -120,
          right: -80,
          child: _GlowBubble(size: 220, color: _ytRed.withOpacity(0.18)),
        ),
        Positioned(
          bottom: -140,
          left: -90,
          child: _GlowBubble(
            size: 260,
            color: const Color(0xFFFF6D6D).withOpacity(0.16),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
            child: Column(
              children: [
                _buildTopBar(type: 'AUDIO'),
                SizedBox(height: 24.h),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildAudioHero(),
                        SizedBox(height: 18.h),
                        _GlassCard(
                          child: Column(
                            children: [
                              Text(
                                'الآن قيد التشغيل',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.sp,
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              _buildAudioTitle(),
                              SizedBox(height: 8.h),
                              _AnimatedBars(animation: _pulseController),
                              SizedBox(height: 12.h),
                              Text(
                                _fileExtensionLabel(widget.filePath),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.sp,
                                ),
                              ),
                              SizedBox(height: 16.h),
                              _buildAudioProgress(),
                              if (_hasQueue) SizedBox(height: 16.h),
                              if (_hasQueue) _buildQueuePreview(),
                            ],
                          ),
                        ),
                        SizedBox(height: 18.h),
                        _GlassCard(
                          child: Column(
                            children: [
                              _buildPlaybackControls(isAudio: true),
                              SizedBox(height: 20.h),
                              Divider(color: Colors.white10),
                              SizedBox(height: 10.h),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildAudioModeRow(),
                                  // SizedBox(height: 12.h),
                                  _buildSpeedRow(),
                                ],
                              ),
                              SizedBox(height: 10.h),
                              Divider(color: Colors.white10),
                              if (_hasQueue) SizedBox(height: 12.h),
                              if (_hasQueue) _buildQueueButton(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fileExtensionLabel(String path) {
    final ext = path.split('.').last.toUpperCase();
    return 'Format: $ext';
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

  Widget _buildAudioHero() {
    return StreamBuilder<SequenceState?>(
      stream: _audioPlayer?.sequenceStateStream,
      builder: (context, snapshot) {
        final tag = snapshot.data?.currentSource?.tag;
        final artUri = tag is audio_service.MediaItem
            ? tag.artUri
            : _resolveArtUri(widget.coverPath, widget.coverUrl);
        ImageProvider? coverImage;
        if (artUri != null) {
          coverImage = artUri.isScheme('file')
              ? FileImage(File(artUri.toFilePath()))
              : NetworkImage(artUri.toString());
        }

        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + (_pulseController.value * 0.04);
            final glow = 0.2 + (_pulseController.value * 0.35);
            final angle = _pulseController.value * math.pi * 0.04;
            return Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: angle,
                child: _AudioArtwork(
                  title: widget.title,
                  glow: glow,
                  coverImage: coverImage,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAudioTitle() {
    final player = _audioPlayer;
    if (!_hasQueue || player == null) {
      return Text(
        widget.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return StreamBuilder<SequenceState?>(
      stream: player.sequenceStateStream,
      builder: (context, snapshot) {
        final tag = snapshot.data?.currentSource?.tag;
        final title = tag is audio_service.MediaItem
            ? tag.title
            : tag?.toString() ?? widget.title;
        return Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }

  Widget _buildAudioProgress() {
    final player = _audioPlayer;
    if (player == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            return StreamBuilder<Duration>(
              stream: player.bufferedPositionStream,
              builder: (context, bufferedSnapshot) {
                final buffered = bufferedSnapshot.data ?? Duration.zero;
                final max = duration.inMilliseconds
                    .toDouble()
                    .clamp(1.0, double.infinity)
                    .toDouble();
                final current = position.inMilliseconds
                    .toDouble()
                    .clamp(0.0, max)
                    .toDouble();
                final bufferedValue = buffered.inMilliseconds
                    .toDouble()
                    .clamp(0.0, max)
                    .toDouble();
                final remaining = duration - position;

                return Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: _ytSurface,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: LinearProgressIndicator(
                              value: bufferedValue / max,
                              minHeight: 4.h,
                              backgroundColor: Colors.white12,
                              color: Colors.white38,
                            ),
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: _ytRed,
                              inactiveTrackColor: Colors.transparent,
                              thumbColor: _ytRed,
                              overlayColor: _ytRed.withOpacity(0.2),
                              trackHeight: 3.h,
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: 6.r,
                              ),
                            ),
                            child: Slider(
                              value: current,
                              max: max,
                              onChanged: (value) {
                                player.seek(
                                  Duration(milliseconds: value.round()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.sp,
                            ),
                          ),
                          Text(
                            '-${_formatDuration(remaining)}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildQueuePreview() {
    final player = _audioPlayer;
    if (player == null || !_hasQueue) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<int?>(
      stream: player.currentIndexStream,
      builder: (context, snapshot) {
        final currentIndex = snapshot.data ?? widget.initialIndex;
        final nextItems = <Map<String, String>>[];
        for (
          var i = currentIndex + 1;
          i < _audioQueue.length && nextItems.length < 2;
          i++
        ) {
          nextItems.add(_audioQueue[i]);
        }
        if (nextItems.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: _ytSurface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'التالي في القائمة',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              ...nextItems.asMap().entries.map((entry) {
                final item = entry.value;
                final targetIndex = currentIndex + entry.key + 1;
                return InkWell(
                  onTap: () {
                    player.seek(Duration.zero, index: targetIndex);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    child: Row(
                      children: [
                        Icon(
                          Icons.music_note_rounded,
                          color: Colors.white54,
                          size: 16.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            item['title'] ?? 'Audio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white54,
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQueueButton() {
    return InkWell(
      onTap: _showQueueSheet,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music_rounded, color: Colors.white, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              'عرض قائمة التشغيل',
              style: TextStyle(color: Colors.white, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }

  void _showQueueSheet() {
    final player = _audioPlayer;
    if (player == null || !_hasQueue) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: _ytSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            border: Border.all(color: Colors.white12),
          ),
          child: StreamBuilder<int?>(
            stream: player.currentIndexStream,
            builder: (context, snapshot) {
              final currentIndex = snapshot.data ?? widget.initialIndex;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'قائمة التشغيل',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    height: 280.h,
                    child: ListView.separated(
                      itemCount: _audioQueue.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 16.h, color: Colors.white12),
                      itemBuilder: (context, index) {
                        final item = _audioQueue[index];
                        final isActive = index == currentIndex;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            isActive
                                ? Icons.play_circle_fill_rounded
                                : Icons.music_note_rounded,
                            color: isActive ? _ytRed : Colors.white70,
                          ),
                          title: Text(
                            item['title'] ?? 'Audio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            player.seek(Duration.zero, index: index);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaybackControls({required bool isAudio}) {
    if (isAudio) {
      final player = _audioPlayer;
      return StreamBuilder<PlayerState>(
        stream: player?.playerStateStream,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final isPlaying = state?.playing ?? false;
          final isBusy =
              state?.processingState == ProcessingState.loading ||
              state?.processingState == ProcessingState.buffering;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_hasQueue)
                _ControlButton(
                  icon: Icons.skip_previous_rounded,
                  onTap: _playPrevious,
                ),
              if (_hasQueue) SizedBox(width: 12.w),
              _ControlButton(
                icon: Icons.replay_10_rounded,
                onTap: () => _seekBy(const Duration(seconds: -10)),
              ),
              SizedBox(width: 20.w),
              _PlayButton(
                isPlaying: isPlaying,
                onTap: isBusy ? () {} : _togglePlayback,
                isLoading: isBusy,
              ),
              SizedBox(width: 20.w),
              _ControlButton(
                icon: Icons.forward_10_rounded,
                onTap: () => _seekBy(const Duration(seconds: 10)),
              ),
              if (_hasQueue) SizedBox(width: 12.w),
              if (_hasQueue)
                _ControlButton(
                  icon: Icons.skip_next_rounded,
                  onTap: _skipToNext,
                ),
            ],
          );
        },
      );
    }

    final videoPlaying = _videoController?.value.isPlaying ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: Icons.replay_10_rounded,
          onTap: () => _seekBy(const Duration(seconds: -10)),
        ),
        SizedBox(width: 20.w),
        _PlayButton(isPlaying: videoPlaying, onTap: _togglePlayback),
        SizedBox(width: 20.w),
        _ControlButton(
          icon: Icons.forward_10_rounded,
          onTap: () => _seekBy(const Duration(seconds: 10)),
        ),
      ],
    );
  }

  Widget _buildAudioModeRow() {
    final player = _audioPlayer;
    if (player == null) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_hasQueue)
          StreamBuilder<bool>(
            stream: player.shuffleModeEnabledStream,
            builder: (context, snapshot) {
              final enabled = snapshot.data ?? player.shuffleModeEnabled;
              return _ModeButton(
                icon: enabled
                    ? Icons.shuffle_on_rounded
                    : Icons.shuffle_rounded,
                label: 'عشوائي',
                isActive: enabled,
                onTap: _toggleShuffle,
              );
            },
          ),
        if (_hasQueue) SizedBox(width: 16.w),
        StreamBuilder<LoopMode>(
          stream: player.loopModeStream,
          builder: (context, snapshot) {
            final mode = snapshot.data ?? player.loopMode;
            final icon = mode == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded;
            final label = mode == LoopMode.off
                ? 'تكرار'
                : (mode == LoopMode.one ? 'تكرار واحد' : 'تكرار الكل');
            return _ModeButton(
              icon: icon,
              label: label,
              isActive: mode != LoopMode.off,
              onTap: _cycleLoopMode,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSpeedRow() {
    return Align(
      alignment: Alignment.center,
      child: InkWell(
        onTap: _cycleSpeed,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            'Speed ${_playbackSpeed.toStringAsFixed(2)}x',
            style: TextStyle(color: Colors.white70, fontSize: 11.sp),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isActive ? _ytRed.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: isActive ? _ytRed : Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18.sp),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AnimatedBars extends StatelessWidget {
  final Animation<double> animation;

  const _AnimatedBars({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value * math.pi * 2;
        final heights = [
          8 + 14 * (0.5 + 0.5 * math.sin(t)),
          8 + 20 * (0.5 + 0.5 * math.sin(t + 1.2)),
          8 + 16 * (0.5 + 0.5 * math.sin(t + 2.4)),
          8 + 22 * (0.5 + 0.5 * math.sin(t + 3.2)),
        ];
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: heights
              .map(
                (height) => Container(
                  width: 6.w,
                  height: height,
                  margin: EdgeInsets.symmetric(horizontal: 3.w),
                  decoration: BoxDecoration(
                    color: _ytRed,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SpeedChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 10.sp),
        ),
      ),
    );
  }
}

class _AudioArtwork extends StatelessWidget {
  final String title;
  final double glow;
  final ImageProvider? coverImage;

  const _AudioArtwork({
    required this.title,
    required this.glow,
    required this.coverImage,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      child: Container(
        width: 210.w,
        height: 210.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFFF8A80), Color(0xFFB71C1C)],
            center: Alignment(-0.2, -0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withOpacity(glow),
              blurRadius: 60,
              spreadRadius: 6,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 170.w,
              height: 170.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white12),
              ),
            ),
            Container(
              width: 110.w,
              height: 110.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.4),
                border: Border.all(color: Colors.white24),
                image: coverImage == null
                    ? null
                    : DecorationImage(image: coverImage!, fit: BoxFit.cover),
              ),
              child: coverImage == null
                  ? Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 54.sp,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.25),
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: Colors.white70,
                        size: 40.sp,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30.r),
      child: Container(
        width: 46.w,
        height: 46.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white10,
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 24.sp),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final bool isLoading;

  const _PlayButton({
    required this.isPlaying,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40.r),
      child: Container(
        width: 72.w,
        height: 72.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: isLoading
            ? SizedBox(
                width: 24.w,
                height: 24.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 34.sp,
              ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: _ytSurface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 18.sp),
      ),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBubble({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 20)],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: _ytSurface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.white70,
              size: 32.sp,
            ),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }
}
