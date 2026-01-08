import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/video_format.dart';
import '../views/downloads_screen.dart';
import '../views/local_video_player_screen.dart';

class YoutubeController extends GetxController {
  final TextEditingController urlController = TextEditingController();
  final YoutubeExplode yt = YoutubeExplode();

  static const MethodChannel _mediaScanner = MethodChannel(
    'whatsapp_dawnloader/media_scan',
  );

  Video? currentVideo;
  StreamManifest? currentManifest;
  List<VideoFormat> availableFormats = [];
  bool isLoading = false;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  String downloadStatus = '';
  String? selectedFormatId;
  bool isCancelDownload = false;
  List<Map<String, dynamic>> downloadHistory = [];

  @override
  void onInit() {
    super.onInit();
    loadDownloadHistory();
  }

  @override
  void onClose() {
    urlController.dispose();
    yt.close();
    super.onClose();
  }

  Future<File> get _localHistoryFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/downloads_history.json');
  }

  Future<void> loadDownloadHistory() async {
    try {
      final file = await _localHistoryFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        downloadHistory = List<Map<String, dynamic>>.from(jsonList);
        update();
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _scanFile(String path) async {
    try {
      await _mediaScanner.invokeMethod('scanFile', {'path': path});
    } catch (_) {}
  }

  Future<void> _saveDownloadHistory() async {
    final file = await _localHistoryFile;
    await file.writeAsString(jsonEncode(downloadHistory));
  }

  Future<void> pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      urlController.text = clipboardData.text!;
      update();
    }
  }

  Future<void> getVideoInfo() async {
    final url = urlController.text.trim();
    if (url.isEmpty) {
      _showToast('Please enter a YouTube URL');
      return;
    }

    isLoading = true;
    currentVideo = null;
    currentManifest = null;
    availableFormats = [];
    selectedFormatId = null;
    update();

    try {
      final videoId = VideoId(url);
      final video = await yt.videos.get(videoId);
      final streamManifest = await yt.videos.streamsClient.getManifest(
        videoId,
      );
      currentManifest = streamManifest;

      final formats = <VideoFormat>[];
      final allVideoStreams = [
        ...streamManifest.muxed,
        ...streamManifest.videoOnly,
      ];

      final qualityGroups = <String, List<VideoStreamInfo>>{};
      for (var stream in allVideoStreams) {
        final label = stream.qualityLabel;
        qualityGroups.putIfAbsent(label, () => []).add(stream);
      }

      for (var entry in qualityGroups.entries) {
        final label = entry.key;
        final streams = entry.value;

        if (!label.contains('360')) continue;

        streams.sort((a, b) {
          final aIsMuxed = a is MuxedStreamInfo;
          final bIsMuxed = b is MuxedStreamInfo;
          if (aIsMuxed && !bIsMuxed) return -1;
          if (!aIsMuxed && bIsMuxed) return 1;
          return b.size.totalBytes.compareTo(a.size.totalBytes);
        });

        final bestStream = streams.first;
        final containerName = _getContainerName(bestStream.container);

        formats.add(
          VideoFormat(
            id: bestStream.tag.toString(),
            label: '$containerName $label',
            icon: bestStream is MuxedStreamInfo
                ? Icons.videocam_rounded
                : Icons.high_quality_rounded,
            quality: label,
            size: bestStream.size.totalBytes,
            isAudioOnly: false,
            container: containerName,
          ),
        );
      }

      formats.sort((a, b) => b.size.compareTo(a.size));

      currentVideo = video;
      availableFormats = formats;
      isLoading = false;
      update();

      _showToast('Video info loaded successfully');
    } catch (e) {
      debugPrint('YouTube Info Error: $e');
      isLoading = false;
      update();
      _showToast('Error: ${e.toString()}');
    }
  }

  String _getContainerName(dynamic container) {
    if (container.toString().contains('mp4')) return 'MP4';
    if (container.toString().contains('webm')) return 'WEBM';
    if (container.toString().contains('mp3')) return 'MP3';
    if (container.toString().contains('m4a')) return 'M4A';
    return 'VIDEO';
  }

  Future<bool> _requestPermission(BuildContext context) async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.storage.isGranted) return true;

    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.videos,
      Permission.audio,
    ].request();

    if ((statuses[Permission.videos]?.isGranted ?? false) &&
            (statuses[Permission.audio]?.isGranted ?? false) ||
        (statuses[Permission.storage]?.isGranted ?? false)) {
      return true;
    }

    if (statuses[Permission.storage] == PermissionStatus.permanentlyDenied ||
        statuses[Permission.videos] == PermissionStatus.permanentlyDenied ||
        statuses[Permission.audio] == PermissionStatus.permanentlyDenied) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1C),
            title: const Text(
              'Permission Required',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Please enable Files and Media permissions in settings to save downloads.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text(
                  'Settings',
                  style: TextStyle(color: Color(0xFFE53935)),
                ),
              ),
            ],
          ),
        );
      }
      return false;
    }
    return false;
  }

  Future<void> _downloadStreamRaw(
    VideoId videoId,
    int streamTag,
    File file,
    int totalBytes,
    Function(int bytes) onBytesReceived,
  ) async {
    if (await file.exists()) {
      await file.delete();
    }

    final sink = file.openWrite();
    int downloadedBytes = 0;
    int retryCount = 0;
    const int maxRetries = 20;
    StreamInfo? currentStreamInfo;

    try {
      while (downloadedBytes < totalBytes) {
        if (isCancelDownload) break;

        HttpClient? client;
        try {
          if (currentStreamInfo == null || retryCount > 0) {
            final manifest = await yt.videos.streamsClient.getManifest(
              videoId,
            );
            currentStreamInfo = manifest.streams.firstWhere(
              (s) => s.tag == streamTag,
            );
          }

          Stream<List<int>> stream;

          if (downloadedBytes == 0) {
            stream = yt.videos.streamsClient.get(currentStreamInfo!);
          } else {
            client = HttpClient();
            final request = await client.getUrl(currentStreamInfo!.url);
            request.headers.add(
              HttpHeaders.rangeHeader,
              'bytes=$downloadedBytes-',
            );

            final response = await request.close();

            if (response.statusCode >= 400) {
              throw Exception(
                'HTTP Error: ${response.statusCode} ${response.reasonPhrase}',
              );
            }
            stream = response;
          }

          final timedStream = stream.timeout(
            const Duration(seconds: 90),
            onTimeout: (eventSink) {
              eventSink.addError(TimeoutException('Stream timed out'));
              eventSink.close();
            },
          );

          int bufferedUIBytes = 0;
          int lastUITime = DateTime.now().millisecondsSinceEpoch;

          await for (final data in timedStream) {
            if (isCancelDownload) break;

            sink.add(data);
            downloadedBytes += data.length;

            bufferedUIBytes += data.length;
            final now = DateTime.now().millisecondsSinceEpoch;

            if (bufferedUIBytes > 100 * 1024 || now - lastUITime > 200) {
              onBytesReceived(bufferedUIBytes);
              bufferedUIBytes = 0;
              lastUITime = now;
            }

            retryCount = 0;
          }

          if (bufferedUIBytes > 0) {
            onBytesReceived(bufferedUIBytes);
          }

          if (downloadedBytes >= totalBytes) {
            break;
          }

          throw Exception('Connection closed prematurely');
        } catch (e) {
          if (isCancelDownload) break;

          currentStreamInfo = null;

          retryCount++;
          debugPrint(
            'Download error at $downloadedBytes bytes: $e. Retry $retryCount/$maxRetries',
          );

          if (retryCount > maxRetries) {
            throw Exception(
              'Failed to download after $maxRetries retries. Error: $e',
            );
          }

          await Future.delayed(Duration(seconds: retryCount));
        } finally {
          client?.close();
        }
      }

      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<void> downloadVideo(BuildContext context, String formatId) async {
    if (currentVideo == null) return;

    final hasPermission = await _requestPermission(context);
    if (!hasPermission) {
      _showToast('Permission denied. Cannot save file.');
      return;
    }

    isDownloading = true;
    downloadProgress = 0.0;
    downloadStatus = 'Preparing download...';
    isCancelDownload = false;
    update();

    try {
      final videoId = currentVideo!.id;
      final streamManifest = await yt.videos.streamsClient
          .getManifest(videoId.value)
          .timeout(const Duration(seconds: 30));

      final streamInfo = streamManifest.streams.firstWhere(
        (s) => s.tag.toString() == formatId,
      );

      final selectedFormat = availableFormats.firstWhere(
        (f) => f.id == formatId,
      );

      final safeTitle = currentVideo!.title
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final fileName =
          '${safeTitle.substring(0, safeTitle.length < 50 ? safeTitle.length : 50)}_${selectedFormat.quality}.${selectedFormat.container.toLowerCase()}'
              .replaceAll(' ', '_');

      final isAudio = selectedFormat.isAudioOnly;
      final downloadsDir = Directory(
        isAudio
            ? '/storage/emulated/0/Music/WhatsappDownloader'
            : '/storage/emulated/0/Movies/WhatsappDownloader',
      );
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final filePath = '${downloadsDir.path}/$fileName';

      if (streamInfo is VideoOnlyStreamInfo) {
        final audioStream = streamManifest.audioOnly.withHighestBitrate();
        final tempVideo = File(
          '${downloadsDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        final tempAudio = File(
          '${downloadsDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );

        final totalBytes =
            streamInfo.size.totalBytes + audioStream.size.totalBytes;
        var receivedVideo = 0;
        var receivedAudio = 0;

        void updateProgress() {
          if (isClosed) return;

          final totalReceived = receivedVideo + receivedAudio;
          final progress = (totalReceived / totalBytes) * 0.95;
          downloadProgress = progress;
          downloadStatus =
              'جاري التحميل بسرعة عالية: ${(progress * 100).toStringAsFixed(1)}%';
          update();
        }

        await _downloadStreamRaw(
          videoId,
          streamInfo.tag,
          tempVideo,
          streamInfo.size.totalBytes,
          (bytes) {
            receivedVideo += bytes;
            updateProgress();
          },
        );

        if (isCancelDownload) return;

        await _downloadStreamRaw(
          videoId,
          audioStream.tag,
          tempAudio,
          audioStream.size.totalBytes,
          (bytes) {
            receivedAudio += bytes;
            updateProgress();
          },
        );

        if (isCancelDownload) return;

        downloadStatus = 'Merging audio and video...';
        update();

        final audioCodec = selectedFormat.container == 'WEBM'
            ? 'libopus'
            : 'aac';

        final session = await FFmpegKit.execute(
          '-y -i "${tempVideo.path}" -i "${tempAudio.path}" -c:v copy -c:a $audioCodec "$filePath"',
        );
        final returnCode = await session.getReturnCode();

        if (await tempVideo.exists()) await tempVideo.delete();
        if (await tempAudio.exists()) await tempAudio.delete();

        if (!ReturnCode.isSuccess(returnCode)) {
          throw Exception('Failed to merge video and audio');
        }
      } else {
        final file = File(filePath);
        final totalBytes = streamInfo.size.totalBytes;
        var received = 0;

        await _downloadStreamRaw(videoId, streamInfo.tag, file, totalBytes,
            (bytes) {
          received += bytes;
          if (isClosed) {
            return;
          }
          final progress = received / totalBytes;
          downloadProgress = progress;
          downloadStatus =
              'جاري التحميل: ${(progress * 100).toStringAsFixed(1)}%';
          update();
        });
      }

      if (isCancelDownload) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        downloadStatus = 'Download cancelled';
        isDownloading = false;
        update();
        return;
      }

      await _scanFile(filePath);

      downloadStatus = 'تم التنزيل بنجاح!';
      isDownloading = false;

      final downloadItem = {
        'title': fileName,
        'path': filePath,
        'type': isAudio ? 'audio' : 'video',
        'date': DateTime.now().toIso8601String(),
        'size': formatFileSize(selectedFormat.size),
        'sizeBytes': selectedFormat.size,
        'durationMs': currentVideo?.duration?.inMilliseconds,
        'thumbUrl': currentVideo?.thumbnails.highResUrl,
      };
      downloadHistory.insert(0, downloadItem);
      await _saveDownloadHistory();
      update();

      _showDownloadSnackBar(
        context,
        filePath: filePath,
        title: fileName,
        isAudio: isAudio,
        coverUrl: currentVideo?.thumbnails.highResUrl,
      );
    } catch (e) {
      debugPrint('🔴 Download Error: $e');
      isDownloading = false;
      downloadStatus = 'Failed';
      update();
      _showToast('Error: $e');
    }
  }

  void navigateToDownloads(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DownloadsScreen()),
    ).then((_) => loadDownloadHistory());
  }

  void selectFormat(String formatId) {
    selectedFormatId = formatId;
    update();
  }

  void cancelDownload() {
    isCancelDownload = true;
    update();
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14.0.sp,
    );
  }

  void _showDownloadSnackBar(
    BuildContext context, {
    required String filePath,
    required String title,
    required bool isAudio,
    String? coverUrl,
  }) {
    if (!context.mounted) {
      return;
    }
    final label = isAudio
        ? 'تم حفظ الصوت في الموسيقى'
        : 'تم حفظ الفيديو في المعرض';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label),
        action: SnackBarAction(
          label: 'فتح',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LocalVideoPlayerScreen(
                  filePath: filePath,
                  title: title,
                  coverUrl: coverUrl,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
