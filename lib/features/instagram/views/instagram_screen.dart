import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart' hide Trans;

import '../controllers/instagram_controller.dart';

class InstagramScreen extends StatelessWidget {
  const InstagramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<InstagramController>(
      init: InstagramController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: Stack(
            children: [
              // خلفية بتدرجات ألوان إنستقرام الخافتة
              Positioned(
                top: -100,
                right: -80,
                child: _GlowBubble(
                  size: 250,
                  color: const Color(0xFF833AB4).withOpacity(0.15),
                ),
              ),
              Positioned(
                bottom: -120,
                left: -80,
                child: _GlowBubble(
                  size: 280,
                  color: const Color(0xFFF77737).withOpacity(0.12),
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 16.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(onBack: () => Navigator.pop(context)),
                      SizedBox(height: 24.h),
                      _InputCard(controller: controller),
                      SizedBox(height: 32.h),
                      _SectionTitle(title: 'ig_section_collections'.tr()),
                      SizedBox(height: 12.h),
                      _CollectionsGrid(controller: controller),
                      SizedBox(height: 32.h),
                      _SectionTitle(title: 'ig_section_insights'.tr()),
                      SizedBox(height: 12.h),
                      const _InsightsList(),
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
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ig_title'.tr(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'ig_tagline'.tr(),
                style: TextStyle(color: Colors.white70, fontSize: 12.sp),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InputCard extends StatelessWidget {
  final InstagramController controller;
  const _InputCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF252525)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: controller.urlController,
              style: const TextStyle(color: Colors.white),
              onChanged: controller.updateUrl,
              decoration: InputDecoration(
                hintText: 'ig_input_hint'.tr(),
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13.sp),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16.w),
                prefixIcon: Icon(
                  Icons.link_rounded,
                  color: Colors.white54,
                  size: 20.sp,
                ),
                suffixIcon: controller.urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.white54,
                        ),
                        onPressed: controller.clearInput,
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.pasteLink,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  icon: const Icon(Icons.paste_rounded, size: 18),
                  label: Text('ig_action_paste'.tr()),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: controller.isLoading
                      ? null
                      : controller.fetchContent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE1306C),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  icon: controller.isLoading
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text('ig_action_fetch'.tr()),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'ig_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}

class _CollectionsGrid extends StatelessWidget {
  final InstagramController controller;
  const _CollectionsGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'icon': Icons.movie_filter_rounded,
        'label': 'ig_card_reels'.tr(),
        'color': const Color(0xFFE1306C),
      },
      {
        'icon': Icons.grid_on_rounded,
        'label': 'ig_card_posts'.tr(),
        'color': const Color(0xFFC13584),
      },
      {
        'icon': Icons.history_edu_rounded,
        'label': 'ig_card_stories'.tr(),
        'color': const Color(0xFFF77737),
      },
      {
        'icon': Icons.favorite_border_rounded,
        'label': 'ig_card_highlights'.tr(),
        'color': const Color(0xFFFD1D1D),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item['icon'] as IconData,
                color: item['color'] as Color,
                size: 28.sp,
              ),
              SizedBox(height: 8.h),
              Text(
                item['label'] as String,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightsList extends StatelessWidget {
  const _InsightsList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InsightTile(
          icon: Icons.high_quality_rounded,
          title: 'ig_insight_quality'.tr(),
          subtitle: 'ig_insight_quality_desc'.tr(),
        ),
        SizedBox(height: 12.h),
        _InsightTile(
          icon: Icons.privacy_tip_outlined,
          title: 'ig_insight_privacy'.tr(),
          subtitle: 'ig_insight_privacy_desc'.tr(),
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InsightTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24.sp),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white54, fontSize: 11.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
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
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 10)],
      ),
    );
  }
}
