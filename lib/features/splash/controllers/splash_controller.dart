import 'package:flutter/animation.dart';
import 'package:get/get.dart';

import '../../../core/routes/routes.dart';

class SplashController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<double> fadeAnimation;
  late final Animation<double> scaleAnimation;

  @override
  void onInit() {
    super.onInit();
    _setupAnimations();
    _navigateToNext();
  }

  void _setupAnimations() {
    animationController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    fadeAnimation =
        CurvedAnimation(parent: animationController, curve: Curves.easeIn);

    scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeOutBack),
    );

    animationController.forward();
  }

  void _navigateToNext() {
    Future.delayed(const Duration(seconds: 3), () {
      if (isClosed) {
        return;
      }
      Get.offNamed(Routes.home);
    });
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}
