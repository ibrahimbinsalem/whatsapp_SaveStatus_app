import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InstagramScreen extends StatelessWidget {
  const InstagramScreen({super.key});

  static const Color _igPink = Color(0xFFE4405F);
  static const Color _igPurple = Color(0xFF833AB4);
  static const Color _igOrange = Color(0xFFFCAF45);
  static const Color _igSurface = Color(0xFFFDF6F7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F9),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF7F9), Color(0xFFFFEDF2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -60,
            child: _GlowBubble(
              size: 240,
              color: _igPurple.withOpacity(0.18),
            ),
          ),
          Positioned(
            bottom: -130,
            right: -80,
            child: _GlowBubble(
              size: 280,
              color: _igOrange.withOpacity(0.2),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(),
                  SizedBox(height: 18.h),
                  _HeroCard(),
                  SizedBox(height: 16.h),
                  _InputCard(),
                  SizedBox(height: 16.h),
                  _Collections(),
                  SizedBox(height: 20.h),
                  _Insights(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: Colors.black12),
          ),
          child: ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                colors: [
                  InstagramScreen._igPurple,
                  InstagramScreen._igPink,
                  InstagramScreen._igOrange,
                ],
              ).createShader(bounds);
            },
            child: Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 24.sp,
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
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'ig_tagline'.tr(),
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            InstagramScreen._igPurple,
            InstagramScreen._igPink,
            InstagramScreen._igOrange,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: InstagramScreen._igPink.withOpacity(0.25),
            blurRadius: 24.r,
            offset: Offset(0, 12.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ig_title'.tr(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'ig_subtitle'.tr(),
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _Badge(text: 'ig_card_reels'.tr()),
              SizedBox(width: 8.w),
              _Badge(text: 'ig_card_posts'.tr()),
              SizedBox(width: 8.w),
              _Badge(text: 'ig_card_stories'.tr()),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: InstagramScreen._igSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'ig_input_hint'.tr(),
              hintStyle: TextStyle(
                color: Colors.black45,
                fontSize: 12.sp,
              ),
              prefixIcon: Icon(
                Icons.link_rounded,
                color: Colors.black45,
                size: 18.sp,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.black87),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: InstagramScreen._igPurple.withOpacity(0.4),
                    ),
                    foregroundColor: InstagramScreen._igPurple,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    'ig_action_paste'.tr(),
                    style: TextStyle(fontSize: 12.sp),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InstagramScreen._igPink,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    'ig_action_fetch'.tr(),
                    style: TextStyle(fontSize: 12.sp),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Collections extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'ig_section_collections'.tr()),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: [
              _CollectionTile(
                title: 'ig_card_reels'.tr(),
                icon: Icons.video_library_rounded,
              ),
              _CollectionTile(
                title: 'ig_card_posts'.tr(),
                icon: Icons.grid_on_rounded,
              ),
              _CollectionTile(
                title: 'ig_card_stories'.tr(),
                icon: Icons.history_toggle_off_rounded,
              ),
              _CollectionTile(
                title: 'ig_card_highlights'.tr(),
                icon: Icons.auto_awesome_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'ig_section_insights'.tr()),
          SizedBox(height: 10.h),
          _InsightRow(
            icon: Icons.auto_graph_rounded,
            title: 'ig_insight_quality'.tr(),
            subtitle: 'ig_insight_quality_desc'.tr(),
          ),
          SizedBox(height: 10.h),
          _InsightRow(
            icon: Icons.lock_outline_rounded,
            title: 'ig_insight_privacy'.tr(),
            subtitle: 'ig_insight_privacy_desc'.tr(),
          ),
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final String title;
  final IconData icon;

  const _CollectionTile({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: InstagramScreen._igSurface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: InstagramScreen._igPink, size: 16.sp),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(color: Colors.black87, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InsightRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: InstagramScreen._igSurface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.black12),
          ),
          child: Icon(icon, color: InstagramScreen._igPurple, size: 18.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 11.sp,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.black87,
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: 10.sp),
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
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 120,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}
