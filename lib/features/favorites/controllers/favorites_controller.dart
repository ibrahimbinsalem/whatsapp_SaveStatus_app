import 'package:cross_file/cross_file.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../statuses/status_media.dart';
import '../../statuses/status_media_repository.dart';

enum FavoriteFilter { all, photos, videos }

class FavoritesController extends GetxController {
  final StatusMediaRepository repository = StatusMediaRepository();
  final TextEditingController searchController = TextEditingController();
  final List<StatusMedia> items = [];
  Set<String> favorites = {};
  Set<String> saved = {};
  bool loading = true;
  bool sortNewest = true;
  FavoriteFilter filter = FavoriteFilter.all;
  String searchQuery = '';

  @override
  void onInit() {
    super.onInit();
    loadFavorites();
    loadSaved();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadFavorites() async {
    loading = true;
    update();
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('favorite_statuses') ?? [];
    final entries = await repository.loadFromPaths(stored);
    final existingPaths = entries.map((item) => item.path).toSet();
    final cleaned = stored.where(existingPaths.contains).toList();
    if (cleaned.length != stored.length) {
      await prefs.setStringList('favorite_statuses', cleaned);
    }
    favorites = cleaned.toSet();
    items
      ..clear()
      ..addAll(entries);
    loading = false;
    update();
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('saved_statuses') ?? [];
    saved = stored.toSet();
    update();
  }

  Future<void> toggleFavorite(StatusMedia item) async {
    final next = <String>{...favorites};
    if (next.contains(item.path)) {
      next.remove(item.path);
      items.removeWhere((entry) => entry.path == item.path);
    } else {
      next.add(item.path);
    }
    favorites = next;
    update();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_statuses', next.toList());
  }

  bool isFavorite(StatusMedia item) => favorites.contains(item.path);

  List<StatusMedia> applyFilters(List<StatusMedia> list) {
    final query = searchQuery.trim().toLowerCase();
    final filtered = list.where((item) {
      if (filter == FavoriteFilter.photos && item.isVideo) {
        return false;
      }
      if (filter == FavoriteFilter.videos && !item.isVideo) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final name = item.path.split('/').last.toLowerCase();
      return name.contains(query);
    }).toList();
    filtered.sort((a, b) => sortNewest
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return filtered;
  }

  Future<void> saveToGallery(BuildContext context, StatusMedia item) async {
    if (saved.contains(item.path)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('status_already_saved'.tr())),
      );
      return;
    }
    final savedOk = await repository.saveToGallery(item);
    if (!context.mounted) {
      return;
    }
    if (savedOk) {
      final next = <String>{...saved, item.path};
      saved = next;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_statuses', next.toList());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(savedOk ? 'status_saved'.tr() : 'status_save_failed'.tr()),
      ),
    );
  }

  Future<void> shareItem(BuildContext context, StatusMedia item) async {
    try {
      await Share.shareXFiles([XFile(item.path)]);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('status_share_failed'.tr())),
      );
    }
  }

  Future<void> copyPath(BuildContext context, StatusMedia item) async {
    await Clipboard.setData(ClipboardData(text: item.path));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('status_copy_done'.tr())),
    );
  }

  Future<void> deleteItem(BuildContext context, StatusMedia item) async {
    final deleted = await repository.deleteFromGallery(item);
    if (!context.mounted) {
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

  void updateSearch(String value) {
    searchQuery = value;
    update();
  }

  void clearSearch() {
    searchController.clear();
    searchQuery = '';
    update();
  }

  void toggleSort() {
    sortNewest = !sortNewest;
    update();
  }

  void setFilter(FavoriteFilter value) {
    filter = value;
    update();
  }
}
