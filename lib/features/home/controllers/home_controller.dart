import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routes/routes.dart';
import '../../statuses/status_media.dart';
import '../../statuses/status_media_repository.dart';

class HomeController extends GetxController {
  final StatusMediaRepository repository = StatusMediaRepository();
  final TextEditingController searchController = TextEditingController();
  final List<StatusMedia> items = [];

  bool loading = true;
  bool permissionDenied = false;
  bool favoritesOnly = false;
  bool sortNewest = true;
  String searchQuery = '';
  Set<String> favorites = {};
  Set<String> saved = {};

  bool get isAndroid => Platform.isAndroid;

  @override
  void onInit() {
    super.onInit();
    loadFavorites();
    loadSaved();
    loadMedia();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  List<StatusMedia> get filteredItems => _applyFilters(items);

  Future<void> loadMedia({bool showMessage = false, BuildContext? context}) async {
    loading = true;
    permissionDenied = false;
    update();

    await loadSaved();

    if (!isAndroid) {
      items.clear();
      loading = false;
      update();
      return;
    }

    final hasPermission = await _ensureStoragePermission();
    if (!hasPermission) {
      items.clear();
      permissionDenied = true;
      loading = false;
      update();
      return;
    }

    final latest = await repository.listWhatsAppStatuses();
    items
      ..clear()
      ..addAll(latest);
    loading = false;
    update();

    if (showMessage && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('status_scan_done'.tr())),
      );
    }
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('favorite_statuses') ?? [];
    favorites = stored.toSet();
    update();
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('saved_statuses') ?? [];
    saved = stored.toSet();
    update();
  }

  Future<void> markSaved(StatusMedia item) async {
    final next = <String>{...saved, item.path};
    saved = next;
    update();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_statuses', next.toList());
  }

  bool isSaved(StatusMedia item) => saved.contains(item.path);

  Future<void> toggleFavorite(StatusMedia item) async {
    final path = item.path;
    final next = <String>{...favorites};
    if (next.contains(path)) {
      next.remove(path);
    } else {
      next.add(path);
    }
    favorites = next;
    update();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_statuses', next.toList());
  }

  bool isFavorite(StatusMedia item) => favorites.contains(item.path);

  List<StatusMedia> _applyFilters(List<StatusMedia> list) {
    final query = searchQuery.trim().toLowerCase();
    final filtered = list.where((item) {
      if (favoritesOnly && !favorites.contains(item.path)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final name = item.path.split('/').last.toLowerCase();
      return name.contains(query);
    }).toList();
    filtered.sort(
      (a, b) => sortNewest
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return filtered;
  }

  Future<bool> _ensureStoragePermission() async {
    if (!isAndroid) {
      return true;
    }
    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) {
      return true;
    }
    final manageStatus = await Permission.manageExternalStorage.request();
    return manageStatus.isGranted;
  }

  Future<void> saveToGallery(BuildContext context, StatusMedia item) async {
    if (isSaved(item)) {
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
      await markSaved(item);
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
    if (deleted) {
      items.removeWhere((entry) => entry.path == item.path);
      favorites.remove(item.path);
      update();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_statuses', favorites.toList());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? 'status_deleted'.tr() : 'status_delete_failed'.tr(),
        ),
      ),
    );
  }

  Future<void> openWhatsApp() async {
    final uri = Uri.parse('whatsapp://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    final fallback = Uri.parse('https://wa.me/');
    await launchUrl(fallback, mode: LaunchMode.externalApplication);
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

  void toggleFavoritesOnly() {
    favoritesOnly = !favoritesOnly;
    update();
  }

  void toggleSort() {
    sortNewest = !sortNewest;
    update();
  }

  void openFavorites(BuildContext context) {
    Navigator.pushNamed(context, Routes.favorites).then((_) => loadFavorites());
  }
}
