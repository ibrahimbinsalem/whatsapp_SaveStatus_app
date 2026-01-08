import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeDownloader {
  static Future<void> downloadVideo({
    required String url,
    required String quality,
    required String fileDirectory,
    required String fileName,
    required Function(double) onProgress,
  }) async {
    final yt = YoutubeExplode();
    try {
      final videoId = VideoId(url);
      final streamManifest = await yt.videos.streamsClient.getManifest(videoId);

      StreamInfo? streamInfo;

      // Try to find video stream by quality label (e.g., "720p")
      try {
        streamInfo = streamManifest.muxed.firstWhere(
          (s) => s.qualityLabel == quality,
        );
      } catch (_) {
        // If not found, try to find audio stream by bitrate (e.g., "128kbps")
        try {
          final bitrate = int.tryParse(quality.replaceAll('kbps', ''));
          if (bitrate != null) {
            streamInfo = streamManifest.audioOnly.firstWhere(
              (s) => s.bitrate.kiloBitsPerSecond.ceil() == bitrate,
            );
          }
        } catch (_) {}
      }

      if (streamInfo == null) throw Exception('Quality not found: $quality');

      final stream = yt.videos.streamsClient.get(streamInfo);
      final file = File('$fileDirectory/$fileName');
      final output = file.openWrite(mode: FileMode.write);

      int totalBytes = streamInfo.size.totalBytes;
      int receivedBytes = 0;

      await for (final data in stream) {
        receivedBytes += data.length;
        output.add(data);
        onProgress(receivedBytes / totalBytes);
      }
      await output.flush();
      await output.close();
    } finally {
      yt.close();
    }
  }
}
