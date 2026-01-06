import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'status_media.dart';

class StatusMediaRepository {
  static const String _folderName = 'statuses';
  static const String _albumName = 'Status Saver';
  static const MethodChannel _mediaScanner = MethodChannel(
    'whatsapp_dawnloader/media_scan',
  );
  static final Map<String, Future<File?>> _thumbnailCache = {};
  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
  };
  static const Set<String> _videoExtensions = {
    '.mp4',
    '.mov',
    '.m4v',
    '.3gp',
    '.webm',
    '.mkv',
    '.avi',
  };
  static const List<String> _defaultRoots = [
    '/storage/emulated/0',
    '/storage/self/primary',
    '/sdcard',
  ];

  Future<Directory> _ensureBaseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final statusesDir = Directory('${dir.path}/$_folderName');
    if (!await statusesDir.exists()) {
      await statusesDir.create(recursive: true);
    }
    return statusesDir;
  }

  Future<List<StatusMedia>> listAll() async {
    final dir = await _ensureBaseDir();
    final items = await _scanDirectory(dir);

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<List<StatusMedia>> listWhatsAppStatuses() async {
    if (!Platform.isAndroid) {
      return [];
    }

    final items = <StatusMedia>[];
    final seen = <String>{};

    for (final dir in _whatsAppStatusDirs()) {
      final found = await _scanDirectory(dir, seen: seen);
      if (found.isNotEmpty) {
        items.addAll(found);
      }
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<bool> saveToGallery(StatusMedia item) async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final file = File(item.path);
      if (!await file.exists()) {
        return false;
      }
      final targetDir = await _ensureSavedDir();
      if (targetDir == null) {
        return false;
      }
      final ext = _extensionForPath(item.path);
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final filename = 'status_$timestamp$ext';
      final target = File('${targetDir.path}/$filename');
      await file.copy(target.path);
      await _scanFile(target.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteFromGallery(StatusMedia item) async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final targetDir = await _ensureSavedDir();
      if (targetDir == null) {
        return false;
      }
      if (!item.path.startsWith('${targetDir.path}/')) {
        return false;
      }
      final file = File(item.path);
      if (!await file.exists()) {
        return false;
      }
      await file.delete();
      await _scanFile(item.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool isSavedMediaPath(String path) {
    return path.contains('/Pictures/$_albumName/') ||
        path.contains('/DCIM/$_albumName/');
  }

  Future<int> countSavedCopies() async {
    final dir = await _ensureSavedDir();
    if (dir == null) {
      return 0;
    }
    var count = 0;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final type = _typeForPath(entity.path);
        if (type == null) {
          continue;
        }
        count += 1;
      }
    } catch (_) {
      return 0;
    }
    return count;
  }

  Future<int> deleteSavedCopies() async {
    final dir = await _ensureSavedDir();
    if (dir == null) {
      return 0;
    }
    var deleted = 0;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final type = _typeForPath(entity.path);
        if (type == null) {
          continue;
        }
        try {
          await entity.delete();
          await _scanFile(entity.path);
          deleted += 1;
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      return deleted;
    }
    return deleted;
  }

  Future<StatusMedia?> loadFromPath(String path) async {
    final type = _typeForPath(path);
    if (type == null) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size == 0) {
        return null;
      }
      return StatusMedia(path: path, type: type, createdAt: stat.modified);
    } catch (_) {
      return null;
    }
  }

  Future<List<StatusMedia>> loadFromPaths(List<String> paths) async {
    final items = <StatusMedia>[];
    for (final path in paths) {
      final item = await loadFromPath(path);
      if (item != null) {
        items.add(item);
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<File?> getVideoThumbnail(String path) {
    return _thumbnailCache.putIfAbsent(path, () async {
      try {
        if (!Platform.isAndroid && !Platform.isIOS) {
          return null;
        }
        final file = File(path);
        if (!await file.exists()) {
          return null;
        }
        final cacheDir = await getTemporaryDirectory();
        final thumbsDir = Directory('${cacheDir.path}/status_thumbs');
        if (!await thumbsDir.exists()) {
          await thumbsDir.create(recursive: true);
        }
        final stat = await file.stat();
        final base = _sanitizeFileName(_basename(path));
        final filename =
            'thumb_${stat.size}_${stat.modified.millisecondsSinceEpoch}_$base.png';
        final targetPath = '${thumbsDir.path}/$filename';
        final target = File(targetPath);
        if (await target.exists()) {
          return target;
        }
        final created = await VideoThumbnail.thumbnailFile(
          video: path,
          thumbnailPath: targetPath,
          imageFormat: ImageFormat.PNG,
          maxHeight: 240,
          quality: 75,
        );
        if (created == null) {
          return null;
        }
        return File(created);
      } catch (_) {
        return null;
      }
    });
  }

  Future<List<StatusMedia>> importPaths(List<String> paths) async {
    final dir = await _ensureBaseDir();
    final imported = <StatusMedia>[];

    for (final sourcePath in paths) {
      try {
        final type = _typeForPath(sourcePath);
        if (type == null) {
          continue;
        }
        final source = File(sourcePath);
        if (!await source.exists()) {
          continue;
        }

        final ext = _extensionForPath(sourcePath);
        final timestamp = DateTime.now().microsecondsSinceEpoch;
        final filename = 'status_${timestamp}_${imported.length}$ext';
        final target = File('${dir.path}/$filename');
        await source.copy(target.path);
        final stat = await target.stat();
        imported.add(
          StatusMedia(path: target.path, type: type, createdAt: stat.modified),
        );
      } catch (_) {
        continue;
      }
    }

    return imported;
  }

  List<Directory> _whatsAppStatusDirs() {
    final roots = <String>{
      ..._defaultRoots,
      if (Platform.environment['EXTERNAL_STORAGE']?.isNotEmpty ?? false)
        Platform.environment['EXTERNAL_STORAGE']!,
    };
    final dirs = <Directory>[];
    for (final root in roots) {
      dirs.addAll([
        Directory('$root/Android/media/com.whatsapp/WhatsApp/Media/.Statuses'),
        Directory(
          '$root/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
        ),
        Directory('$root/WhatsApp/Media/.Statuses'),
        Directory('$root/WhatsApp Business/Media/.Statuses'),
      ]);
    }
    return dirs;
  }

  Future<List<StatusMedia>> _scanDirectory(
    Directory dir, {
    Set<String>? seen,
  }) async {
    final items = <StatusMedia>[];
    try {
      if (!await dir.exists()) {
        return items;
      }
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final path = entity.path;
        if (path.endsWith('.nomedia')) {
          continue;
        }
        final type = _typeForPath(path);
        if (type == null) {
          continue;
        }
        if (seen != null && !seen.add(_normalizePathForDedup(path))) {
          continue;
        }
        try {
          final stat = await entity.stat();
          if (stat.type != FileSystemEntityType.file || stat.size == 0) {
            continue;
          }
          items.add(
            StatusMedia(path: path, type: type, createdAt: stat.modified),
          );
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      return items;
    }
    return items;
  }

  StatusMediaType? _typeForPath(String path) {
    final extension = _extensionForPath(path);
    if (_imageExtensions.contains(extension)) {
      return StatusMediaType.image;
    }
    if (_videoExtensions.contains(extension)) {
      return StatusMediaType.video;
    }
    return null;
  }

  String _extensionForPath(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return path.substring(dotIndex).toLowerCase();
  }

  String _basename(String path) {
    final slashIndex = path.lastIndexOf('/');
    if (slashIndex == -1) {
      return path;
    }
    return path.substring(slashIndex + 1);
  }

  String _sanitizeFileName(String name) {
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty) {
      return 'video';
    }
    if (safe.length > 80) {
      return safe.substring(0, 80);
    }
    return safe;
  }

  String _normalizePathForDedup(String path) {
    if (path.startsWith('/storage/self/primary/')) {
      return path.replaceFirst(
        '/storage/self/primary/',
        '/storage/emulated/0/',
      );
    }
    if (path.startsWith('/sdcard/')) {
      return path.replaceFirst('/sdcard/', '/storage/emulated/0/');
    }
    return path;
  }

  Future<String?> _resolvePrimaryStorageRoot() async {
    final candidates = <String>[];
    final envRoot = Platform.environment['EXTERNAL_STORAGE'];
    if (envRoot != null && envRoot.isNotEmpty) {
      candidates.add(envRoot);
    }
    candidates.addAll(_defaultRoots);
    for (final root in candidates) {
      final dir = Directory(root);
      if (await dir.exists()) {
        return root;
      }
    }
    return null;
  }

  Future<Directory?> _ensureSavedDir() async {
    final root = await _resolvePrimaryStorageRoot();
    if (root == null) {
      return null;
    }
    final targetDir = Directory('$root/Pictures/$_albumName');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  Future<void> _scanFile(String path) async {
    try {
      await _mediaScanner.invokeMethod('scanFile', {'path': path});
    } catch (_) {
      // Ignore scan errors; file still exists on disk.
    }
  }
}
