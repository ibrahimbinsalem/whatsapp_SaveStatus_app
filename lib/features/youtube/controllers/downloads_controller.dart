import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';

import '../views/local_video_player_screen.dart';

const Color _ytRed = Color(0xFFE53935);
const Color _ytSurface = Color(0xFF1C1C1C);

enum DownloadFilter { all, video, audio }

enum DownloadAction { details, rename, convertMp3, delete }

enum DownloadSort { newest, oldest, sizeDesc, sizeAsc, nameAsc, nameDesc }

enum AudioPlaylistMode { latest, mostPlayed }

class DownloadsController extends GetxController {
  BuildContext? context;

  bool get mounted => !isClosed;

  void setContext(BuildContext value) {
    context = value;
  }

  void setState(VoidCallback fn) {
    if (isClosed) {
      return;
    }
    fn();
    update();
  }

  static const MethodChannel _mediaScanner =
      MethodChannel('whatsapp_dawnloader/media_scan');
  List<Map<String, dynamic>> _downloadHistory = [];
  DownloadFilter _selectedFilter = DownloadFilter.all;
  DownloadSort _selectedSort = DownloadSort.newest;
  AudioPlaylistMode _playlistMode = AudioPlaylistMode.latest;
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

  List<Map<String, dynamic>> get downloadHistory => _downloadHistory;

  DownloadFilter get selectedFilter => _selectedFilter;

  DownloadSort get selectedSort => _selectedSort;

  AudioPlaylistMode get playlistMode => _playlistMode;

  TextEditingController get searchController => _searchController;

  String get searchQuery => _searchQuery;

  int get totalBytes => _totalBytes;

  bool get favoritesOnly => _favoritesOnly;

  PermissionStatus get storageStatus => _storageStatus;

  PermissionStatus get manageStatus => _manageStatus;

  PermissionStatus get notificationStatus => _notificationStatus;

  bool get permissionLoading => _permissionLoading;

  List<Map<String, dynamic>> get filteredDownloads => _filteredDownloads;

  int get videoCount => _videoCount;

  int get audioCount => _audioCount;

  bool get hasActiveAdvancedFilters => _hasActiveAdvancedFilters;

  @override
  void onInit() {
    super.onInit();
    _loadDownloadHistory();
    _loadPreferences();
    _loadPermissions();
  }

  @override
  void onClose() {
    _searchController.dispose();
    super.onClose();
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
      if (_playlistMode == AudioPlaylistMode.mostPlayed) {
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
      context!,
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
    if (_selectedFilter != DownloadFilter.all) {
      final isAudio = _selectedFilter == DownloadFilter.audio;
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
      case DownloadSort.oldest:
        return _parseDate(a).compareTo(_parseDate(b));
      case DownloadSort.sizeDesc:
        return _sizeBytes(b).compareTo(_sizeBytes(a));
      case DownloadSort.sizeAsc:
        return _sizeBytes(a).compareTo(_sizeBytes(b));
      case DownloadSort.nameAsc:
        return _titleOf(a).compareTo(_titleOf(b));
      case DownloadSort.nameDesc:
        return _titleOf(b).compareTo(_titleOf(a));
      case DownloadSort.newest:
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
    final ctx = context;
    if (ctx == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: ctx,
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
    final ctx = context;
    if (ctx == null) {
      return;
    }
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
      context: ctx,
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
    final ctx = context;
    if (ctx == null) {
      return;
    }
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
      context: ctx,
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
        Navigator.pop(ctx);
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
        Navigator.pop(ctx);
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
    final ctx = context;
    if (ctx == null) {
      return;
    }
    showModalBottomSheet<void>(
      context: ctx,
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

  void _setFilter(DownloadFilter filter) {
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
    final ctx = context;
    if (ctx == null) {
      return;
    }
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
      context: ctx,
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

  

  Future<void> loadDownloadHistory() async => _loadDownloadHistory();

  void updateSearch(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  void setSort(DownloadSort sort) {
    setState(() {
      _selectedSort = sort;
    });
  }

  void setFilter(DownloadFilter filter) => _setFilter(filter);

  void setPlaylistMode(AudioPlaylistMode mode) {
    setState(() {
      _playlistMode = mode;
    });
  }

  String lastDownloadLabel() => _lastDownloadLabel();

  String formatBytes(int bytes) => _formatBytes(bytes);

  String formatDateLabel(String? rawDate) => _formatDateLabel(rawDate);

  bool isFavoritePath(String path) => _isFavoritePath(path);

  int playCountFor(String path) => _playCountFor(path);

  Future<String?> loadThumbnail(String path) => _loadThumbnail(path);

  void openAudioPlayer({String? path}) => _openAudioPlayer(path: path);

  Future<void> registerPlay(String path) => _registerPlay(path);

  Future<void> showDetails(Map<String, dynamic> item) => _showDetails(item);

  Future<void> renameItem(Map<String, dynamic> item) => _renameItem(item);

  Future<void> convertToMp3(Map<String, dynamic> item) => _convertToMp3(item);

  Future<void> deleteItem(int index) => _deleteItem(index);

  Future<void> clearAllDownloads() => _clearAllDownloads();

  Future<void> toggleFavorite(Map<String, dynamic> item) =>
      _toggleFavorite(item);

  Future<void> shareItem(Map<String, dynamic> item) => _shareItem(item);

  void showAdvancedFilterSheet() => _showAdvancedFilterSheet();
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
