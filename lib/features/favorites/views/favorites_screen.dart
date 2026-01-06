import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/colors.dart';
import '../../statuses/status_media.dart';
import '../../statuses/status_media_repository.dart';
import '../../statuses/widgets/status_media_widgets.dart';

enum _FavoriteFilter { all, photos, videos }

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final StatusMediaRepository _repository = StatusMediaRepository();
  final TextEditingController _searchController = TextEditingController();
  final List<StatusMedia> _items = [];
  Set<String> _favorites = {};
  Set<String> _saved = {};
  bool _loading = true;
  bool _sortNewest = true;
  _FavoriteFilter _filter = _FavoriteFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadSaved();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSaved();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('favorite_statuses') ?? [];
    final items = await _repository.loadFromPaths(stored);
    final existingPaths = items.map((item) => item.path).toSet();
    final cleaned = stored.where(existingPaths.contains).toList();
    if (cleaned.length != stored.length) {
      await prefs.setStringList('favorite_statuses', cleaned);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _favorites = cleaned.toSet();
      _items
        ..clear()
        ..addAll(items);
      _loading = false;
    });
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('saved_statuses') ?? [];
    if (!mounted) {
      return;
    }
    setState(() {
      _saved = stored.toSet();
    });
  }

  Future<void> _toggleFavorite(StatusMedia item) async {
    final next = <String>{..._favorites};
    if (next.contains(item.path)) {
      next.remove(item.path);
      _items.removeWhere((entry) => entry.path == item.path);
    } else {
      next.add(item.path);
    }
    setState(() {
      _favorites = next;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_statuses', next.toList());
  }

  bool _isFavorite(StatusMedia item) => _favorites.contains(item.path);

  List<StatusMedia> _applyFilters(List<StatusMedia> items) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = items.where((item) {
      if (_filter == _FavoriteFilter.photos && item.isVideo) {
        return false;
      }
      if (_filter == _FavoriteFilter.videos && !item.isVideo) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final name = item.path.split('/').last.toLowerCase();
      return name.contains(query);
    }).toList();
    filtered.sort((a, b) => _sortNewest
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return filtered;
  }

  Future<void> _saveToGallery(StatusMedia item) async {
    if (_saved.contains(item.path)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('status_already_saved'.tr())),
      );
      return;
    }
    final saved = await _repository.saveToGallery(item);
    if (!mounted) {
      return;
    }
    if (saved) {
      final next = <String>{..._saved, item.path};
      _saved = next;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_statuses', next.toList());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? 'status_saved'.tr() : 'status_save_failed'.tr()),
      ),
    );
  }

  Future<void> _shareItem(StatusMedia item) async {
    try {
      await Share.shareXFiles([XFile(item.path)]);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('status_share_failed'.tr())),
      );
    }
  }

  Future<void> _copyPath(StatusMedia item) async {
    await Clipboard.setData(ClipboardData(text: item.path));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('status_copy_done'.tr())),
    );
  }

  Future<void> _deleteItem(StatusMedia item) async {
    final deleted = await _repository.deleteFromGallery(item);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? 'status_deleted'.tr() : 'status_delete_failed'.tr(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _applyFilters(_items);
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
            decoration: const BoxDecoration(gradient: AppColors.mistGradient),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FavoritesFilterBar(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    onClear: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    sortNewest: _sortNewest,
                    onToggleSort: () {
                      setState(() {
                        _sortNewest = !_sortNewest;
                      });
                    },
                    onRefresh: _loadFavorites,
                  ),
                  SizedBox(height: 10.h),
                  _FilterChips(
                    value: _filter,
                    onChanged: (value) {
                      setState(() {
                        _filter = value;
                      });
                    },
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: _FavoritesGrid(
                      items: filteredItems,
                      isLoading: _loading,
                      onSave: _saveToGallery,
                      onShare: _shareItem,
                      onCopy: _copyPath,
                      onDelete: _deleteItem,
                      onToggleFavorite: _toggleFavorite,
                      isFavorite: _isFavorite,
                      canDelete: _repository.isSavedMediaPath,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          child: Icon(
            icon,
            color: AppColors.textSecondary,
            size: 18.sp,
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final _FavoriteFilter value;
  final ValueChanged<_FavoriteFilter> onChanged;

  const _FilterChips({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      children: [
        ChoiceChip(
          label: Text('status_filter_all'.tr()),
          selected: value == _FavoriteFilter.all,
          onSelected: (_) => onChanged(_FavoriteFilter.all),
        ),
        ChoiceChip(
          label: Text('status_filter_photos'.tr()),
          selected: value == _FavoriteFilter.photos,
          onSelected: (_) => onChanged(_FavoriteFilter.photos),
        ),
        ChoiceChip(
          label: Text('status_filter_videos'.tr()),
          selected: value == _FavoriteFilter.videos,
          onSelected: (_) => onChanged(_FavoriteFilter.videos),
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

  const _FavoriteOverlay({
    required this.isFavorite,
    required this.onTap,
  });

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

  const _EmptyFavoritesState({
    required this.title,
    required this.subtitle,
  });

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
          Icon(Icons.star_border_rounded,
              color: AppColors.primary.withOpacity(0.6), size: 28.sp),
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
