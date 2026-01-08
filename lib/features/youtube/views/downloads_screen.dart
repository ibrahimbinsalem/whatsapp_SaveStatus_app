import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../controllers/downloads_controller.dart';
import 'local_video_player_screen.dart';

const Color _ytRed = Color(0xFFE53935);
const Color _ytDark = Color(0xFF0F0F0F);
const Color _ytSurface = Color(0xFF1C1C1C);

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DownloadsController>(
      init: DownloadsController(),
      builder: (controller) {
        controller.setContext(context);
        final filtered = controller.filteredDownloads;
        return Scaffold(
          backgroundColor: _ytDark,
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
                child: RefreshIndicator(
                  color: _ytRed,
                  onRefresh: controller.loadDownloadHistory,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 16.h,
                          ),
                          child: _Header(
                            totalCount: controller.downloadHistory.length,
                            onBack: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: _SummaryCard(
                            total: controller.downloadHistory.length,
                            videos: controller.videoCount,
                            audios: controller.audioCount,
                            lastDownload: controller.lastDownloadLabel(),
                            totalSize: controller.formatBytes(controller.totalBytes),
                            onClearAll: controller.downloadHistory.isEmpty
                                ? null
                                : controller.clearAllDownloads,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: _PermissionsCard(
                            isLoading: controller.permissionLoading,
                            storage: controller.storageStatus,
                            manage: controller.manageStatus,
                            notification: controller.notificationStatus,
                            onOpenSettings: openAppSettings,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: _SearchBar(
                            controller: controller.searchController,
                            onChanged: controller.updateSearch,
                            onClear: controller.clearSearch,
                            onSortChanged: controller.setSort,
                            selectedSort: controller.selectedSort,
                            onFilterTap: controller.showAdvancedFilterSheet,
                            hasActiveFilters: controller.hasActiveAdvancedFilters,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: _FilterRow(
                            selected: controller.selectedFilter,
                            onChanged: controller.setFilter,
                            total: controller.downloadHistory.length,
                            videos: controller.videoCount,
                            audios: controller.audioCount,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: 12.h)),
                      if (controller.audioCount > 0)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: _PlaylistModeToggle(
                              mode: controller.playlistMode,
                              onChanged: controller.setPlaylistMode,
                            ),
                          ),
                        ),
                      if (controller.audioCount > 0)
                        SliverToBoxAdapter(
                          child: SizedBox(height: 12.h),
                        ),
                      if (controller.audioCount > 0)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: _PlayAllButton(
                              onTap: controller.openAudioPlayer,
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              childCount: filtered.length,
                              (context, index) {
                                final item = filtered[index];
                                final isAudio = item['type'] == 'audio';
                                final path = item['path']?.toString() ?? '';
                                final isFavorite =
                                    controller.isFavoritePath(path);
                                final playCount = controller.playCountFor(path);
                                return _DownloadCard(
                                  item: item,
                                  isAudio: isAudio,
                                  leading: isAudio
                                      ? _MediaIcon(isAudio: true)
                                      : FutureBuilder<String?>(
                                          future: controller.loadThumbnail(path),
                                          builder: (context, snapshot) {
                                            final thumbPath = snapshot.data;
                                            if (thumbPath != null &&
                                                File(thumbPath).existsSync()) {
                                              return _VideoThumb(
                                                  path: thumbPath);
                                            }
                                            return _MediaIcon(isAudio: false);
                                          },
                                        ),
                                  onTap: () {
                                    if (isAudio) {
                                      controller.openAudioPlayer(
                                        path: item['path'],
                                      );
                                    } else {
                                      controller.registerPlay(path);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              LocalVideoPlayerScreen(
                                            filePath: item['path'],
                                            title: item['title'],
                                            coverUrl: item['thumbUrl'],
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onActionSelected: (action) {
                                    switch (action) {
                                      case DownloadAction.details:
                                        controller.showDetails(item);
                                        break;
                                      case DownloadAction.rename:
                                        controller.renameItem(item);
                                        break;
                                      case DownloadAction.convertMp3:
                                        controller.convertToMp3(item);
                                        break;
                                      case DownloadAction.delete:
                                        controller.deleteItem(index);
                                        break;
                                    }
                                  },
                                  onDelete: () => controller.deleteItem(index),
                                  dateLabel: controller.formatDateLabel(
                                    item['date']?.toString(),
                                  ),
                                  isFavorite: isFavorite,
                                  onToggleFavorite: () =>
                                      controller.toggleFavorite(item),
                                  playCount: playCount,
                                  onShare: () => controller.shareItem(item),
                                );
                              },
                            ),
                          ),
                        ),
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

class _Header extends StatelessWidget {
  final int totalCount;
  final VoidCallback onBack;

  const _Header({required this.totalCount, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconCircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سجل التنزيلات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'كل ملفاتك المحفوظة في مكان واحد',
                style: TextStyle(color: Colors.white70, fontSize: 12.sp),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            '$totalCount عنصر',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final int videos;
  final int audios;
  final String lastDownload;
  final String totalSize;
  final VoidCallback? onClearAll;

  const _SummaryCard({
    required this.total,
    required this.videos,
    required this.audios,
    required this.lastDownload,
    required this.totalSize,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SummaryStat(label: 'الإجمالي', value: '$total', color: _ytRed),
              SizedBox(width: 12.w),
              _SummaryStat(
                label: 'فيديو',
                value: '$videos',
                color: Colors.blueAccent,
              ),
              SizedBox(width: 12.w),
              _SummaryStat(
                label: 'صوت',
                value: '$audios',
                color: Colors.greenAccent,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: Colors.white70,
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'آخر تنزيل: $lastDownload',
                          style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.storage_rounded, color: Colors.white70, size: 18.sp),
                    SizedBox(width: 6.w),
                    Text(
                      totalSize,
                      style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onClearAll,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white24),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text(
                'تنظيف كل التنزيلات',
                style: TextStyle(fontSize: 12.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
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

class _PermissionsCard extends StatelessWidget {
  final bool isLoading;
  final PermissionStatus storage;
  final PermissionStatus manage;
  final PermissionStatus notification;
  final VoidCallback onOpenSettings;

  const _PermissionsCard({
    required this.isLoading,
    required this.storage,
    required this.manage,
    required this.notification,
    required this.onOpenSettings,
  });

  String _statusLabel(PermissionStatus status) {
    if (status.isGranted) {
      return 'مفعل';
    }
    if (status.isPermanentlyDenied) {
      return 'مرفوض نهائيًا';
    }
    return 'غير مفعل';
  }

  Color _statusColor(PermissionStatus status) {
    if (status.isGranted) {
      return Colors.greenAccent;
    }
    if (status.isPermanentlyDenied) {
      return Colors.redAccent;
    }
    return Colors.orangeAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الأذونات والإرشادات',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'تأكد من تفعيل صلاحيات التخزين والتنبيهات حتى تعمل التنزيلات بسلاسة.',
            style: TextStyle(color: Colors.white70, fontSize: 11.sp),
          ),
          SizedBox(height: 12.h),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: _ytRed, strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _PermissionPill(
                  label: 'التخزين',
                  status: _statusLabel(storage),
                  color: _statusColor(storage),
                ),
                _PermissionPill(
                  label: 'إدارة التخزين',
                  status: _statusLabel(manage),
                  color: _statusColor(manage),
                ),
                _PermissionPill(
                  label: 'الإشعارات',
                  status: _statusLabel(notification),
                  color: _statusColor(notification),
                ),
              ],
            ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenSettings,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white24),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: Text(
                'فتح إعدادات الصلاحيات',
                style: TextStyle(fontSize: 12.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionPill extends StatelessWidget {
  final String label;
  final String status;
  final Color color;

  const _PermissionPill({
    required this.label,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8.sp),
          SizedBox(width: 6.w),
          Text(
            '$label: $status',
            style: TextStyle(color: Colors.white70, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<DownloadSort> onSortChanged;
  final DownloadSort selectedSort;
  final VoidCallback onFilterTap;
  final bool hasActiveFilters;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onSortChanged,
    required this.selectedSort,
    required this.onFilterTap,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ابحث في التنزيلات',
              hintStyle: TextStyle(color: Colors.white54, fontSize: 12.sp),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: onClear,
                    ),
              filled: true,
              fillColor: _ytSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: _ytRed),
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        _FilterButton(
          onTap: onFilterTap,
          isActive: hasActiveFilters,
        ),
        SizedBox(width: 10.w),
        _SortMenuButton(
          selectedSort: selectedSort,
          onSelected: onSortChanged,
        ),
      ],
    );
  }
}

class _SortMenuButton extends StatelessWidget {
  final DownloadSort selectedSort;
  final ValueChanged<DownloadSort> onSelected;

  const _SortMenuButton({
    required this.selectedSort,
    required this.onSelected,
  });

  String _labelForSort(DownloadSort sort) {
    switch (sort) {
      case DownloadSort.oldest:
        return 'الأقدم';
      case DownloadSort.sizeDesc:
        return 'الأكبر';
      case DownloadSort.sizeAsc:
        return 'الأصغر';
      case DownloadSort.nameAsc:
        return 'A-Z';
      case DownloadSort.nameDesc:
        return 'Z-A';
      case DownloadSort.newest:
      default:
        return 'الأحدث';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DownloadSort>(
      onSelected: onSelected,
      color: _ytSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: const BorderSide(color: Colors.white12),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: DownloadSort.newest,
          child: _MenuRow(icon: Icons.schedule, text: 'الأحدث'),
        ),
        PopupMenuItem(
          value: DownloadSort.oldest,
          child: _MenuRow(icon: Icons.history_toggle_off, text: 'الأقدم'),
        ),
        PopupMenuItem(
          value: DownloadSort.sizeDesc,
          child: _MenuRow(icon: Icons.arrow_downward, text: 'الأكبر'),
        ),
        PopupMenuItem(
          value: DownloadSort.sizeAsc,
          child: _MenuRow(icon: Icons.arrow_upward, text: 'الأصغر'),
        ),
        PopupMenuItem(
          value: DownloadSort.nameAsc,
          child: _MenuRow(icon: Icons.sort_by_alpha, text: 'A-Z'),
        ),
        PopupMenuItem(
          value: DownloadSort.nameDesc,
          child: _MenuRow(icon: Icons.sort_by_alpha, text: 'Z-A'),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: _ytSurface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Icon(Icons.tune_rounded, color: Colors.white, size: 18.sp),
            SizedBox(height: 4.h),
            Text(
              _labelForSort(selectedSort),
              style: TextStyle(color: Colors.white70, fontSize: 9.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;

  const _FilterButton({required this.onTap, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isActive ? _ytRed.withOpacity(0.2) : _ytSurface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isActive ? _ytRed : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_rounded,
              color: Colors.white,
              size: 18.sp,
            ),
            SizedBox(height: 4.h),
            Text(
              'فلتر',
              style: TextStyle(color: Colors.white70, fontSize: 9.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final DownloadFilter selected;
  final ValueChanged<DownloadFilter> onChanged;
  final int total;
  final int videos;
  final int audios;

  const _FilterRow({
    required this.selected,
    required this.onChanged,
    required this.total,
    required this.videos,
    required this.audios,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'الكل',
          count: total,
          isSelected: selected == DownloadFilter.all,
          onTap: () => onChanged(DownloadFilter.all),
        ),
        SizedBox(width: 10.w),
        _FilterChip(
          label: 'فيديو',
          count: videos,
          isSelected: selected == DownloadFilter.video,
          onTap: () => onChanged(DownloadFilter.video),
        ),
        SizedBox(width: 10.w),
        _FilterChip(
          label: 'صوت',
          count: audios,
          isSelected: selected == DownloadFilter.audio,
          onTap: () => onChanged(DownloadFilter.audio),
        ),
      ],
    );
  }
}

class _PlaylistModeToggle extends StatelessWidget {
  final AudioPlaylistMode mode;
  final ValueChanged<AudioPlaylistMode> onChanged;

  const _PlaylistModeToggle({
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PlaylistButton(
            label: 'الأحدث',
            isActive: mode == AudioPlaylistMode.latest,
            onTap: () => onChanged(AudioPlaylistMode.latest),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _PlaylistButton(
            label: 'الأكثر تشغيلًا',
            isActive: mode == AudioPlaylistMode.mostPlayed,
            onTap: () => onChanged(AudioPlaylistMode.mostPlayed),
          ),
        ),
      ],
    );
  }
}

class _PlaylistButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PlaylistButton({
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
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isActive ? _ytRed.withOpacity(0.2) : _ytSurface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: isActive ? _ytRed : Colors.white12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayAllButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.queue_music_rounded, color: Colors.white),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تشغيل كل المقاطع الصوتية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'قائمة تشغيل تلقائية من مكتبة الصوت',
                  style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('تشغيل'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? _ytRed.withOpacity(0.2) : _ytSurface,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: isSelected ? _ytRed : Colors.white12),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '$count',
                style: TextStyle(color: Colors.white70, fontSize: 10.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isAudio;
  final Widget leading;
  final VoidCallback onTap;
  final ValueChanged<DownloadAction> onActionSelected;
  final VoidCallback onDelete;
  final String dateLabel;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final int playCount;
  final VoidCallback onShare;

  const _DownloadCard({
    required this.item,
    required this.isAudio,
    required this.leading,
    required this.onTap,
    required this.onActionSelected,
    required this.onDelete,
    required this.dateLabel,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.playCount,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isAudio ? Colors.greenAccent : _ytRed;
    final title = (item['title'] ?? 'بدون عنوان').toString();
    final size = (item['size'] ?? '—').toString();
    final playsLabel = playCount > 0 ? 'تشغيل $playCount' : null;

    return Dismissible(
      key: ValueKey('${item['path'] ?? title}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white),
            SizedBox(width: 6.w),
            Text(
              'حذف',
              style: TextStyle(color: Colors.white, fontSize: 12.sp),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: _ytSurface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                leading,
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 6.h,
                        children: [
                          _MetaChip(
                            label: isAudio ? 'صوت' : 'فيديو',
                            color: accent,
                          ),
                          _MetaChip(label: size, color: Colors.white70),
                          if (playsLabel != null)
                            _MetaChip(label: playsLabel, color: Colors.white60),
                          _MetaChip(label: dateLabel, color: Colors.white54),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onShare,
                      icon: const Icon(Icons.share_rounded),
                      color: Colors.white70,
                      iconSize: 20.sp,
                    ),
                    IconButton(
                      onPressed: onToggleFavorite,
                      icon: Icon(
                        isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                      color: isFavorite ? Colors.amber : Colors.white70,
                      iconSize: 22.sp,
                    ),
                    _ActionMenuButton(onSelected: onActionSelected),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _FilterField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white54, fontSize: 12.sp),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: _ytRed),
        ),
      ),
    );
  }
}

class _FilterSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _ytRed,
          ),
        ],
      ),
    );
  }
}

class _ActionMenuButton extends StatelessWidget {
  final ValueChanged<DownloadAction> onSelected;

  const _ActionMenuButton({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DownloadAction>(
      onSelected: onSelected,
      color: _ytSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: const BorderSide(color: Colors.white12),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: DownloadAction.details,
          child: _MenuRow(icon: Icons.info_outline_rounded, text: 'تفاصيل'),
        ),
        PopupMenuItem(
          value: DownloadAction.rename,
          child: _MenuRow(icon: Icons.edit_rounded, text: 'إعادة تسمية'),
        ),
        PopupMenuItem(
          value: DownloadAction.convertMp3,
          child: _MenuRow(
            icon: Icons.music_note_rounded,
            text: 'تحويل إلى صوت',
          ),
        ),
        PopupMenuItem(
          value: DownloadAction.delete,
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            text: 'حذف',
            isDanger: true,
          ),
        ),
      ],
      child: Container(
        width: 34.w,
        height: 34.w,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(
          Icons.more_vert_rounded,
          color: Colors.white70,
          size: 18.sp,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDanger;

  const _MenuRow({
    required this.icon,
    required this.text,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.redAccent : Colors.white;
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: color),
        SizedBox(width: 8.w),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 12.sp),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white54, fontSize: 11.sp),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}

class _MediaIcon extends StatelessWidget {
  final bool isAudio;

  const _MediaIcon({required this.isAudio});

  @override
  Widget build(BuildContext context) {
    final accent = isAudio ? Colors.greenAccent : _ytRed;
    return Container(
      width: 46.w,
      height: 46.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withOpacity(0.15),
      ),
      child: Icon(
        isAudio ? Icons.music_note : Icons.videocam_rounded,
        color: accent,
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final String path;

  const _VideoThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 54.w,
        height: 54.w,
        color: Colors.white10,
        child: Image.file(File(path), fit: BoxFit.cover),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: _ytSurface,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.download_done_rounded,
                  size: 30.sp,
                  color: Colors.white54,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'لا توجد تنزيلات حتى الآن',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              Text(
                'ابدأ بتنزيل فيديو أو صوت ليظهر هنا السجل بالكامل',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.sp,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconCircleButton({required this.icon, required this.onTap});

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

class _MediaMeta {
  final String path;
  final int sizeBytes;
  final String extension;
  final Duration? duration;

  const _MediaMeta({
    required this.path,
    required this.sizeBytes,
    required this.extension,
    required this.duration,
  });
}
