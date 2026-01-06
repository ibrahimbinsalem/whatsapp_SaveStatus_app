import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/colors.dart';
import '../../statuses/status_media_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StatusMediaRepository _repository = StatusMediaRepository();
  PermissionStatus _storageStatus = PermissionStatus.denied;
  PermissionStatus _manageStatus = PermissionStatus.denied;
  int _savedCount = 0;
  bool _loading = true;

  bool get _isAndroid => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _loading = true;
    });
    if (_isAndroid) {
      _storageStatus = await Permission.storage.status;
      _manageStatus = await Permission.manageExternalStorage.status;
    }
    _savedCount = await _repository.countSavedCopies();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _clearSavedCopies() async {
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
    final deleted = await _repository.deleteSavedCopies();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_statuses', []);
    if (!mounted) {
      return;
    }
    setState(() {
      _savedCount = 0;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('status_settings_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.mistGradient),
          ),
          SafeArea(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              children: [
                _SettingsCard(
                  title: 'status_settings_permissions'.tr(),
                  subtitle: _isAndroid
                      ? 'status_settings_permissions_subtitle'.tr()
                      : 'status_android_only_subtitle'.tr(),
                  child: _isAndroid
                      ? Column(
                          children: [
                            _PermissionRow(
                              label: 'status_settings_permission_storage'.tr(),
                              status: _storageStatus,
                            ),
                            SizedBox(height: 10.h),
                            _PermissionRow(
                              label: 'status_settings_permission_manage'.tr(),
                              status: _manageStatus,
                            ),
                            SizedBox(height: 12.h),
                            _SettingsButton(
                              text: 'status_settings_open_settings'.tr(),
                              onPressed: openAppSettings,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(height: 16.h),
                _SettingsCard(
                  title: 'status_settings_storage'.tr(),
                  subtitle: 'status_settings_storage_subtitle'.tr(),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'status_settings_saved_count'.tr(
                                namedArgs: {'count': '$_savedCount'},
                              ),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.sp,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            _SettingsButton(
                              text: 'status_settings_clear_button'.tr(),
                              onPressed:
                                  _savedCount == 0 ? null : _clearSavedCopies,
                              isOutlined: true,
                            ),
                          ],
                        ),
                ),
                SizedBox(height: 16.h),
                _SettingsCard(
                  title: 'status_settings_guide'.tr(),
                  subtitle: 'status_how_title'.tr(),
                  child: Column(
                    children: [
                      _GuideStep(
                        index: 1,
                        text: 'status_how_step_1'.tr(),
                      ),
                      _GuideStep(
                        index: 2,
                        text: 'status_how_step_2'.tr(),
                      ),
                      _GuideStep(
                        index: 3,
                        text: 'status_how_step_3'.tr(),
                      ),
                    ],
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

class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

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
            blurRadius: 10.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final PermissionStatus status;

  const _PermissionRow({
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isGranted = status.isGranted;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isGranted
                ? AppColors.primary.withOpacity(0.12)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isGranted
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.red.withOpacity(0.3),
            ),
          ),
          child: Text(
            isGranted
                ? 'status_settings_permission_granted'.tr()
                : 'status_settings_permission_denied'.tr(),
            style: TextStyle(
              color: isGranted ? AppColors.primary : Colors.redAccent,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isOutlined;

  const _SettingsButton({
    required this.text,
    required this.onPressed,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOutlined ? Colors.white : AppColors.primary;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor:
              isOutlined ? AppColors.primary : AppColors.textOnPrimary,
          side: isOutlined
              ? BorderSide(color: AppColors.primary, width: 1.5)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int index;
  final String text;

  const _GuideStep({
    required this.index,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                '$index',
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
              text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
