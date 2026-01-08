import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../statuses/status_media_repository.dart';

class SettingsController extends GetxController {
  final StatusMediaRepository repository = StatusMediaRepository();
  PermissionStatus storageStatus = PermissionStatus.denied;
  PermissionStatus manageStatus = PermissionStatus.denied;
  int savedCount = 0;
  bool loading = true;

  bool get isAndroid => Platform.isAndroid;

  @override
  void onInit() {
    super.onInit();
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    loading = true;
    update();
    if (isAndroid) {
      storageStatus = await Permission.storage.status;
      manageStatus = await Permission.manageExternalStorage.status;
    }
    savedCount = await repository.countSavedCopies();
    loading = false;
    update();
  }

  Future<void> clearSavedCopies(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('status_settings_clear_title'.tr()),
        content: Text('status_settings_clear_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('skip'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('done'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final deleted = await repository.deleteSavedCopies();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_statuses', []);
    savedCount = 0;
    update();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted > 0
              ? 'status_settings_clear_done'.tr()
              : 'status_settings_clear_empty'.tr(),
        ),
      ),
    );
  }
}
