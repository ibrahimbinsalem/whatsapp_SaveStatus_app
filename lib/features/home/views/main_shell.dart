import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../instagram/views/instagram_screen.dart';
import '../../settings/views/settings_screen.dart';
import '../../youtube/views/youtube_screen.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final List<Color> _activeColors = const [
    Color(0xFF0F8A6A),
    Color(0xFFE53935),
    Color(0xFFE4405F),
    Color(0xFF4A5568),
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    YoutubeScreen(),
    InstagramScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedColor = _activeColors[_currentIndex];
    final isDarkNav = _currentIndex == 1;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: selectedColor,
        unselectedItemColor: isDarkNav ? Colors.white54 : Colors.grey.shade500,
        backgroundColor: isDarkNav ? const Color(0xFF121212) : Colors.white,
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
  }
}
