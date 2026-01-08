import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/routes/routes.dart';
import '../../statuses/status_media.dart';
import '../../statuses/status_media_repository.dart';
import '../../statuses/widgets/status_media_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StatusMediaRepository _repository = StatusMediaRepository();
  final TextEditingController _searchController = TextEditingController();
  final List<StatusMedia> _items = [];
  bool _loading = true;
  bool _permissionDenied = false;
  bool _favoritesOnly = false;
  bool _sortNewest = true;
  String _searchQuery = '';
  Set<String> _favorites = {};
  Set<String> _saved = {};

  bool get _isAndroid => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadSaved();
    _loadMedia();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia({bool showMessage = false}) async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });
    await _loadSaved();

    if (!_isAndroid) {
      setState(() {
        _items.clear();
        _loading = false;
      });
      return;
    }

    final hasPermission = await _ensureStoragePermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() {
          _items.clear();
          _permissionDenied = true;
          _loading = false;
        });
      }
      return;
    }

    final items = await _repository.listWhatsAppStatuses();
    if (!mounted) {
      return;
    }
    setState(() {
      _items
        ..clear()
        ..addAll(items);
      _loading = false;
    });

    if (showMessage && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('status_scan_done'.tr())));
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('favorite_statuses') ?? [];
    if (!mounted) {
      return;
    }
    setState(() {
      _favorites = stored.toSet();
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

  Future<void> _markSaved(StatusMedia item) async {
    final next = <String>{..._saved, item.path};
    setState(() {
      _saved = next;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_statuses', next.toList());
  }

  bool _isSaved(StatusMedia item) => _saved.contains(item.path);

  Future<void> _toggleFavorite(StatusMedia item) async {
    final path = item.path;
    final next = <String>{..._favorites};
    if (next.contains(path)) {
      next.remove(path);
    } else {
      next.add(path);
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
      if (_favoritesOnly && !_favorites.contains(item.path)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final name = item.path.split('/').last.toLowerCase();
      return name.contains(query);
    }).toList();
    filtered.sort(
      (a, b) => _sortNewest
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return filtered;
  }

  Future<bool> _ensureStoragePermission() async {
    if (!_isAndroid) {
      return true;
    }
    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) {
      return true;
    }
    final manageStatus = await Permission.manageExternalStorage.request();
    return manageStatus.isGranted;
  }

  Future<void> _saveToGallery(StatusMedia item) async {
    if (_isSaved(item)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('status_already_saved'.tr())));
      return;
    }
    final saved = await _repository.saveToGallery(item);
    if (!mounted) {
      return;
    }
    if (saved) {
      await _markSaved(item);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('status_share_failed'.tr())));
    }
  }

  Future<void> _copyPath(StatusMedia item) async {
    await Clipboard.setData(ClipboardData(text: item.path));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('status_copy_done'.tr())));
  }

  Future<void> _deleteItem(StatusMedia item) async {
    final deleted = await _repository.deleteFromGallery(item);
    if (!mounted) {
      return;
    }
    if (deleted) {
      setState(() {
        _items.removeWhere((entry) => entry.path == item.path);
        _favorites.remove(item.path);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_statuses', _favorites.toList());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? 'status_deleted'.tr() : 'status_delete_failed'.tr(),
        ),
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('whatsapp://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    final fallback = Uri.parse('https://wa.me/');
    await launchUrl(fallback, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 760;
    final tabHeight = isNarrow ? 320.h : 360.h;
    final filteredItems = _applyFilters(_items);
    final images = filteredItems.where((item) => !item.isVideo).toList();
    final videos = filteredItems.where((item) => item.isVideo).toList();
    final hasFilters = _searchQuery.isNotEmpty || _favoritesOnly;
    final showEmptyHint =
        _isAndroid && !_loading && !_permissionDenied && _items.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.mistGradient),
          ),
          Positioned(
            top: -100,
            right: -60,
            child: _GlowCircle(
              size: 240,
              color: AppColors.primary.withOpacity(0.12),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: _GlowCircle(
              size: 280,
              color: AppColors.accent.withOpacity(0.14),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadMedia,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(
                      isAndroid: _isAndroid,
                      onOpenFavorites: () {
                        Navigator.pushNamed(
                          context,
                          Routes.favorites,
                        ).then((_) => _loadFavorites());
                      },
                    ),
                    SizedBox(height: 16.h),
                    _HeroCard(
                      isNarrow: isNarrow,
                      isAndroid: _isAndroid,
                      onScan: () => _loadMedia(showMessage: true),
                      onOpenWhatsApp: _openWhatsApp,
                    ),
                    SizedBox(height: 12.h),
                    if (!_isAndroid)
                      const _PlatformNotice()
                    else if (_permissionDenied)
                      _PermissionCard(
                        onOpenSettings: openAppSettings,
                        onRetry: _loadMedia,
                      ),
                    SizedBox(height: 12.h),
                    if (_isAndroid)
                      _FilterBar(
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
                        favoritesOnly: _favoritesOnly,
                        onToggleFavorites: () {
                          setState(() {
                            _favoritesOnly = !_favoritesOnly;
                          });
                        },
                        sortNewest: _sortNewest,
                        onToggleSort: () {
                          setState(() {
                            _sortNewest = !_sortNewest;
                          });
                        },
                      ),
                    if (_isAndroid) SizedBox(height: 12.h),
                    _OverviewRow(
                      isNarrow: isNarrow,
                      imageCount: images.length,
                      videoCount: videos.length,
                    ),
                    SizedBox(height: 20.h),
                    _PreviewTabs(
                      height: tabHeight,
                      images: images,
                      videos: videos,
                      isLoading: _loading,
                      onSave: _isAndroid ? _saveToGallery : null,
                      onShare: _shareItem,
                      onCopy: _copyPath,
                      onDelete: _deleteItem,
                      onToggleFavorite: _toggleFavorite,
                      isFavorite: _isFavorite,
                      canDelete: _repository.isSavedMediaPath,
                      emptySubtitleKey: hasFilters
                          ? 'status_filter_empty_subtitle'
                          : 'status_tabs_hint',
                      emptyTitleKey: hasFilters
                          ? 'status_filter_empty_title'
                          : 'status_tabs_empty',
                    ),
                    SizedBox(height: 20.h),
                    if (showEmptyHint)
                      _EmptyStatusHelp(
                        onOpenWhatsApp: _openWhatsApp,
                        onScan: () => _loadMedia(showMessage: true),
                      ),
                    if (showEmptyHint) SizedBox(height: 16.h),
                    const _HowItWorksCard(),
                    SizedBox(height: 16.h),
                    _RecentSection(
                      items: filteredItems,
                      onSave: _isAndroid ? _saveToGallery : null,
                      onShare: _shareItem,
                      onCopy: _copyPath,
                      onDelete: _deleteItem,
                      onToggleFavorite: _toggleFavorite,
                      isFavorite: _isFavorite,
                      canDelete: _repository.isSavedMediaPath,
                    ),
                    SizedBox(height: 12.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isAndroid;
  final VoidCallback onOpenFavorites;

  const _TopBar({
    required this.isAndroid,
    required this.onOpenFavorites,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10.r,
                offset: Offset(0, 6.h),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/WhatsApp status download icon.png',
            width: 42.w,
            height: 42.w,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'status_home_title'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'status_overview_hint'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Text(
                isAndroid ? 'Android' : 'iOS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            _TopBarAction(
              icon: Icons.star_rounded,
              tooltip: 'status_favorites_title'.tr(),
              onTap: onOpenFavorites,
            ),
          ],
        ),
      ],
    );
  }
}

class _TopBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopBarAction({
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
          width: 34.w,
          height: 34.w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 18.sp),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool isNarrow;
  final bool isAndroid;
  final VoidCallback onScan;
  final VoidCallback onOpenWhatsApp;

  const _HeroCard({
    required this.isNarrow,
    required this.isAndroid,
    required this.onScan,
    required this.onOpenWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 24.r,
            offset: Offset(0, 12.h),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'status_home_tagline'.tr(),
                style: TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'status_home_subtitle'.tr(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 14.h),
              if (!isAndroid)
                Text(
                  'status_android_only_subtitle'.tr(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12.sp,
                  ),
                )
              else if (isNarrow)
                Column(
                  children: [
                    CustomButton(
                      text: 'status_action_import'.tr(),
                      onPressed: onScan,
                    ),
                    SizedBox(height: 10.h),
                    CustomButton(
                      text: 'status_action_open_whatsapp'.tr(),
                      onPressed: onOpenWhatsApp,
                      isOutlined: true,
                      color: Colors.white,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'status_action_import'.tr(),
                        onPressed: onScan,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: CustomButton(
                        text: 'status_action_open_whatsapp'.tr(),
                        onPressed: onOpenWhatsApp,
                        isOutlined: true,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlatformNotice extends StatelessWidget {
  const _PlatformNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'status_android_only_title'.tr(),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'status_android_only_subtitle'.tr(),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final Future<void> Function({bool showMessage}) onRetry;

  const _PermissionCard({required this.onOpenSettings, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'status_permission_title'.tr(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'status_permission_subtitle'.tr(),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'status_permission_action'.tr(),
                  onPressed: onOpenSettings,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: CustomButton(
                  text: 'retry'.tr(),
                  onPressed: () => onRetry(showMessage: true),
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final bool isNarrow;
  final int imageCount;
  final int videoCount;

  const _OverviewRow({
    required this.isNarrow,
    required this.imageCount,
    required this.videoCount,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _OverviewCardData(
        titleKey: 'status_overview_photos',
        count: imageCount,
        icon: Icons.photo_rounded,
        tint: AppColors.primary,
      ),
      _OverviewCardData(
        titleKey: 'status_overview_videos',
        count: videoCount,
        icon: Icons.videocam_rounded,
        tint: AppColors.secondary,
      ),
    ];

    if (isNarrow) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: _OverviewCard(data: card),
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: List.generate(
        cards.length,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              end: index == cards.length - 1 ? 0 : 12.w,
            ),
            child: _OverviewCard(data: cards[index]),
          ),
        ),
      ),
    );
  }
}

class _OverviewCardData {
  final String titleKey;
  final int count;
  final IconData icon;
  final Color tint;

  _OverviewCardData({
    required this.titleKey,
    required this.count,
    required this.icon,
    required this.tint,
  });
}

class _OverviewCard extends StatelessWidget {
  final _OverviewCardData data;
  const _OverviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: data.tint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(data.icon, color: data.tint, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.titleKey.tr(),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  data.count.toString(),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _PreviewTabs extends StatelessWidget {
  final double height;
  final List<StatusMedia> images;
  final List<StatusMedia> videos;
  final bool isLoading;
  final ValueChanged<StatusMedia>? onSave;
  final ValueChanged<StatusMedia> onShare;
  final ValueChanged<StatusMedia> onCopy;
  final ValueChanged<StatusMedia> onDelete;
  final ValueChanged<StatusMedia> onToggleFavorite;
  final bool Function(StatusMedia) isFavorite;
  final bool Function(String path) canDelete;
  final String emptyTitleKey;
  final String emptySubtitleKey;

  const _PreviewTabs({
    required this.height,
    required this.images,
    required this.videos,
    required this.isLoading,
    required this.onSave,
    required this.onShare,
    required this.onCopy,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.isFavorite,
    required this.canDelete,
    required this.emptyTitleKey,
    required this.emptySubtitleKey,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 760 ? 3 : 4;

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(titleKey: 'status_tabs_title'),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(color: AppColors.primary, width: 3),
              ),
              tabs: [
                Tab(text: 'status_tabs_photos'.tr()),
                Tab(text: 'status_tabs_videos'.tr()),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: height,
            child: TabBarView(
              children: [
                _PreviewGrid(
                  items: images,
                  isLoading: isLoading,
                  isVideo: false,
                  crossAxisCount: crossAxisCount,
                  onSave: onSave,
                  onShare: onShare,
                  onCopy: onCopy,
                  onDelete: onDelete,
                  onToggleFavorite: onToggleFavorite,
                  isFavorite: isFavorite,
                  canDelete: canDelete,
                  emptyTitleKey: emptyTitleKey,
                  emptySubtitleKey: emptySubtitleKey,
                ),
                _PreviewGrid(
                  items: videos,
                  isLoading: isLoading,
                  isVideo: true,
                  crossAxisCount: crossAxisCount,
                  onSave: onSave,
                  onShare: onShare,
                  onCopy: onCopy,
                  onDelete: onDelete,
                  onToggleFavorite: onToggleFavorite,
                  isFavorite: isFavorite,
                  canDelete: canDelete,
                  emptyTitleKey: emptyTitleKey,
                  emptySubtitleKey: emptySubtitleKey,
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'status_tabs_hint'.tr(),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

class _PreviewGrid extends StatelessWidget {
  final List<StatusMedia> items;
  final bool isLoading;
  final bool isVideo;
  final int crossAxisCount;
  final ValueChanged<StatusMedia>? onSave;
  final ValueChanged<StatusMedia> onShare;
  final ValueChanged<StatusMedia> onCopy;
  final ValueChanged<StatusMedia> onDelete;
  final ValueChanged<StatusMedia> onToggleFavorite;
  final bool Function(StatusMedia) isFavorite;
  final bool Function(String path) canDelete;
  final String emptyTitleKey;
  final String emptySubtitleKey;

  const _PreviewGrid({
    required this.items,
    required this.isLoading,
    required this.isVideo,
    required this.crossAxisCount,
    required this.onSave,
    required this.onShare,
    required this.onCopy,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.isFavorite,
    required this.canDelete,
    required this.emptyTitleKey,
    required this.emptySubtitleKey,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (items.isEmpty) {
      return _EmptyState(
        titleKey: emptyTitleKey,
        subtitleKey: emptySubtitleKey,
        icon: isVideo ? Icons.videocam_off : Icons.image_not_supported,
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
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
                    child: _FavoriteButton(
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

class _FilterBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool favoritesOnly;
  final VoidCallback onToggleFavorites;
  final bool sortNewest;
  final VoidCallback onToggleSort;

  const _FilterBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.favoritesOnly,
    required this.onToggleFavorites,
    required this.sortNewest,
    required this.onToggleSort,
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
          _IconToggleButton(
            isActive: favoritesOnly,
            activeIcon: Icons.star_rounded,
            inactiveIcon: Icons.star_border_rounded,
            tooltip: 'status_filter_favorites'.tr(),
            onTap: onToggleFavorites,
          ),
          SizedBox(width: 6.w),
          _IconToggleButton(
            isActive: sortNewest,
            activeIcon: Icons.south_rounded,
            inactiveIcon: Icons.north_rounded,
            tooltip: sortNewest
                ? 'status_sort_latest'.tr()
                : 'status_sort_oldest'.tr(),
            onTap: onToggleSort,
          ),
        ],
      ),
    );
  }
}

class _IconToggleButton extends StatelessWidget {
  final bool isActive;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconToggleButton({
    required this.isActive,
    required this.activeIcon,
    required this.inactiveIcon,
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
            color: isActive ? AppColors.primary.withOpacity(0.12) : null,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            isActive ? activeIcon : inactiveIcon,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
            size: 18.sp,
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;

  const _FavoriteButton({required this.isFavorite, required this.onTap});

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

class _EmptyStatusHelp extends StatelessWidget {
  final VoidCallback onOpenWhatsApp;
  final VoidCallback onScan;

  const _EmptyStatusHelp({required this.onOpenWhatsApp, required this.onScan});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'status_empty_title'.tr(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'status_empty_subtitle'.tr(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.sp,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'status_action_open_whatsapp'.tr(),
                  onPressed: onOpenWhatsApp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: CustomButton(
                  text: 'status_action_import'.tr(),
                  onPressed: onScan,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final steps = [
      'status_how_step_1',
      'status_how_step_2',
      'status_how_step_3',
    ];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'status_how_title'.tr(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          ...steps.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      entry.value.tr(),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        height: 1.6,
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
  }
}

class _RecentSection extends StatelessWidget {
  final List<StatusMedia> items;
  final ValueChanged<StatusMedia>? onSave;
  final ValueChanged<StatusMedia> onShare;
  final ValueChanged<StatusMedia> onCopy;
  final ValueChanged<StatusMedia> onDelete;
  final ValueChanged<StatusMedia> onToggleFavorite;
  final bool Function(StatusMedia) isFavorite;
  final bool Function(String path) canDelete;

  const _RecentSection({
    required this.items,
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
    final recentItems = items.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(titleKey: 'status_recent_title'),
        SizedBox(height: 6.h),
        Text(
          'status_recent_subtitle'.tr(),
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
        ),
        SizedBox(height: 12.h),
        if (recentItems.isEmpty)
          _EmptyState(
            titleKey: 'status_recent_empty',
            subtitleKey: 'status_tabs_hint',
            icon: Icons.photo_library_outlined,
          )
        else
          SizedBox(
            height: 120.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recentItems.length,
              separatorBuilder: (context, index) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                final item = recentItems[index];
                return _RecentItem(
                  item: item,
                  isFavorite: isFavorite(item),
                  onToggleFavorite: () => onToggleFavorite(item),
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
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RecentItem extends StatelessWidget {
  final StatusMedia item;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  const _RecentItem({
    required this.item,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  String _formatTime(BuildContext context) {
    final locale = context.locale.toString();
    return DateFormat.Hm(locale).format(item.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140.w,
        padding: EdgeInsets.all(12.w),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: item.isVideo
                          ? StatusVideoThumb(
                              path: item.path,
                              showPlayIcon: false,
                            )
                          : Image.file(
                              File(item.path),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const StatusVideoPlaceholder();
                              },
                            ),
                    ),
                  ),
                  Positioned(
                    top: 6.h,
                    right: 6.w,
                    child: _FavoriteButton(
                      isFavorite: isFavorite,
                      onTap: onToggleFavorite,
                    ),
                  ),
                  if (item.isVideo)
                    Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white.withOpacity(0.9),
                        size: 28.sp,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              item.isVideo
                  ? 'status_recent_item_video'.tr()
                  : 'status_recent_item_photo'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              _formatTime(context),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String titleKey;
  const _SectionHeader({required this.titleKey});

  @override
  Widget build(BuildContext context) {
    return Text(
      titleKey.tr(),
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String titleKey;
  final String subtitleKey;
  final IconData icon;

  const _EmptyState({
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160.h,
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary.withOpacity(0.6), size: 28.sp),
          SizedBox(height: 12.h),
          Text(
            titleKey.tr(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitleKey.tr(),
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

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

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
