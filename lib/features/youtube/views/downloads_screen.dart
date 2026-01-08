import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:whatsapp_dawnloader/features/youtube/views/local_video_player_screen.dart';

const Color _ytRed = Color(0xFFE53935);
const Color _ytDark = Color(0xFF0F0F0F);
const Color _ytSurface = Color(0xFF1C1C1C);

enum _DownloadFilter { all, video, audio }

enum _DownloadAction { details, rename, convertMp3, delete }

enum _DownloadSort { newest, oldest, sizeDesc, sizeAsc, nameAsc, nameDesc }

enum _AudioPlaylistMode { latest, mostPlayed }

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  static const MethodChannel _mediaScanner =
      MethodChannel('whatsapp_dawnloader/media_scan');
  List<Map<String, dynamic>> _downloadHistory = [];
  _DownloadFilter _selectedFilter = _DownloadFilter.all;
  _DownloadSort _selectedSort = _DownloadSort.newest;
  _AudioPlaylistMode _playlistMode = _AudioPlaylistMode.latest;
  final Map<String, String?> _thumbnailCache = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _totalBytes = 0;
  Set<String> _favoritePaths = {};
  Map<String, int> _playCounts = {};
  bool _favoritesOnly = false;
  double? _minSizeMb;
  double? _maxSizeMb;
  Duration? _minDuration;
  Duration? _maxDuration;
  PermissionStatus _storageStatus = PermissionStatus.denied;
  PermissionStatus _manageStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  bool _permissionLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadHistory();
    _loadPreferences();
    _loadPermissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
        if (!mounted) {
          return;
        }
        setState(() {
          _downloadHistory = List<Map<String, dynamic>>.from(jsonList);
        });
        await _syncSizes();
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('yt_favorites') ?? [];
    final playCountsRaw = prefs.getString('yt_play_counts');
    final playCounts = <String, int>{};
    if (playCountsRaw != null && playCountsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(playCountsRaw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          playCounts[entry.key] = (entry.value as num).toInt();
        }
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _favoritePaths = favorites.toSet();
      _playCounts = playCounts;
    });
  }

  Future<void> _scanFile(String path) async {
    try {
      await _mediaScanner.invokeMethod('scanFile', {'path': path});
    } catch (_) {}
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('yt_favorites', _favoritePaths.toList());
  }

  Future<void> _persistPlayCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yt_play_counts', jsonEncode(_playCounts));
  }

  Future<void> _loadPermissions() async {
    try {
      final storage = await Permission.storage.status;
      final manage = await Permission.manageExternalStorage.status;
      final notification = await Permission.notification.status;
      if (!mounted) {
        return;
      }
      setState(() {
        _storageStatus = storage;
        _manageStatus = manage;
        _notificationStatus = notification;
        _permissionLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _permissionLoading = false;
      });
    }
  }

  List<Map<String, String>> _buildAudioQueue() {
    final items = _downloadHistory
        .where((item) => item['type'] == 'audio')
        .toList();
    items.sort((a, b) {
      if (_playlistMode == _AudioPlaylistMode.mostPlayed) {
        final aCount = _playCountFor(a['path']?.toString() ?? '');
        final bCount = _playCountFor(b['path']?.toString() ?? '');
        if (aCount != bCount) {
          return bCount.compareTo(aCount);
        }
      }
      return _parseDate(b).compareTo(_parseDate(a));
    });
    return items
        .map(
          (item) => {
            'path': item['path']?.toString() ?? '',
            'title': item['title']?.toString() ?? 'Audio',
            'coverPath': item['coverPath']?.toString() ?? '',
            'coverUrl': item['thumbUrl']?.toString() ?? '',
          },
        )
        .where((item) => item['path']!.isNotEmpty)
        .toList();
  }

  int _audioIndexForPath(
    String path,
    List<Map<String, String>> queue,
  ) {
    final index = queue.indexWhere((item) => item['path'] == path);
    return index == -1 ? 0 : index;
  }

  void _openAudioPlayer({String? path}) {
    final queue = _buildAudioQueue();
    if (queue.isEmpty) {
      return;
    }
    final initialIndex = path == null ? 0 : _audioIndexForPath(path, queue);
    final initialPath = queue[initialIndex]['path'] ?? '';
    _registerPlay(initialPath);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocalVideoPlayerScreen(
          filePath: initialPath,
          title: queue[initialIndex]['title'] ?? 'Audio',
          coverPath: queue[initialIndex]['coverPath'],
          coverUrl: queue[initialIndex]['coverUrl'],
          playlist: queue,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _syncSizes() async {
    var changed = false;
    var totalBytes = 0;
    for (final entry in _downloadHistory) {
      final path = entry['path']?.toString() ?? '';
      if (path.isEmpty) {
        continue;
      }
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.length();
        totalBytes += bytes;
        if (entry['sizeBytes'] != bytes) {
          entry['sizeBytes'] = bytes;
          entry['size'] = _formatBytes(bytes);
          changed = true;
        }
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _totalBytes = totalBytes;
    });
    if (changed) {
      await _persistHistory();
    }
  }

  Future<void> _persistHistory() async {
    final historyFile = await _localHistoryFile;
    await historyFile.writeAsString(jsonEncode(_downloadHistory));
  }

  Future<String?> _loadThumbnail(String path) async {
    if (_thumbnailCache.containsKey(path)) {
      return _thumbnailCache[path];
    }
    try {
      final directory = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: path,
        thumbnailPath: directory.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        quality: 75,
      );
      _thumbnailCache[path] = thumbPath;
      return thumbPath;
    } catch (e) {
      debugPrint('Thumbnail error: $e');
      _thumbnailCache[path] = null;
      return null;
    }
  }

  Future<String?> _createCoverFromVideo(String path) async {
    try {
      final directory = await getTemporaryDirectory();
      return await VideoThumbnail.thumbnailFile(
        video: path,
        thumbnailPath: directory.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 85,
      );
    } catch (e) {
      debugPrint('Cover error: $e');
      return null;
    }
  }

  String _fileExtension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot == -1) {
      return '';
    }
    return name.substring(dot);
  }

  String _fileBaseName(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot == -1) {
      return name;
    }
    return name.substring(0, dot);
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  String _resolveUniquePath(String dir, String name, String ext) {
    var candidate = '$dir/$name$ext';
    var counter = 1;
    while (File(candidate).existsSync()) {
      candidate = '$dir/${name}_$counter$ext';
      counter += 1;
    }
    return candidate;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  int _durationMs(Map<String, dynamic> item) {
    return (item['durationMs'] as int?) ?? 0;
  }

  int _playCountFor(String path) => _playCounts[path] ?? 0;

  bool _isFavoritePath(String path) => _favoritePaths.contains(path);

  Future<void> _toggleFavorite(Map<String, dynamic> item) async {
    final path = item['path']?.toString() ?? '';
    if (path.isEmpty) {
      return;
    }
    final next = <String>{..._favoritePaths};
    if (next.contains(path)) {
      next.remove(path);
    } else {
      next.add(path);
    }
    setState(() {
      _favoritePaths = next;
    });
    await _persistFavorites();
  }

  Future<void> _registerPlay(String path) async {
    if (path.isEmpty) {
      return;
    }
    final next = Map<String, int>.from(_playCounts);
    next[path] = (next[path] ?? 0) + 1;
    setState(() {
      _playCounts = next;
    });
    await _persistPlayCounts();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  List<Map<String, dynamic>> get _filteredDownloads {
    Iterable<Map<String, dynamic>> items = _downloadHistory;
    if (_selectedFilter != _DownloadFilter.all) {
      final isAudio = _selectedFilter == _DownloadFilter.audio;
      items = items.where((item) => (item['type'] == 'audio') == isAudio);
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        return title.contains(query);
      });
    }
    if (_favoritesOnly) {
      items = items.where((item) {
        final path = item['path']?.toString() ?? '';
        return _isFavoritePath(path);
      });
    }
    if (_minSizeMb != null || _maxSizeMb != null) {
      items = items.where((item) {
        final bytes = _sizeBytes(item);
        final sizeMb = bytes / 1048576;
        if (_minSizeMb != null && sizeMb < _minSizeMb!) {
          return false;
        }
        if (_maxSizeMb != null && sizeMb > _maxSizeMb!) {
          return false;
        }
        return true;
      });
    }
    if (_minDuration != null || _maxDuration != null) {
      items = items.where((item) {
        final durationMs = _durationMs(item);
        final duration = Duration(milliseconds: durationMs);
        if (_minDuration != null && duration < _minDuration!) {
          return false;
        }
        if (_maxDuration != null && duration > _maxDuration!) {
          return false;
        }
        return true;
      });
    }
    final list = items.toList();
    list.sort((a, b) => _compareItems(a, b));
    return list;
  }

  int _compareItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    switch (_selectedSort) {
      case _DownloadSort.oldest:
        return _parseDate(a).compareTo(_parseDate(b));
      case _DownloadSort.sizeDesc:
        return _sizeBytes(b).compareTo(_sizeBytes(a));
      case _DownloadSort.sizeAsc:
        return _sizeBytes(a).compareTo(_sizeBytes(b));
      case _DownloadSort.nameAsc:
        return _titleOf(a).compareTo(_titleOf(b));
      case _DownloadSort.nameDesc:
        return _titleOf(b).compareTo(_titleOf(a));
      case _DownloadSort.newest:
      default:
        return _parseDate(b).compareTo(_parseDate(a));
    }
  }

  DateTime _parseDate(Map<String, dynamic> item) {
    final raw = item['date']?.toString() ?? '';
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _sizeBytes(Map<String, dynamic> item) {
    return (item['sizeBytes'] as int?) ?? 0;
  }

  String _titleOf(Map<String, dynamic> item) {
    return (item['title'] ?? '').toString().toLowerCase();
  }

  int get _videoCount =>
      _downloadHistory.where((item) => item['type'] != 'audio').length;

  int get _audioCount =>
      _downloadHistory.where((item) => item['type'] == 'audio').length;

  String _formatDateLabel(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) {
      return 'غير معروف';
    }
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) {
      return rawDate.split('T').first;
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '${parsed.year}/$month/$day';
  }

  String _lastDownloadLabel() {
    if (_downloadHistory.isEmpty) {
      return 'لا يوجد';
    }
    final dates = _downloadHistory
        .map((item) => DateTime.tryParse(item['date']?.toString() ?? ''))
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) {
      return 'غير معروف';
    }
    dates.sort((a, b) => b.compareTo(a));
    return _formatDateLabel(dates.first.toIso8601String());
  }

  Future<void> _deleteItem(int index) async {
    try {
      final item = _filteredDownloads[index];
      final file = File(item['path']);
      if (await file.exists()) {
        await file.delete();
      }

      setState(() {
        _downloadHistory.removeWhere((entry) => entry['path'] == item['path']);
      });
      _thumbnailCache.remove(item['path']);
      _favoritePaths.remove(item['path']);
      _playCounts.remove(item['path']);

      await _persistHistory();
      await _persistFavorites();
      await _persistPlayCounts();
      await _syncSizes();
    } catch (e) {
      debugPrint('Error deleting item: $e');
    }
  }

  Future<void> _clearAllDownloads() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _ytSurface,
        title: const Text('حذف كل التنزيلات', style: TextStyle(color: Colors.white)),
        content: Text(
          'سيتم حذف جميع الملفات من الجهاز.',
          style: TextStyle(color: Colors.white70, fontSize: 12.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: _ytRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    for (final item in _downloadHistory) {
      final path = item['path']?.toString() ?? '';
      if (path.isEmpty) {
        continue;
      }
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _downloadHistory.clear();
      _thumbnailCache.clear();
      _totalBytes = 0;
      _favoritePaths.clear();
      _playCounts.clear();
    });
    await _persistHistory();
    await _persistFavorites();
    await _persistPlayCounts();
  }

  Future<void> _renameItem(Map<String, dynamic> item) async {
    final path = item['path']?.toString() ?? '';
    if (path.isEmpty) {
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      Fluttertoast.showToast(msg: 'الملف غير موجود');
      return;
    }

    final baseName = _fileBaseName(path);
    final extension = _fileExtension(path);
    final controller = TextEditingController(text: baseName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _ytSurface,
        title: const Text(
          'إعادة تسمية الملف',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'اسم جديد',
            hintStyle: TextStyle(color: Colors.white54, fontSize: 12.sp),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: _ytRed),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('حفظ', style: TextStyle(color: _ytRed)),
          ),
        ],
      ),
    );

    if (newName == null) {
      return;
    }
    final sanitized = _sanitizeFileName(newName);
    if (sanitized.isEmpty) {
      Fluttertoast.showToast(msg: 'الاسم غير صالح');
      return;
    }

    final dir = file.parent.path;
    final newPath = _resolveUniquePath(dir, sanitized, extension);
    if (newPath == path) {
      return;
    }

    try {
      final renamed = await file.rename(newPath);
      await _scanFile(renamed.path);
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _downloadHistory.indexWhere(
          (entry) => entry['path'] == path,
        );
        if (index != -1) {
          _downloadHistory[index]['path'] = renamed.path;
          _downloadHistory[index]['title'] = renamed.path.split('/').last;
        }
        if (_favoritePaths.contains(path)) {
          _favoritePaths
            ..remove(path)
            ..add(renamed.path);
        }
        if (_playCounts.containsKey(path)) {
          final count = _playCounts.remove(path);
          if (count != null) {
            _playCounts[renamed.path] = count;
          }
        }
      });
      _thumbnailCache.remove(path);
      await _persistHistory();
      await _persistFavorites();
      await _persistPlayCounts();
      Fluttertoast.showToast(msg: 'تمت إعادة التسمية');
    } catch (e) {
      debugPrint('Rename error: $e');
      Fluttertoast.showToast(msg: 'فشل إعادة التسمية');
    }
  }

  Future<void> _convertToMp3(Map<String, dynamic> item) async {
    final path = item['path']?.toString() ?? '';
    if (path.isEmpty) {
      return;
    }
    if (item['type'] == 'audio') {
      Fluttertoast.showToast(msg: 'الملف صوت بالفعل');
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      Fluttertoast.showToast(msg: 'الملف غير موجود');
      return;
    }

    final audioDir = Directory('/storage/emulated/0/Music/WhatsappDownloader');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final baseName = _sanitizeFileName(_fileBaseName(path));
    final outputPath = _resolveUniquePath(audioDir.path, baseName, '.m4a');

    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _ytSurface,
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(color: _ytRed, strokeWidth: 2),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'جاري تحويل الملف إلى M4A...',
                style: TextStyle(color: Colors.white70, fontSize: 12.sp),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final coverPath = await _createCoverFromVideo(path);
      // إضافة -y للكتابة فوق الملف إذا كان موجوداً
      final session = await FFmpegKit.execute(
        '-y -i "$path" -vn -c:a aac -b:a 192k "$outputPath"',
      );
      final returnCode = await session.getReturnCode();
      if (mounted) {
        Navigator.pop(context);
      }

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        final sizeBytes = await outputFile.length();
        await _scanFile(outputPath);
        if (!mounted) {
          return;
        }
        setState(() {
          _downloadHistory.insert(0, {
            'title': outputFile.path.split('/').last,
            'path': outputFile.path,
            'type': 'audio',
            'date': DateTime.now().toIso8601String(),
            'size': _formatBytes(sizeBytes),
            'sizeBytes': sizeBytes,
            'durationMs': _durationMs(item),
            'thumbUrl': item['thumbUrl'],
            'coverPath': coverPath,
          });
        });
        await _persistHistory();
        Fluttertoast.showToast(msg: 'تم إنشاء ملف M4A بنجاح');
      } else {
        // طباعة السجلات لمعرفة سبب الفشل
        final logs = await session.getLogs();
        final logContent = logs.map((log) => log.getMessage()).join('\n');
        debugPrint('FFmpeg Failure Logs: $logContent');
        Fluttertoast.showToast(
          msg: 'فشل تحويل الملف. راجع السجلات (Debug Console)',
        );
      }
    } catch (e) {
      debugPrint('Convert error: $e');
      if (mounted) {
        Navigator.pop(context);
      }
      Fluttertoast.showToast(msg: 'حدث خطأ أثناء التحويل');
    }
  }

  Future<void> _shareItem(Map<String, dynamic> item) async {
    final path = item['path']?.toString() ?? '';
    if (path.isEmpty) {
      return;
    }
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> _copyPath(Map<String, dynamic> item) async {
    final path = item['path']?.toString() ?? '';
    if (path.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: path));
    Fluttertoast.showToast(msg: 'تم نسخ المسار');
  }

  Future<_MediaMeta> _loadMeta(Map<String, dynamic> item) async {
    final path = item['path']?.toString() ?? '';
    final file = File(path);
    final exists = await file.exists();
    final bytes = exists ? await file.length() : 0;
    final extension = _fileExtension(path).replaceAll('.', '').toUpperCase();
    Duration? duration;
    final storedDurationMs = _durationMs(item);
    if (storedDurationMs > 0) {
      duration = Duration(milliseconds: storedDurationMs);
    }
    if (exists) {
      try {
        if (item['type'] != 'audio') {
          final controller = VideoPlayerController.file(file);
          await controller.initialize();
          duration = controller.value.duration;
          await controller.dispose();
        }
      } catch (_) {
        duration = null;
      }
    }
    return _MediaMeta(
      path: path,
      sizeBytes: bytes,
      extension: extension.isEmpty ? 'FILE' : extension,
      duration: duration,
    );
  }

  Future<void> _showDetails(Map<String, dynamic> item) async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: _ytSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            border: Border.all(color: Colors.white12),
          ),
          child: FutureBuilder<_MediaMeta>(
            future: _loadMeta(item),
            builder: (context, snapshot) {
              final meta = snapshot.data;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (item['title'] ?? 'بدون عنوان').toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          item['type'] == 'audio' ? 'AUDIO' : 'VIDEO',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _DetailRow(
                    label: 'الصيغة',
                    value: meta?.extension ?? '—',
                  ),
                  _DetailRow(
                    label: 'الحجم',
                    value: meta == null ? '...' : _formatBytes(meta.sizeBytes),
                  ),
                  _DetailRow(
                    label: 'المدة',
                    value: meta?.duration == null
                        ? '...'
                        : _formatDuration(meta!.duration!),
                  ),
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: () => _copyPath(item),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_rounded,
                            color: Colors.white70,
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              item['path']?.toString() ?? '',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.copy_rounded,
                            color: Colors.white54,
                            size: 16.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareItem(item),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: Text(
                            'مشاركة',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _renameItem(item),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: Text(
                            'تعديل الاسم',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _toggleFavorite(item),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white24),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      icon: Icon(
                        _isFavoritePath(item['path']?.toString() ?? '')
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _isFavoritePath(item['path']?.toString() ?? '')
                            ? 'إزالة من المفضلة'
                            : 'إضافة للمفضلة',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: item['type'] == 'audio'
                              ? null
                              : () => _convertToMp3(item),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          icon: const Icon(Icons.music_note_rounded, size: 18),
                          label: Text(
                            'تحويل إلى صوت',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteItem(
                            _filteredDownloads.indexOf(item),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.redAccent),
                            foregroundColor: Colors.redAccent,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text(
                            'حذف',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _setFilter(_DownloadFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  bool get _hasActiveAdvancedFilters {
    return _favoritesOnly ||
        _minSizeMb != null ||
        _maxSizeMb != null ||
        _minDuration != null ||
        _maxDuration != null;
  }

  void _showAdvancedFilterSheet() {
    final minSizeController = TextEditingController(
      text: _minSizeMb?.toStringAsFixed(1),
    );
    final maxSizeController = TextEditingController(
      text: _maxSizeMb?.toStringAsFixed(1),
    );
    final minDurationController = TextEditingController(
      text: _minDuration?.inMinutes.toString(),
    );
    final maxDurationController = TextEditingController(
      text: _maxDuration?.inMinutes.toString(),
    );
    var favoritesOnly = _favoritesOnly;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: _ytSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              border: Border.all(color: Colors.white12),
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فلترة متقدمة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _FilterSwitch(
                      title: 'المفضلة فقط',
                      value: favoritesOnly,
                      onChanged: (value) {
                        setModalState(() {
                          favoritesOnly = value;
                        });
                      },
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'الحجم (MB)',
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterField(
                            controller: minSizeController,
                            hint: 'الحد الأدنى',
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: _FilterField(
                            controller: maxSizeController,
                            hint: 'الحد الأقصى',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'المدة (بالدقائق)',
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterField(
                            controller: minDurationController,
                            hint: 'من',
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: _FilterField(
                            controller: maxDurationController,
                            hint: 'إلى',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              minSizeController.clear();
                              maxSizeController.clear();
                              minDurationController.clear();
                              maxDurationController.clear();
                              setModalState(() {
                                favoritesOnly = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white24),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text('إعادة ضبط', style: TextStyle(fontSize: 12.sp)),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _favoritesOnly = favoritesOnly;
                                _minSizeMb =
                                    double.tryParse(minSizeController.text);
                                _maxSizeMb =
                                    double.tryParse(maxSizeController.text);
                                final minMinutes =
                                    int.tryParse(minDurationController.text);
                                final maxMinutes =
                                    int.tryParse(maxDurationController.text);
                                _minDuration = minMinutes == null
                                    ? null
                                    : Duration(minutes: minMinutes);
                                _maxDuration = maxMinutes == null
                                    ? null
                                    : Duration(minutes: maxMinutes);
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _ytRed,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text('تطبيق', style: TextStyle(fontSize: 12.sp)),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDownloads;
    return Scaffold(
      backgroundColor: _ytDark,
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
            child: _GlowBubble(size: 220, color: _ytRed.withOpacity(0.18)),
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
            child: RefreshIndicator(
              color: _ytRed,
              onRefresh: _loadDownloadHistory,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 16.h,
                      ),
                      child: _Header(
                        totalCount: _downloadHistory.length,
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: _SummaryCard(
                        total: _downloadHistory.length,
                        videos: _videoCount,
                        audios: _audioCount,
                        lastDownload: _lastDownloadLabel(),
                        totalSize: _formatBytes(_totalBytes),
                        onClearAll: _downloadHistory.isEmpty
                            ? null
                            : _clearAllDownloads,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: _PermissionsCard(
                        isLoading: _permissionLoading,
                        storage: _storageStatus,
                        manage: _manageStatus,
                        notification: _notificationStatus,
                        onOpenSettings: openAppSettings,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: _SearchBar(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        onClear: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        onSortChanged: (sort) {
                          setState(() {
                            _selectedSort = sort;
                          });
                        },
                        selectedSort: _selectedSort,
                        onFilterTap: _showAdvancedFilterSheet,
                        hasActiveFilters: _hasActiveAdvancedFilters,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: _FilterRow(
                        selected: _selectedFilter,
                        onChanged: _setFilter,
                        total: _downloadHistory.length,
                        videos: _videoCount,
                        audios: _audioCount,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 12.h)),
                  if (_audioCount > 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: _PlaylistModeToggle(
                          mode: _playlistMode,
                          onChanged: (mode) {
                            setState(() {
                              _playlistMode = mode;
                            });
                          },
                        ),
                      ),
                    ),
                  if (_audioCount > 0)
                    SliverToBoxAdapter(
                      child: SizedBox(height: 12.h),
                    ),
                  if (_audioCount > 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: _PlayAllButton(onTap: _openAudioPlayer),
                      ),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          childCount: filtered.length,
                          (context, index) {
                            final item = filtered[index];
                            final isAudio = item['type'] == 'audio';
                            final path = item['path']?.toString() ?? '';
                            final isFavorite = _isFavoritePath(path);
                            final playCount = _playCountFor(path);
                            return _DownloadCard(
                              item: item,
                              isAudio: isAudio,
                              leading: isAudio
                                  ? _MediaIcon(isAudio: true)
                                  : FutureBuilder<String?>(
                                      future: _loadThumbnail(path),
                                      builder: (context, snapshot) {
                                        final thumbPath = snapshot.data;
                                        if (thumbPath != null &&
                                            File(thumbPath).existsSync()) {
                                          return _VideoThumb(path: thumbPath);
                                        }
                                        return _MediaIcon(isAudio: false);
                                      },
                                    ),
                              onTap: () {
                                if (isAudio) {
                                  _openAudioPlayer(path: item['path']);
                                } else {
                                  _registerPlay(path);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          LocalVideoPlayerScreen(
                                        filePath: item['path'],
                                        title: item['title'],
                                        coverUrl: item['thumbUrl'],
                                      ),
                                    ),
                                  );
                                }
                              },
                              onActionSelected: (action) {
                                switch (action) {
                                  case _DownloadAction.details:
                                    _showDetails(item);
                                    break;
                                  case _DownloadAction.rename:
                                    _renameItem(item);
                                    break;
                                  case _DownloadAction.convertMp3:
                                    _convertToMp3(item);
                                    break;
                                  case _DownloadAction.delete:
                                    _deleteItem(index);
                                    break;
                                }
                              },
                              onDelete: () => _deleteItem(index),
                              dateLabel: _formatDateLabel(
                                item['date']?.toString(),
                              ),
                              isFavorite: isFavorite,
                              onToggleFavorite: () => _toggleFavorite(item),
                              playCount: playCount,
                              onShare: () => _shareItem(item),
                            );
                          },
                        ),
                      ),
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

class _Header extends StatelessWidget {
  final int totalCount;
  final VoidCallback onBack;

  const _Header({required this.totalCount, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconCircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سجل التنزيلات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'كل ملفاتك المحفوظة في مكان واحد',
                style: TextStyle(color: Colors.white70, fontSize: 12.sp),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            '$totalCount عنصر',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final int videos;
  final int audios;
  final String lastDownload;
  final String totalSize;
  final VoidCallback? onClearAll;

  const _SummaryCard({
    required this.total,
    required this.videos,
    required this.audios,
    required this.lastDownload,
    required this.totalSize,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SummaryStat(label: 'الإجمالي', value: '$total', color: _ytRed),
              SizedBox(width: 12.w),
              _SummaryStat(
                label: 'فيديو',
                value: '$videos',
                color: Colors.blueAccent,
              ),
              SizedBox(width: 12.w),
              _SummaryStat(
                label: 'صوت',
                value: '$audios',
                color: Colors.greenAccent,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: Colors.white70,
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'آخر تنزيل: $lastDownload',
                          style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.storage_rounded, color: Colors.white70, size: 18.sp),
                    SizedBox(width: 6.w),
                    Text(
                      totalSize,
                      style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onClearAll,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white24),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text(
                'تنظيف كل التنزيلات',
                style: TextStyle(fontSize: 12.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  final bool isLoading;
  final PermissionStatus storage;
  final PermissionStatus manage;
  final PermissionStatus notification;
  final VoidCallback onOpenSettings;

  const _PermissionsCard({
    required this.isLoading,
    required this.storage,
    required this.manage,
    required this.notification,
    required this.onOpenSettings,
  });

  String _statusLabel(PermissionStatus status) {
    if (status.isGranted) {
      return 'مفعل';
    }
    if (status.isPermanentlyDenied) {
      return 'مرفوض نهائيًا';
    }
    return 'غير مفعل';
  }

  Color _statusColor(PermissionStatus status) {
    if (status.isGranted) {
      return Colors.greenAccent;
    }
    if (status.isPermanentlyDenied) {
      return Colors.redAccent;
    }
    return Colors.orangeAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الأذونات والإرشادات',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'تأكد من تفعيل صلاحيات التخزين والتنبيهات حتى تعمل التنزيلات بسلاسة.',
            style: TextStyle(color: Colors.white70, fontSize: 11.sp),
          ),
          SizedBox(height: 12.h),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: _ytRed, strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _PermissionPill(
                  label: 'التخزين',
                  status: _statusLabel(storage),
                  color: _statusColor(storage),
                ),
                _PermissionPill(
                  label: 'إدارة التخزين',
                  status: _statusLabel(manage),
                  color: _statusColor(manage),
                ),
                _PermissionPill(
                  label: 'الإشعارات',
                  status: _statusLabel(notification),
                  color: _statusColor(notification),
                ),
              ],
            ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenSettings,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white24),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: Text(
                'فتح إعدادات الصلاحيات',
                style: TextStyle(fontSize: 12.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionPill extends StatelessWidget {
  final String label;
  final String status;
  final Color color;

  const _PermissionPill({
    required this.label,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8.sp),
          SizedBox(width: 6.w),
          Text(
            '$label: $status',
            style: TextStyle(color: Colors.white70, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<_DownloadSort> onSortChanged;
  final _DownloadSort selectedSort;
  final VoidCallback onFilterTap;
  final bool hasActiveFilters;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onSortChanged,
    required this.selectedSort,
    required this.onFilterTap,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ابحث في التنزيلات',
              hintStyle: TextStyle(color: Colors.white54, fontSize: 12.sp),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: onClear,
                    ),
              filled: true,
              fillColor: _ytSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: _ytRed),
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        _FilterButton(
          onTap: onFilterTap,
          isActive: hasActiveFilters,
        ),
        SizedBox(width: 10.w),
        _SortMenuButton(
          selectedSort: selectedSort,
          onSelected: onSortChanged,
        ),
      ],
    );
  }
}

class _SortMenuButton extends StatelessWidget {
  final _DownloadSort selectedSort;
  final ValueChanged<_DownloadSort> onSelected;

  const _SortMenuButton({
    required this.selectedSort,
    required this.onSelected,
  });

  String _labelForSort(_DownloadSort sort) {
    switch (sort) {
      case _DownloadSort.oldest:
        return 'الأقدم';
      case _DownloadSort.sizeDesc:
        return 'الأكبر';
      case _DownloadSort.sizeAsc:
        return 'الأصغر';
      case _DownloadSort.nameAsc:
        return 'A-Z';
      case _DownloadSort.nameDesc:
        return 'Z-A';
      case _DownloadSort.newest:
      default:
        return 'الأحدث';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DownloadSort>(
      onSelected: onSelected,
      color: _ytSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: const BorderSide(color: Colors.white12),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _DownloadSort.newest,
          child: _MenuRow(icon: Icons.schedule, text: 'الأحدث'),
        ),
        PopupMenuItem(
          value: _DownloadSort.oldest,
          child: _MenuRow(icon: Icons.history_toggle_off, text: 'الأقدم'),
        ),
        PopupMenuItem(
          value: _DownloadSort.sizeDesc,
          child: _MenuRow(icon: Icons.arrow_downward, text: 'الأكبر'),
        ),
        PopupMenuItem(
          value: _DownloadSort.sizeAsc,
          child: _MenuRow(icon: Icons.arrow_upward, text: 'الأصغر'),
        ),
        PopupMenuItem(
          value: _DownloadSort.nameAsc,
          child: _MenuRow(icon: Icons.sort_by_alpha, text: 'A-Z'),
        ),
        PopupMenuItem(
          value: _DownloadSort.nameDesc,
          child: _MenuRow(icon: Icons.sort_by_alpha, text: 'Z-A'),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: _ytSurface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Icon(Icons.tune_rounded, color: Colors.white, size: 18.sp),
            SizedBox(height: 4.h),
            Text(
              _labelForSort(selectedSort),
              style: TextStyle(color: Colors.white70, fontSize: 9.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;

  const _FilterButton({required this.onTap, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isActive ? _ytRed.withOpacity(0.2) : _ytSurface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isActive ? _ytRed : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_rounded,
              color: Colors.white,
              size: 18.sp,
            ),
            SizedBox(height: 4.h),
            Text(
              'فلتر',
              style: TextStyle(color: Colors.white70, fontSize: 9.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final _DownloadFilter selected;
  final ValueChanged<_DownloadFilter> onChanged;
  final int total;
  final int videos;
  final int audios;

  const _FilterRow({
    required this.selected,
    required this.onChanged,
    required this.total,
    required this.videos,
    required this.audios,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'الكل',
          count: total,
          isSelected: selected == _DownloadFilter.all,
          onTap: () => onChanged(_DownloadFilter.all),
        ),
        SizedBox(width: 10.w),
        _FilterChip(
          label: 'فيديو',
          count: videos,
          isSelected: selected == _DownloadFilter.video,
          onTap: () => onChanged(_DownloadFilter.video),
        ),
        SizedBox(width: 10.w),
        _FilterChip(
          label: 'صوت',
          count: audios,
          isSelected: selected == _DownloadFilter.audio,
          onTap: () => onChanged(_DownloadFilter.audio),
        ),
      ],
    );
  }
}

class _PlaylistModeToggle extends StatelessWidget {
  final _AudioPlaylistMode mode;
  final ValueChanged<_AudioPlaylistMode> onChanged;

  const _PlaylistModeToggle({
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PlaylistButton(
            label: 'الأحدث',
            isActive: mode == _AudioPlaylistMode.latest,
            onTap: () => onChanged(_AudioPlaylistMode.latest),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _PlaylistButton(
            label: 'الأكثر تشغيلًا',
            isActive: mode == _AudioPlaylistMode.mostPlayed,
            onTap: () => onChanged(_AudioPlaylistMode.mostPlayed),
          ),
        ),
      ],
    );
  }
}

class _PlaylistButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PlaylistButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isActive ? _ytRed.withOpacity(0.2) : _ytSurface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: isActive ? _ytRed : Colors.white12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayAllButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _ytSurface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.queue_music_rounded, color: Colors.white),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تشغيل كل المقاطع الصوتية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'قائمة تشغيل تلقائية من مكتبة الصوت',
                  style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('تشغيل'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? _ytRed.withOpacity(0.2) : _ytSurface,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: isSelected ? _ytRed : Colors.white12),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '$count',
                style: TextStyle(color: Colors.white70, fontSize: 10.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isAudio;
  final Widget leading;
  final VoidCallback onTap;
  final ValueChanged<_DownloadAction> onActionSelected;
  final VoidCallback onDelete;
  final String dateLabel;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final int playCount;
  final VoidCallback onShare;

  const _DownloadCard({
    required this.item,
    required this.isAudio,
    required this.leading,
    required this.onTap,
    required this.onActionSelected,
    required this.onDelete,
    required this.dateLabel,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.playCount,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isAudio ? Colors.greenAccent : _ytRed;
    final title = (item['title'] ?? 'بدون عنوان').toString();
    final size = (item['size'] ?? '—').toString();
    final playsLabel = playCount > 0 ? 'تشغيل $playCount' : null;

    return Dismissible(
      key: ValueKey('${item['path'] ?? title}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white),
            SizedBox(width: 6.w),
            Text(
              'حذف',
              style: TextStyle(color: Colors.white, fontSize: 12.sp),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: _ytSurface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                leading,
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 6.h,
                        children: [
                          _MetaChip(
                            label: isAudio ? 'صوت' : 'فيديو',
                            color: accent,
                          ),
                          _MetaChip(label: size, color: Colors.white70),
                          if (playsLabel != null)
                            _MetaChip(label: playsLabel, color: Colors.white60),
                          _MetaChip(label: dateLabel, color: Colors.white54),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onShare,
                      icon: const Icon(Icons.share_rounded),
                      color: Colors.white70,
                      iconSize: 20.sp,
                    ),
                    IconButton(
                      onPressed: onToggleFavorite,
                      icon: Icon(
                        isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                      color: isFavorite ? Colors.amber : Colors.white70,
                      iconSize: 22.sp,
                    ),
                    _ActionMenuButton(onSelected: onActionSelected),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _FilterField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white54, fontSize: 12.sp),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: _ytRed),
        ),
      ),
    );
  }
}

class _FilterSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _ytRed,
          ),
        ],
      ),
    );
  }
}

class _ActionMenuButton extends StatelessWidget {
  final ValueChanged<_DownloadAction> onSelected;

  const _ActionMenuButton({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DownloadAction>(
      onSelected: onSelected,
      color: _ytSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: const BorderSide(color: Colors.white12),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _DownloadAction.details,
          child: _MenuRow(icon: Icons.info_outline_rounded, text: 'تفاصيل'),
        ),
        PopupMenuItem(
          value: _DownloadAction.rename,
          child: _MenuRow(icon: Icons.edit_rounded, text: 'إعادة تسمية'),
        ),
        PopupMenuItem(
          value: _DownloadAction.convertMp3,
          child: _MenuRow(
            icon: Icons.music_note_rounded,
            text: 'تحويل إلى صوت',
          ),
        ),
        PopupMenuItem(
          value: _DownloadAction.delete,
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            text: 'حذف',
            isDanger: true,
          ),
        ),
      ],
      child: Container(
        width: 34.w,
        height: 34.w,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(
          Icons.more_vert_rounded,
          color: Colors.white70,
          size: 18.sp,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDanger;

  const _MenuRow({
    required this.icon,
    required this.text,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.redAccent : Colors.white;
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: color),
        SizedBox(width: 8.w),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 12.sp),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white54, fontSize: 11.sp),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}

class _MediaIcon extends StatelessWidget {
  final bool isAudio;

  const _MediaIcon({required this.isAudio});

  @override
  Widget build(BuildContext context) {
    final accent = isAudio ? Colors.greenAccent : _ytRed;
    return Container(
      width: 46.w,
      height: 46.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withOpacity(0.15),
      ),
      child: Icon(
        isAudio ? Icons.music_note : Icons.videocam_rounded,
        color: accent,
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final String path;

  const _VideoThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 54.w,
        height: 54.w,
        color: Colors.white10,
        child: Image.file(File(path), fit: BoxFit.cover),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: _ytSurface,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.download_done_rounded,
                  size: 30.sp,
                  color: Colors.white54,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'لا توجد تنزيلات حتى الآن',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              Text(
                'ابدأ بتنزيل فيديو أو صوت ليظهر هنا السجل بالكامل',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.sp,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: _ytSurface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 18.sp),
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

class _MediaMeta {
  final String path;
  final int sizeBytes;
  final String extension;
  final Duration? duration;

  const _MediaMeta({
    required this.path,
    required this.sizeBytes,
    required this.extension,
    required this.duration,
  });
}
