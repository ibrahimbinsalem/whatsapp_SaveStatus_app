import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../instagram/views/instagram_screen.dart';
import '../../settings/views/settings_screen.dart';
import '../../youtube/views/youtube_screen.dart';
import '../controllers/main_shell_controller.dart';
import 'home_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    const screens = [
      HomeScreen(),
      YoutubeScreen(),
      InstagramScreen(),
      SettingsScreen(),
    ];

    return GetBuilder<MainShellController>(
      init: MainShellController(),
      builder: (controller) {
        return Scaffold(
          body: IndexedStack(index: controller.currentIndex, children: screens),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: controller.currentIndex,
            onTap: controller.setIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: controller.selectedColor,
            unselectedItemColor: controller.isDarkNav
                ? Colors.white54
                : Colors.grey.shade500,
            backgroundColor: controller.isDarkNav
                ? const Color(0xFF121212)
                : Colors.white,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.chat_bubble_rounded),
                label: 'nav_whatsapp'.tr(),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: 'nav_youtube'.tr(),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.camera_alt_rounded),
                label: 'nav_instagram'.tr(),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_rounded),
                label: 'nav_settings'.tr(),
              ),
            ],
          ),
        );
      },
    );
  }
}
