import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:whatsapp_dawnloader/features/youtube/downloader.dart';
import 'package:whatsapp_dawnloader/features/youtube/views/downloads_screen.dart';
import 'package:whatsapp_dawnloader/features/youtube/views/local_video_player_screen.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

class YoutubeScreen extends StatefulWidget {
  const YoutubeScreen({super.key});

  static const Color _ytRed = Color(0xFFE53935);
  static const Color _ytDark = Color(0xFF0F0F0F);
  static const Color _ytSurface = Color(0xFF1C1C1C);

  @override
  State<YoutubeScreen> createState() => _YoutubeScreenState();
}

class _YoutubeScreenState extends State<YoutubeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  static const MethodChannel _mediaScanner = MethodChannel(
    'whatsapp_dawnloader/media_scan',
  );

  Video? _currentVideo;
  StreamManifest? _currentManifest;
  List<VideoFormat> _availableFormats = [];
  bool _isLoading = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  String? _selectedFormatId;
  bool _isCancelDownload = false;
  List<Map<String, dynamic>> _downloadHistory = [];
  String _formatType = 'video';

  @override
  void initState() {
    super.initState();
    _loadDownloadHistory();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _yt.close();
    super.dispose();
  }

  Future<File> get _localHistoryFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/downloads_history.json');
  }

  Future<void> _loadDownloadHistory() async {
    try {
      final file = await _localHistoryFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        setState(() {
          _downloadHistory = List<Map<String, dynamic>>.from(jsonList);
        });
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
    await file.writeAsString(jsonEncode(_downloadHistory));
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _urlController.text = clipboardData.text!;
      });
    }
  }

  Future<void> _getVideoInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showToast('Please enter a YouTube URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _currentVideo = null;
      _currentManifest = null;
      _availableFormats = [];
      _selectedFormatId = null;
      _formatType = 'video';
    });

    try {
      // استخراج ID الفيديو
      final videoId = VideoId(url);

      // جلب معلومات الفيديو
      final video = await _yt.videos.get(videoId);

      // جلب التدفقات المتاحة
      final streamManifest = await _yt.videos.streamsClient.getManifest(
        videoId,
      );
      _currentManifest = streamManifest;

      // تجميع الصيغ المتاحة
      final formats = <VideoFormat>[];
      final addedQualities = <String>{};

      // 1. إضافة التدفقات المدمجة (صوت + صورة) - عادة تصل لـ 720p
      final muxedStreams = streamManifest.muxed.toList()
        ..sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));

      for (var stream in muxedStreams) {
        final containerName = _getContainerName(stream.container);
        final qualityLabel = stream.qualityLabel;

        formats.add(
          VideoFormat(
            id: stream.tag.toString(),
            label: '$containerName $qualityLabel',
            icon: Icons.videocam_rounded,
            quality: qualityLabel,
            size: stream.size.totalBytes,
            isAudioOnly: false,
            container: containerName,
          ),
        );
        addedQualities.add(qualityLabel);
      }

      // 2. إضافة تدفقات الفيديو فقط (للجودات العالية 1080p+)
      final videoOnlyStreams = streamManifest.videoOnly.toList()
        ..sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));

      for (var stream in videoOnlyStreams) {
        final qualityLabel = stream.qualityLabel;
        if (!addedQualities.contains(qualityLabel)) {
          final containerName = _getContainerName(stream.container);
          formats.add(
            VideoFormat(
              id: stream.tag.toString(),
              label: '$containerName $qualityLabel',
              icon: Icons.high_quality_rounded,
              quality: qualityLabel,
              size: stream.size.totalBytes,
              isAudioOnly: false,
              container: containerName,
            ),
          );
          addedQualities.add(qualityLabel);
        }
      }

      // إضافة صوت بجودات مختلفة
      final audioStreams = streamManifest.audioOnly;
      for (var stream in audioStreams) {
        final bitrate = stream.bitrate.kiloBitsPerSecond.ceil();
        final containerName = _getContainerName(stream.container);

        String displayLabel = containerName;
        String fileExtension = containerName;
        IconData icon = Icons.audiotrack_rounded;

        if (containerName == 'MP4' || containerName == 'M4A') {
          displayLabel = 'MP3';
          fileExtension = 'mp3';
          icon = Icons.music_note_rounded;
        }

        formats.add(
          VideoFormat(
            id: stream.tag.toString(),
            label: '$displayLabel ${bitrate}kbps',
            icon: icon,
            quality: '${bitrate}kbps',
            size: stream.size.totalBytes,
            isAudioOnly: true,
            container: fileExtension,
          ),
        );
      }

      // فرز الصيغ حسب الجودة والحجم
      formats.sort((a, b) => b.size.compareTo(a.size));

      if (!mounted) return;

      setState(() {
        _currentVideo = video;
        _availableFormats = formats;
        _isLoading = false;
      });

      _showToast('Video info loaded successfully');
    } catch (e) {
      debugPrint('YouTube Info Error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
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

  Future<bool> _requestPermission() async {
    // التحقق من إذن إدارة الملفات (للأندرويد 11+)
    if (await Permission.manageExternalStorage.isGranted) return true;

    // التحقق من إذن التخزين (للأندرويد 10 وأقل)
    if (await Permission.storage.isGranted) return true;

    // محاولة طلب إذن إدارة الملفات بشكل صريح
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    // طلب الأذونات المناسبة لجميع الإصدارات
    // (Storage للإصدارات القديمة، Videos/Audio للإصدارات الحديثة 13+)
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.videos,
      Permission.audio,
    ].request();

    // On Android 13+, we need audio/video permissions. On older versions, storage is enough.
    // This check covers both scenarios.
    if ((statuses[Permission.videos]?.isGranted ?? false) &&
            (statuses[Permission.audio]?.isGranted ?? false) ||
        (statuses[Permission.storage]?.isGranted ?? false)) {
      return true;
    }

    // معالجة الرفض الدائم
    if (statuses[Permission.storage] == PermissionStatus.permanentlyDenied ||
        statuses[Permission.videos] == PermissionStatus.permanentlyDenied ||
        statuses[Permission.audio] == PermissionStatus.permanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: YoutubeScreen._ytSurface,
            title: Text(
              'Permission Required',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Please enable Files and Media permissions in settings to save downloads.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: Text(
                  'Settings',
                  style: TextStyle(color: YoutubeScreen._ytRed),
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
    const int maxRetries = 20;    StreamInfo? currentStreamInfo;

    try {
      while (downloadedBytes < totalBytes) {
        if (_isCancelDownload) break;

        HttpClient? client;
        try {
          // تحديث الرابط (Manifest) عند البداية أو عند حدوث خطأ
          if (currentStreamInfo == null || retryCount > 0) {
            final manifest = await _yt.videos.streamsClient.getManifest(
              videoId,
            );
            currentStreamInfo = manifest.streams.firstWhere(
              (s) => s.tag == streamTag,
            );
          }

          Stream<List<int>> stream;

          if (downloadedBytes == 0) {
            // المحاولة الأولى: نستخدم عميل المكتبة الرسمي مباشرة لتجنب 403
            // هذا يضمن أن يبدأ التحميل بشكل صحيح
            stream = _yt.videos.streamsClient.get(currentStreamInfo!);
          } else {
            // محاولة الاستكمال: نستخدم HttpClient مع رابط جديد
            client = HttpClient();
            client.userAgent =
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

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

          // إضافة مهلة زمنية
          final timedStream = stream.timeout(
            const Duration(seconds: 60),
            onTimeout: (eventSink) {
              eventSink.addError(TimeoutException('Stream timed out'));
              eventSink.close();
            },
          );

          int bufferedUIBytes = 0;
          int lastUITime = DateTime.now().millisecondsSinceEpoch;

          await for (final data in timedStream) {
            if (_isCancelDownload) break;

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
          if (_isCancelDownload) break;

          // إجبار تجديد الرابط عند حدوث أي خطأ
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

  Future<void> _downloadVideo(String formatId) async {
    if (_currentVideo == null) return;

    // التحقق من إذن التخزين مع معالجة الرفض الدائم
    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      _showToast('Permission denied. Cannot save file.');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Preparing download...';
      _isCancelDownload = false;
    });

    try {
      // Get new stream links with timeout to avoid hanging
      final videoId = _currentVideo!.id;
      final streamManifest = await _yt.videos.streamsClient
          .getManifest(videoId.value)
          .timeout(const Duration(seconds: 30));

      // البحث عن التدفق المحدد
      // قد يرمي خطأ إذا لم يتم العثور عليه، مما ينقلنا لكتلة catch للمحاولة الثانية
      final streamInfo = streamManifest.streams.firstWhere(
        (s) => s.tag.toString() == formatId,
      );

      // الحصول على الصيغة المختارة
      final selectedFormat = _availableFormats.firstWhere(
        (f) => f.id == formatId,
      );

      // إنشاء اسم الملف آمن
      final safeTitle = _currentVideo!.title
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
        // حالة الجودة العالية (فيديو منفصل عن الصوت)
        final audioStream = streamManifest.audioOnly.withHighestBitrate();
        final tempVideo = File(
          '${downloadsDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        final tempAudio = File(
          '${downloadsDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );

        // حساب الحجم الكلي للتقدم
        final totalBytes =
            streamInfo.size.totalBytes + audioStream.size.totalBytes;
        var receivedVideo = 0;
        var receivedAudio = 0;

        // دالة لتحديث التقدم الموحد
        void updateProgress() {
          if (!mounted) return;

          final totalReceived = receivedVideo + receivedAudio;
          // نخصص 95% للتحميل و 5% للدمج
          final progress = (totalReceived / totalBytes) * 0.95;
          setState(() {
            _downloadProgress = progress;
            _downloadStatus =
                'جاري التحميل بسرعة عالية: ${(progress * 100).toStringAsFixed(1)}%';
          });
        }

        // تحميل الفيديو والصوت في نفس الوقت (Parallel Download)
        await Future.wait([
          _downloadStreamRaw(
            videoId,
            streamInfo.tag,
            tempVideo,
            streamInfo.size.totalBytes,
            (bytes) {
              receivedVideo += bytes;
              updateProgress();
            },
          ),
          _downloadStreamRaw(
            videoId,
            audioStream.tag,
            tempAudio,
            audioStream.size.totalBytes,
            (bytes) {
              receivedAudio += bytes;
              updateProgress();
            },
          ),
        ]);

        if (_isCancelDownload) return;

        // 3. الدمج باستخدام FFmpeg (90% -> 100%)
        setState(() {
          _downloadStatus = 'Merging audio and video...';
        });

        // تحديد كوديك الصوت بناءً على الحاوية لضمان التوافق
        final audioCodec = selectedFormat.container == 'WEBM'
            ? 'libopus'
            : 'aac';

        final session = await FFmpegKit.execute(
          '-y -i "${tempVideo.path}" -i "${tempAudio.path}" -c:v copy -c:a $audioCodec "$filePath"',
        );
        final returnCode = await session.getReturnCode();

        // حذف الملفات المؤقتة
        if (await tempVideo.exists()) await tempVideo.delete();
        if (await tempAudio.exists()) await tempAudio.delete();

        if (!ReturnCode.isSuccess(returnCode)) {
          throw Exception('Failed to merge video and audio');
        }
      } else {
        // تحميل مباشر (للملفات المدمجة أو الصوت فقط)
        final file = File(filePath);
        final totalBytes = streamInfo.size.totalBytes;
        var received = 0;

        await _downloadStreamRaw(videoId, streamInfo.tag, file, totalBytes, (
          bytes,
        ) {
          received += bytes;
          if (mounted) {
            final progress = received / totalBytes;
            setState(() {
              _downloadProgress = progress;
              _downloadStatus =
                  'جاري التحميل: ${(progress * 100).toStringAsFixed(1)}%';
            });
          }
        });
      }

      // Cancel the download if the user presses the stop button before the download starts.
      if (_isCancelDownload) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        if (mounted) {
          setState(() {
            _downloadStatus = 'Download cancelled';
            _isDownloading = false;
          });
        }
        return;
      }

      if (!mounted) return;

      await _scanFile(filePath);

      setState(() {
        _downloadStatus = 'تم التنزيل بنجاح!';
        _isDownloading = false;

        // إضافة إلى سجل التنزيلات
        final downloadItem = {
          'title': fileName,
          'path': filePath,
          'type': isAudio ? 'audio' : 'video',
          'date': DateTime.now().toIso8601String(),
          'size': _formatFileSize(selectedFormat.size),
          'sizeBytes': selectedFormat.size,
          'durationMs': _currentVideo?.duration?.inMilliseconds,
          'thumbUrl': _currentVideo?.thumbnails.highResUrl,
        };
        _downloadHistory.insert(0, downloadItem);
        _saveDownloadHistory();
      });

      _showDownloadSnackBar(
        filePath: filePath,
        title: fileName,
        isAudio: isAudio,
        coverUrl: _currentVideo?.thumbnails.highResUrl,
      );
    } catch (e) {
      debugPrint('🔴 Download Error: $e');
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadStatus = 'Failed';
      });
      _showToast('Error: $e');
    } finally {
      // client.close();
    }
  }

  void _navigateToDownloads() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DownloadsScreen()),
    ).then((_) => _loadDownloadHistory());
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

  void _showDownloadSnackBar({
    required String filePath,
    required String title,
    required bool isAudio,
    String? coverUrl,
  }) {
    if (!mounted) {
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YoutubeScreen._ytDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F0F0F), Color(0xFF1A1A1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: _GlowBubble(
              size: 220,
              color: YoutubeScreen._ytRed.withOpacity(0.18),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -90,
            child: _GlowBubble(
              size: 260,
              color: const Color(0xFFFF6D6D).withOpacity(0.16),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(onDownloadsPressed: _navigateToDownloads),
                  SizedBox(height: 18.h),
                  _HeroCard(),
                  SizedBox(height: 16.h),
                  _InputCard(
                    urlController: _urlController,
                    onPastePressed: _pasteFromClipboard,
                    onPreparePressed: _getVideoInfo,
                    isLoading: _isLoading,
                  ),

                  // عرض معلومات الفيديو
                  if (_currentVideo != null) ...[
                    SizedBox(height: 16.h),
                    _VideoInfoCard(
                      video: _currentVideo!,
                      duration: _formatDuration(_currentVideo!.duration),
                    ),
                  ],

                  // عرض خيارات التنزيل (فيديو / صوت)
                  if (_availableFormats.isNotEmpty) ...[
                    SizedBox(height: 20.h),
                    _FormatTypeSelector(
                      selectedType: _formatType,
                      onTypeChanged: (type) {
                        setState(() {
                          _formatType = type;
                          _selectedFormatId = null;
                        });
                      },
                    ),
                    SizedBox(height: 16.h),
                  ],

                  if (_availableFormats.any(
                    (f) =>
                        _formatType == 'video' ? !f.isAudioOnly : f.isAudioOnly,
                  )) ...[
                    _FormatsRow(
                      formats: _availableFormats
                          .where(
                            (f) => _formatType == 'video'
                                ? !f.isAudioOnly
                                : f.isAudioOnly,
                          )
                          .toList(),
                      selectedFormatId: _selectedFormatId,
                      onFormatSelected: (formatId) {
                        setState(() {
                          _selectedFormatId = formatId;
                        });
                      },
                      onDownloadPressed: _selectedFormatId != null
                          ? () => _downloadVideo(_selectedFormatId!)
                          : null,
                      onCancel: _isDownloading
                          ? () {
                              setState(() {
                                _isCancelDownload = true;
                              });
                            }
                          : null,
                      isDownloading: _isDownloading,
                      downloadProgress: _downloadProgress,
                      downloadStatus: _downloadStatus,
                      formatFileSize: _formatFileSize,
                    ),
                  ],

                  SizedBox(height: 20.h),
                  _SectionHeader(title: 'yt_section_recent'.tr()),
                  SizedBox(height: 10.h),

                  // عرض التحميلات الحديثة
                  if (_downloadHistory.isNotEmpty)
                    _RecentDownloadsList(
                      recentDownloads: _downloadHistory.take(3).toList(),
                    )
                  else
                    _EmptyState(
                      title: 'yt_empty_recent'.tr(),
                      subtitle: 'yt_subtitle'.tr(),
                    ),
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
  final VoidCallback onDownloadsPressed;

  const _TopBar({required this.onDownloadsPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: YoutubeScreen._ytRed,
            size: 28.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'yt_title'.tr(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'yt_tagline'.tr(),
                style: TextStyle(color: Colors.white70, fontSize: 11.sp),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onDownloadsPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          icon: Icon(
            Icons.download_done_rounded,
            color: Colors.white,
            size: 24.sp,
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
          colors: [YoutubeScreen._ytRed, Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: YoutubeScreen._ytRed.withOpacity(0.35),
            blurRadius: 24.r,
            offset: Offset(0, 12.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'yt_title'.tr(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'yt_subtitle'.tr(),
            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              _ActionChip(
                text: 'yt_format_video'.tr(),
                icon: Icons.movie_creation_outlined,
              ),
              SizedBox(width: 10.w),
              _ActionChip(
                text: 'yt_format_audio'.tr(),
                icon: Icons.audiotrack_rounded,
              ),
              SizedBox(width: 10.w),
              _ActionChip(
                text: 'yt_format_playlist'.tr(),
                icon: Icons.queue_music_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final TextEditingController urlController;
  final VoidCallback onPastePressed;
  final VoidCallback onPreparePressed;
  final bool isLoading;

  const _InputCard({
    required this.urlController,
    required this.onPastePressed,
    required this.onPreparePressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: YoutubeScreen._ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          TextField(
            controller: urlController,
            decoration: InputDecoration(
              hintText: 'yt_input_hint'.tr(),
              hintStyle: TextStyle(color: Colors.white54, fontSize: 12.sp),
              prefixIcon: Icon(
                Icons.link_rounded,
                color: Colors.white54,
                size: 18.sp,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPastePressed,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    'yt_action_paste'.tr(),
                    style: TextStyle(fontSize: 12.sp),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : onPreparePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: YoutubeScreen._ytRed,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'yt_action_prepare'.tr(),
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

class _VideoInfoCard extends StatelessWidget {
  final Video video;
  final String duration;

  const _VideoInfoCard({required this.video, required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: YoutubeScreen._ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 80.w,
                height: 60.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  image: DecorationImage(
                    image: NetworkImage(video.thumbnails.mediumResUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 4.h,
                right: 4.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    duration,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 4.h),
                Text(
                  '${video.author} • ${video.engagement.viewCount.formatViews()} views',
                  style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatsRow extends StatelessWidget {
  final List<VideoFormat> formats;
  final String? selectedFormatId;
  final Function(String) onFormatSelected;
  final VoidCallback? onDownloadPressed;
  final VoidCallback? onCancel;
  final bool isDownloading;
  final double downloadProgress;
  final String downloadStatus;
  final String Function(int) formatFileSize;

  const _FormatsRow({
    required this.formats,
    required this.selectedFormatId,
    required this.onFormatSelected,
    required this.onDownloadPressed,
    this.onCancel,
    required this.isDownloading,
    required this.downloadProgress,
    required this.downloadStatus,
    required this.formatFileSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: YoutubeScreen._ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'yt_section_formats'.tr()),
          SizedBox(height: 10.h),

          // عرض تقدم التحميل إذا كان قيد التنفيذ
          if (isDownloading) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: downloadProgress,
                              backgroundColor: Colors.white12,
                              color: YoutubeScreen._ytRed,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              downloadStatus,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      IconButton(
                        onPressed: onCancel,
                        icon: const Icon(
                          Icons.stop_circle_rounded,
                          color: YoutubeScreen._ytRed,
                        ),
                        tooltip: 'إيقاف التحميل',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
          ],

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
              childAspectRatio: 3.0,
            ),
            itemCount: formats.length,
            itemBuilder: (context, index) {
              final format = formats[index];
              final isSelected = selectedFormatId == format.id;
              return GestureDetector(
                onTap: () => onFormatSelected(format.id),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? YoutubeScreen._ytRed.withOpacity(0.2)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSelected ? YoutubeScreen._ytRed : Colors.white12,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        format.icon,
                        color: isSelected ? Colors.white : Colors.white70,
                        size: 16.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              format.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 10.sp,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (format.size > 0)
                              Text(
                                formatFileSize(format.size),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.white54,
                                  fontSize: 8.sp,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // زر التحميل
          if (selectedFormatId != null && !isDownloading) ...[
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDownloadPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: YoutubeScreen._ytRed,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_rounded, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'yt_action_download'.tr(),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentDownloadsList extends StatelessWidget {
  final List<Map<String, dynamic>> recentDownloads;

  const _RecentDownloadsList({required this.recentDownloads});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: recentDownloads
          .map(
            (download) => Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: YoutubeScreen._ytSurface,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(
                    download['type'] == 'audio'
                        ? Icons.music_note_rounded
                        : Icons.videocam_rounded,
                    color: download['type'] == 'audio'
                        ? Colors.green
                        : YoutubeScreen._ytRed,
                    size: 18.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      download['title'] ?? '',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.sp,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 18.sp,
                      color: Colors.white54,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
          )
          .toList(),
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
        color: Colors.white,
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: YoutubeScreen._ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            color: Colors.white54,
            size: 28.sp,
          ),
          SizedBox(height: 10.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 13.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String text;
  final IconData icon;

  const _ActionChip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14.sp),
          SizedBox(width: 6.w),
          Text(
            text,
            style: TextStyle(color: Colors.white, fontSize: 11.sp),
          ),
        ],
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
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 20)],
      ),
    );
  }
}

// نموذج لتخزين معلومات الصيغة
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

// امتداد لتنسيق عرض المشاهدات
extension ViewCountExtension on int {
  String formatViews() {
    if (this < 1000) return toString();
    if (this < 1000000) return '${(this / 1000).toStringAsFixed(1)}K';
    if (this < 1000000000) return '${(this / 1000000).toStringAsFixed(1)}M';
    return '${(this / 1000000000).toStringAsFixed(1)}B';
  }
}

class _FormatTypeSelector extends StatelessWidget {
  final String selectedType;
  final Function(String) onTypeChanged;

  const _FormatTypeSelector({
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: YoutubeScreen._ytSurface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeButton(
              title: 'yt_format_video'.tr(),
              icon: Icons.videocam_rounded,
              isSelected: selectedType == 'video',
              onTap: () => onTypeChanged('video'),
            ),
          ),
          Expanded(
            child: _TypeButton(
              title: 'yt_format_audio'.tr(),
              icon: Icons.audiotrack_rounded,
              isSelected: selectedType == 'audio',
              onTap: () => onTypeChanged('audio'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? YoutubeScreen._ytRed : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white54,
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
