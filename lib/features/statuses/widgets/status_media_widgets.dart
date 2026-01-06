import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../status_media.dart';
import '../status_media_repository.dart';

class StatusPreviewSheet {
  static void show(
    BuildContext context,
    StatusMedia item, {
    ValueChanged<StatusMedia>? onSave,
    ValueChanged<StatusMedia>? onShare,
    ValueChanged<StatusMedia>? onCopy,
    ValueChanged<StatusMedia>? onDelete,
    ValueChanged<StatusMedia>? onToggleFavorite,
    bool isFavorite = false,
    bool canDelete = false,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  height: 220.h,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: item.isVideo
                        ? StatusVideoPreviewPlayer(path: item.path)
                        : Image.file(
                            File(item.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const StatusVideoPlaceholder();
                            },
                          ),
                  ),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6.w,
                  runSpacing: 8.h,
                  children: [
                    StatusSheetAction(
                      icon: isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      label: 'status_action_favorite'.tr(),
                      onTap: () => onToggleFavorite?.call(item),
                    ),
                    StatusSheetAction(
                      icon: Icons.share_rounded,
                      label: 'status_action_share'.tr(),
                      onTap: () => onShare?.call(item),
                    ),
                    StatusSheetAction(
                      icon: Icons.link_rounded,
                      label: 'status_action_copy'.tr(),
                      onTap: () => onCopy?.call(item),
                    ),
                    if (canDelete)
                      StatusSheetAction(
                        icon: Icons.delete_outline,
                        label: 'status_action_delete'.tr(),
                        onTap: () {
                          Navigator.pop(context);
                          onDelete?.call(item);
                        },
                        isDestructive: true,
                      ),
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  item.isVideo
                      ? 'status_recent_item_video'.tr()
                      : 'status_recent_item_photo'.tr(),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'status_tabs_hint'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                if (onSave != null)
                  CustomButton(
                    text: 'status_action_save'.tr(),
                    onPressed: () {
                      onSave(item);
                      Navigator.pop(context);
                    },
                  ),
                if (onSave != null) SizedBox(height: 10.h),
                CustomButton(
                  text: 'done'.tr(),
                  onPressed: () => Navigator.pop(context),
                  isOutlined: true,
                ),
                SizedBox(height: 10.h),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StatusSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const StatusSheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          width: 72.w,
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isDestructive
                    ? Colors.redAccent
                    : AppColors.textPrimary,
                size: 20.sp,
              ),
              SizedBox(height: 4.h),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDestructive
                      ? Colors.redAccent
                      : AppColors.textSecondary,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusVideoThumb extends StatelessWidget {
  final String path;
  final bool showPlayIcon;

  const StatusVideoThumb({
    super.key,
    required this.path,
    this.showPlayIcon = true,
  });

  static final StatusMediaRepository _repository = StatusMediaRepository();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _repository.getVideoThumbnail(path),
      builder: (context, snapshot) {
        final file = snapshot.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (file != null)
              Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const StatusVideoPlaceholder();
                },
              )
            else
              const StatusVideoPlaceholder(),
            if (showPlayIcon)
              Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white.withOpacity(0.9),
                  size: 36.sp,
                ),
              ),
          ],
        );
      },
    );
  }
}

class StatusVideoPreviewPlayer extends StatefulWidget {
  final String path;

  const StatusVideoPreviewPlayer({super.key, required this.path});

  @override
  State<StatusVideoPreviewPlayer> createState() =>
      _StatusVideoPreviewPlayerState();
}

class _StatusVideoPreviewPlayerState extends State<StatusVideoPreviewPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant StatusVideoPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.file(File(widget.path));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _controller == null || !_controller!.value.isInitialized) {
      return const StatusVideoPlaceholder();
    }
    final controller = _controller!;
    return GestureDetector(
      onTap: _togglePlayback,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(10.w),
            child: Icon(
              controller.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 26.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusVideoPlaceholder extends StatelessWidget {
  const StatusVideoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.accent.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.videocam_rounded,
          color: AppColors.primary.withOpacity(0.6),
          size: 36.sp,
        ),
      ),
    );
  }
}
