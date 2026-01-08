import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MainShellController extends GetxController {
  int currentIndex = 0;

  final List<Color> activeColors = const [
    Color(0xFF0F8A6A),
    Color(0xFFE53935),
    Color(0xFFE4405F),
    Color(0xFF4A5568),
  ];

  void setIndex(int index) {
    currentIndex = index;
    update();
  }

  Color get selectedColor => activeColors[currentIndex];

  bool get isDarkNav => currentIndex == 1;
}
