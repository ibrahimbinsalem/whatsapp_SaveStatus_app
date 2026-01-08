import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart' hide Trans;

import '../../../core/theme/colors.dart';
import '../../statuses/status_media.dart';
import '../../statuses/widgets/status_media_widgets.dart';
import '../controllers/favorites_controller.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final FavoritesController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(FavoritesController());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.loadSaved();
  }

  @override
  void dispose() {
    Get.delete<FavoritesController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FavoritesController>(
      builder: (controller) {
        final filteredItems = controller.applyFilters(controller.items);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('status_favorites_title'.tr()),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: AppColors.textPrimary,
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.mistGradient,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 16.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FavoritesFilterBar(
                        controller: controller.searchController,
                        onChanged: controller.updateSearch,
                        onClear: controller.clearSearch,
                        sortNewest: controller.sortNewest,
                        onToggleSort: controller.toggleSort,
                        onRefresh: controller.loadFavorites,
                      ),
                      SizedBox(height: 10.h),
                      _FilterChips(
                        value: controller.filter,
                        onChanged: controller.setFilter,
                      ),
                      SizedBox(height: 16.h),
                      Expanded(
                        child: _FavoritesGrid(
                          items: filteredItems,
                          isLoading: controller.loading,
                          onSave: (item) =>
                              controller.saveToGallery(context, item),
                          onShare: (item) =>
                              controller.shareItem(context, item),
                          onCopy: (item) => controller.copyPath(context, item),
                          onDelete: (item) =>
                              controller.deleteItem(context, item),
                          onToggleFavorite: controller.toggleFavorite,
                          isFavorite: controller.isFavorite,
                          canDelete: controller.repository.isSavedMediaPath,
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

class _FavoritesFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool sortNewest;
  final VoidCallback onToggleSort;
  final VoidCallback onRefresh;

  const _FavoritesFilterBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.sortNewest,
    required this.onToggleSort,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'status_search_hint'.tr(),
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                  size: 18.sp,
                ),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                          size: 18.sp,
                        ),
                        onPressed: onClear,
                      ),
                border: InputBorder.none,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          _FilterIconButton(
            icon: sortNewest ? Icons.south_rounded : Icons.north_rounded,
            tooltip: sortNewest
                ? 'status_sort_latest'.tr()
                : 'status_sort_oldest'.tr(),
            onTap: onToggleSort,
          ),
          SizedBox(width: 6.w),
          _FilterIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'retry'.tr(),
            onTap: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _FilterIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 18.sp),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final FavoriteFilter value;
  final ValueChanged<FavoriteFilter> onChanged;

  const _FilterChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      children: [
        ChoiceChip(
          label: Text('status_filter_all'.tr()),
          selected: value == FavoriteFilter.all,
          onSelected: (_) => onChanged(FavoriteFilter.all),
        ),
        ChoiceChip(
          label: Text('status_filter_photos'.tr()),
          selected: value == FavoriteFilter.photos,
          onSelected: (_) => onChanged(FavoriteFilter.photos),
        ),
        ChoiceChip(
          label: Text('status_filter_videos'.tr()),
          selected: value == FavoriteFilter.videos,
          onSelected: (_) => onChanged(FavoriteFilter.videos),
        ),
      ],
    );
  }
}

class _FavoritesGrid extends StatelessWidget {
  final List<StatusMedia> items;
  final bool isLoading;
  final ValueChanged<StatusMedia> onSave;
  final ValueChanged<StatusMedia> onShare;
  final ValueChanged<StatusMedia> onCopy;
  final ValueChanged<StatusMedia> onDelete;
  final ValueChanged<StatusMedia> onToggleFavorite;
  final bool Function(StatusMedia) isFavorite;
  final bool Function(String path) canDelete;

  const _FavoritesGrid({
    required this.items,
    required this.isLoading,
    required this.onSave,
    required this.onShare,
    required this.onCopy,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.isFavorite,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (items.isEmpty) {
      return _EmptyFavoritesState(
        title: 'status_favorites_empty'.tr(),
        subtitle: 'status_tabs_hint'.tr(),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 760 ? 3 : 4;

    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => StatusPreviewSheet.show(
            context,
            item,
            onSave: onSave,
            onShare: onShare,
            onCopy: onCopy,
            onDelete: onDelete,
            onToggleFavorite: onToggleFavorite,
            isFavorite: isFavorite(item),
            canDelete: canDelete(item.path),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10.r,
                  offset: Offset(0, 6.h),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: item.isVideo
                        ? StatusVideoThumb(path: item.path)
                        : Image.file(
                            File(item.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const StatusVideoPlaceholder();
                            },
                          ),
                  ),
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: _FavoriteOverlay(
                      isFavorite: isFavorite(item),
                      onTap: () => onToggleFavorite(item),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteOverlay extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;

  const _FavoriteOverlay({required this.isFavorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28.w,
        height: 28.w,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
          color: isFavorite ? AppColors.accent : AppColors.textSecondary,
          size: 16.sp,
        ),
      ),
    );
  }
}

class _EmptyFavoritesState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyFavoritesState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_border_rounded,
            color: AppColors.primary.withOpacity(0.6),
            size: 28.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
