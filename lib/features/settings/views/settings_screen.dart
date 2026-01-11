import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart' hide Trans;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    return GetBuilder<SettingsController>(
      init: SettingsController(),
      builder: (controller) {
        final permissionsGranted = controller.isAndroid &&
            (controller.storageStatus.isGranted ||
                controller.manageStatus.isGranted);
        final savedLabel = controller.loading
            ? '--'
            : controller.savedCount.toString();
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
                onPressed: controller.refreshStatus,
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(gradient: AppColors.mistGradient),
              ),
              Positioned(
                top: -120.h,
                right: -60.w,
                child: Container(
                  width: 240.w,
                  height: 240.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                ),
              ),
              SafeArea(
                child: ListView(
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  children: [
                    _SettingsHero(
                      title: 'status_settings_title'.tr(),
                      subtitle: 'settings_overview_subtitle'.tr(),
                      chips: [
                        _StatChip(
                          icon: Icons.language_rounded,
                          label: 'settings_language_label'.tr(
                            namedArgs: {
                              'lang': isArabic
                                  ? 'settings_language_ar'.tr()
                                  : 'settings_language_en'.tr(),
                            },
                          ),
                        ),
                        _StatChip(
                          icon: Icons.folder_rounded,
                          label: 'settings_stats_saved'.tr(
                            namedArgs: {'count': savedLabel},
                          ),
                        ),
                        _StatChip(
                          icon: permissionsGranted
                              ? Icons.verified_rounded
                              : Icons.gpp_bad_rounded,
                          label: permissionsGranted
                              ? 'settings_stats_permissions_on'.tr()
                              : 'settings_stats_permissions_off'.tr(),
                        ),
                      ],
                    ),
                    SizedBox(height: 18.h),
                    _SettingsCard(
                      icon: Icons.translate_rounded,
                      title: 'settings_language_title'.tr(),
                      subtitle: 'settings_language_subtitle'.tr(),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SettingsButton(
                              text: 'settings_language_ar'.tr(),
                              onPressed: () {
                                if (!isArabic) {
                                  context.setLocale(const Locale('ar'));
                                }
                              },
                              icon: Icons.language_rounded,
                              isOutlined: !isArabic,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _SettingsButton(
                              text: 'settings_language_en'.tr(),
                              onPressed: () {
                                if (isArabic) {
                                  context.setLocale(const Locale('en'));
                                }
                              },
                              icon: Icons.translate_rounded,
                              isOutlined: isArabic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _SettingsCard(
                      icon: Icons.lock_rounded,
                      title: 'status_settings_permissions'.tr(),
                      subtitle: controller.isAndroid
                          ? 'status_settings_permissions_subtitle'.tr()
                          : 'status_android_only_subtitle'.tr(),
                      child: controller.isAndroid
                          ? Column(
                              children: [
                                _PermissionRow(
                                  icon: Icons.folder_open_rounded,
                                  label:
                                      'status_settings_permission_storage'.tr(),
                                  status: controller.storageStatus,
                                ),
                                SizedBox(height: 10.h),
                                _PermissionRow(
                                  icon: Icons.admin_panel_settings_rounded,
                                  label:
                                      'status_settings_permission_manage'.tr(),
                                  status: controller.manageStatus,
                                ),
                                SizedBox(height: 12.h),
                                _SettingsButton(
                                  text: 'status_settings_open_settings'.tr(),
                                  onPressed: openAppSettings,
                                  icon: Icons.settings_rounded,
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    SizedBox(height: 16.h),
                    _SettingsCard(
                      icon: Icons.cloud_download_rounded,
                      title: 'status_settings_storage'.tr(),
                      subtitle: 'status_settings_storage_subtitle'.tr(),
                      child: controller.loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 6.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(10.r),
                                        border: Border.all(
                                          color: AppColors.primary
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        'status_settings_saved_count'.tr(
                                          namedArgs: {
                                            'count': '${controller.savedCount}'
                                          },
                                        ),
                                        style: TextStyle(
                                          color: AppColors.primaryDark,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.folder_zip_rounded,
                                      color:
                                          AppColors.primary.withOpacity(0.6),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                _SettingsButton(
                                  text: 'status_settings_clear_button'.tr(),
                                  onPressed: controller.savedCount == 0
                                      ? null
                                      : () => controller
                                          .clearSavedCopies(context),
                                  icon: Icons.delete_sweep_rounded,
                                  isOutlined: true,
                                ),
                              ],
                            ),
                    ),
                    SizedBox(height: 16.h),
                    _SettingsCard(
                      icon: Icons.auto_stories_rounded,
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
                    SizedBox(height: 16.h),
                    _SettingsCard(
                      icon: Icons.person_pin_rounded,
                      title: 'settings_developer_title'.tr(),
                      subtitle: 'settings_developer_subtitle'.tr(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52.w,
                                height: 52.w,
                                decoration: BoxDecoration(
                                  gradient: AppColors.successGradient,
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Center(
                                  child: Text(
                                    'settings_dev_initials'.tr(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'settings_dev_name'.tr(),
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'settings_dev_role'.tr(),
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
                          SizedBox(height: 12.h),
                          Text(
                            'settings_dev_bio'.tr(),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.sp,
                              height: 1.6,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Wrap(
                            spacing: 10.w,
                            runSpacing: 10.h,
                            children: [
                              _SocialChip(
                                icon: Icons.camera_alt_rounded,
                                label: 'settings_social_instagram'.tr(),
                                onTap: () => _openLink(
                                  context,
                                  'settings_social_instagram_url'.tr(),
                                ),
                              ),
                              _SocialChip(
                                icon: Icons.ondemand_video_rounded,
                                label: 'settings_social_youtube'.tr(),
                                onTap: () => _openLink(
                                  context,
                                  'settings_social_youtube_url'.tr(),
                                ),
                              ),
                              _SocialChip(
                                icon: Icons.alternate_email_rounded,
                                label: 'settings_social_x'.tr(),
                                onTap: () => _openLink(
                                  context,
                                  'settings_social_x_url'.tr(),
                                ),
                              ),
                              _SocialChip(
                                icon: Icons.mail_rounded,
                                label: 'settings_social_email'.tr(),
                                onTap: () => _openLink(
                                  context,
                                  'settings_social_email_url'.tr(),
                                ),
                              ),
                            ],
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
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
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
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
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
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
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
  final IconData icon;

  const _PermissionRow({
    required this.label,
    required this.status,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isGranted = status.isGranted;
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(
            icon,
            size: 18.sp,
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: 10.w),
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
  final IconData? icon;
  final bool isOutlined;

  const _SettingsButton({
    required this.text,
    required this.onPressed,
    this.icon,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16.sp),
              SizedBox(width: 8.w),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> chips;

  const _SettingsHero({
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 18.r,
            offset: Offset(0, 12.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: chips,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16.sp),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

class _SocialChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: AppColors.primaryDark,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openLink(BuildContext context, String url) async {
  if (url.isEmpty) {
    return;
  }
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }
  final launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings_link_failed'.tr())),
    );
  }
}
