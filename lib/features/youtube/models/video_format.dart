import 'package:flutter/material.dart';

class VideoFormat {
  final String id;
  final String label;
  final IconData icon;
  final String quality;
  final int size;
  final bool isAudioOnly;
  final String container;

  VideoFormat({
    required this.id,
    required this.label,
    required this.icon,
    required this.quality,
    required this.size,
    required this.isAudioOnly,
    required this.container,
  });
}
