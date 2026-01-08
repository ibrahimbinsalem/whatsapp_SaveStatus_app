import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart' hide Trans;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../controllers/youtube_controller.dart';
import '../models/video_format.dart';

class YoutubeScreen extends StatelessWidget {
  const YoutubeScreen({super.key});

  static const Color _ytRed = Color(0xFFE53935);
  static const Color _ytDark = Color(0xFF0F0F0F);
  static const Color _ytSurface = Color(0xFF1C1C1C);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<YoutubeController>(
      init: YoutubeController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: YoutubeScreen._ytDark,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F0F0F), Color(0xFF1A1A1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                top: -120,
                right: -80,
                child: _GlowBubble(
                  size: 220,
                  color: YoutubeScreen._ytRed.withOpacity(0.18),
                ),
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
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopBar(
                        onDownloadsPressed: () =>
                            controller.navigateToDownloads(context),
                      ),
                      SizedBox(height: 18.h),
                      _HeroCard(),
                      SizedBox(height: 16.h),
                      _InputCard(
                        urlController: controller.urlController,
                        onPastePressed: controller.pasteFromClipboard,
                        onPreparePressed: controller.getVideoInfo,
                        isLoading: controller.isLoading,
                      ),
                      if (controller.currentVideo != null) ...[
                        SizedBox(height: 16.h),
                        _VideoInfoCard(
                          video: controller.currentVideo!,
                          duration: controller
                              .formatDuration(controller.currentVideo!.duration),
                        ),
                      ],
                      if (controller.availableFormats
                          .any((f) => !f.isAudioOnly)) ...[
                        SizedBox(height: 20.h),
                        _FormatsRow(
                          formats: controller.availableFormats
                              .where((f) => !f.isAudioOnly)
                              .toList(),
                          selectedFormatId: controller.selectedFormatId,
                          onFormatSelected: controller.selectFormat,
                          onDownloadPressed: controller.selectedFormatId != null
                              ? () => controller.downloadVideo(
                                    context,
                                    controller.selectedFormatId!,
                                  )
                              : null,
                          onCancel: controller.isDownloading
                              ? controller.cancelDownload
                              : null,
                          isDownloading: controller.isDownloading,
                          downloadProgress: controller.downloadProgress,
                          downloadStatus: controller.downloadStatus,
                          formatFileSize: controller.formatFileSize,
                        ),
                      ],

                      /*
                      SizedBox(height: 20.h),
                      _SectionHeader(title: 'yt_section_recent'.tr()),
                      SizedBox(height: 10.h),

                      // عرض التحميلات الحديثة
                      if (controller.downloadHistory.isNotEmpty)
                        _RecentDownloadsList(
                          recentDownloads:
                              controller.downloadHistory.take(3).toList(),
                        )
                      else
                        _EmptyState(
                          title: 'yt_empty_recent'.tr(),
                          subtitle: 'yt_subtitle'.tr(),
                        ),
                      */
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onDownloadsPressed;

  const _TopBar({required this.onDownloadsPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: YoutubeScreen._ytRed,
            size: 28.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'yt_title'.tr(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'yt_tagline'.tr(),
                style: TextStyle(color: Colors.white70, fontSize: 11.sp),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onDownloadsPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          icon: Icon(
            Icons.download_done_rounded,
            color: Colors.white,
            size: 24.sp,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [YoutubeScreen._ytRed, Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: YoutubeScreen._ytRed.withOpacity(0.35),
            blurRadius: 24.r,
            offset: Offset(0, 12.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'yt_title'.tr(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'yt_subtitle'.tr(),
            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              _ActionChip(
                text: 'yt_format_video'.tr(),
                icon: Icons.movie_creation_outlined,
              ),
              SizedBox(width: 10.w),
              _ActionChip(
                text: 'yt_format_audio'.tr(),
                icon: Icons.audiotrack_rounded,
              ),
              SizedBox(width: 10.w),
              _ActionChip(
                text: 'yt_format_playlist'.tr(),
                icon: Icons.queue_music_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final TextEditingController urlController;
  final VoidCallback onPastePressed;
  final VoidCallback onPreparePressed;
  final bool isLoading;

  const _InputCard({
    required this.urlController,
    required this.onPastePressed,
    required this.onPreparePressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: YoutubeScreen._ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          TextField(
            controller: urlController,
            decoration: InputDecoration(
              hintText: 'yt_input_hint'.tr(),
              hintStyle: TextStyle(color: Colors.white54, fontSize: 12.sp),
              prefixIcon: Icon(
                Icons.link_rounded,
                color: Colors.white54,
                size: 18.sp,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPastePressed,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    'yt_action_paste'.tr(),
                    style: TextStyle(fontSize: 12.sp),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : onPreparePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: YoutubeScreen._ytRed,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'yt_action_prepare'.tr(),
                          style: TextStyle(fontSize: 12.sp),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VideoInfoCard extends StatelessWidget {
  final Video video;
  final String duration;

  const _VideoInfoCard({required this.video, required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: YoutubeScreen._ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 80.w,
                height: 60.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  image: DecorationImage(
                    image: NetworkImage(video.thumbnails.mediumResUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 4.h,
                right: 4.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    duration,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 4.h),
                Text(
                  '${video.author} • ${video.engagement.viewCount.formatViews()} views',
                  style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatsRow extends StatelessWidget {
  final List<VideoFormat> formats;
  final String? selectedFormatId;
  final Function(String) onFormatSelected;
  final VoidCallback? onDownloadPressed;
  final VoidCallback? onCancel;
  final bool isDownloading;
  final double downloadProgress;
  final String downloadStatus;
  final String Function(int) formatFileSize;

  const _FormatsRow({
    required this.formats,
    required this.selectedFormatId,
    required this.onFormatSelected,
    required this.onDownloadPressed,
    this.onCancel,
    required this.isDownloading,
    required this.downloadProgress,
    required this.downloadStatus,
    required this.formatFileSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: YoutubeScreen._ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'yt_section_formats'.tr()),
          SizedBox(height: 10.h),

          // عرض تقدم التحميل إذا كان قيد التنفيذ
          if (isDownloading) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: downloadProgress,
                              backgroundColor: Colors.white12,
                              color: YoutubeScreen._ytRed,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              downloadStatus,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      IconButton(
                        onPressed: onCancel,
                        icon: const Icon(
                          Icons.stop_circle_rounded,
                          color: YoutubeScreen._ytRed,
                        ),
                        tooltip: 'إيقاف التحميل',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
          ],

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
              childAspectRatio: 3.0,
            ),
            itemCount: formats.length,
            itemBuilder: (context, index) {
              final format = formats[index];
              final isSelected = selectedFormatId == format.id;
              return GestureDetector(
                onTap: () => onFormatSelected(format.id),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? YoutubeScreen._ytRed.withOpacity(0.2)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSelected ? YoutubeScreen._ytRed : Colors.white12,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        format.icon,
                        color: isSelected ? Colors.white : Colors.white70,
                        size: 16.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              format.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 10.sp,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (format.size > 0)
                              Text(
                                formatFileSize(format.size),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.white54,
                                  fontSize: 8.sp,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // زر التحميل
          if (selectedFormatId != null && !isDownloading) ...[
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDownloadPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: YoutubeScreen._ytRed,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_rounded, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'yt_action_download'.tr(),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentDownloadsList extends StatelessWidget {
  final List<Map<String, dynamic>> recentDownloads;

  const _RecentDownloadsList({required this.recentDownloads});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: recentDownloads
          .map(
            (download) => Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: YoutubeScreen._ytSurface,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(
                    download['type'] == 'audio'
                        ? Icons.music_note_rounded
                        : Icons.videocam_rounded,
                    color: download['type'] == 'audio'
                        ? Colors.green
                        : YoutubeScreen._ytRed,
                    size: 18.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      download['title'] ?? '',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.sp,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 18.sp,
                      color: Colors.white54,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: YoutubeScreen._ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            color: Colors.white54,
            size: 28.sp,
          ),
          SizedBox(height: 10.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 13.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String text;
  final IconData icon;

  const _ActionChip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14.sp),
          SizedBox(width: 6.w),
          Text(
            text,
            style: TextStyle(color: Colors.white, fontSize: 11.sp),
          ),
        ],
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

// امتداد لتنسيق عرض المشاهدات
extension ViewCountExtension on int {
  String formatViews() {
    if (this < 1000) return toString();
    if (this < 1000000) return '${(this / 1000).toStringAsFixed(1)}K';
    if (this < 1000000000) return '${(this / 1000000).toStringAsFixed(1)}M';
    return '${(this / 1000000000).toStringAsFixed(1)}B';
  }
}

class _FormatTypeSelector extends StatelessWidget {
  final String selectedType;
  final Function(String) onTypeChanged;

  const _FormatTypeSelector({
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: YoutubeScreen._ytSurface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeButton(
              title: 'yt_format_video'.tr(),
              icon: Icons.videocam_rounded,
              isSelected: selectedType == 'video',
              onTap: () => onTypeChanged('video'),
            ),
          ),
          Expanded(
            child: _TypeButton(
              title: 'yt_format_audio'.tr(),
              icon: Icons.audiotrack_rounded,
              isSelected: selectedType == 'audio',
              onTap: () => onTypeChanged('audio'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? YoutubeScreen._ytRed : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white54,
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
