import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class InstagramController extends GetxController {
  late TextEditingController urlController;
  bool isLoading = false;
  final GetConnect _connect = GetConnect();

  @override
  void onInit() {
    super.onInit();
    urlController = TextEditingController();
    _connect.timeout = const Duration(seconds: 30); // زيادة مهلة الانتظار
  }

  @override
  void onClose() {
    urlController.dispose();
    super.onClose();
  }

  void updateUrl(String val) {
    update();
  }

  Future<void> pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      urlController.text = data.text!;
      update();
    }
  }

  Future<void> fetchContent() async {
    if (urlController.text.isEmpty) return;

    isLoading = true;
    update();

    try {
      // ⚠️ تنبيه: يجب وضع مفتاح API الخاص بك هنا
      const apiKey = 'af73a966femsha3737e712beb291p1ee2e2jsn54f6a115b00d';
      const apiHost = 'instagram-reels-downloader-api.p.rapidapi.com';

      final response = await _connect.get(
        'https://$apiHost/download',
        query: {'url': urlController.text},
        headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': apiHost},
      );

      if (response.statusCode == 200) {
        final body = response.body;

        // --- معالجة الهيكلية الجديدة (result) ---
        if (body['result'] != null && body['result'] is List) {
          final results = body['result'] as List;
          if (results.isNotEmpty) {
            final item = results[0];
            String? downloadUrl;
            String fileExtension = 'jpg';

            // 1. محاولة العثور على فيديو
            if (item['video_versions'] != null) {
              final videos = item['video_versions'] as List;
              if (videos.isNotEmpty) {
                downloadUrl = videos[0]['url'];
                fileExtension = 'mp4';
              }
            }

            // 2. محاولة العثور على صورة (إذا لم يكن فيديو)
            if (downloadUrl == null && item['image_versions2'] != null) {
              final candidates = item['image_versions2']['candidates'] as List?;
              if (candidates != null && candidates.isNotEmpty) {
                downloadUrl = candidates[0]['url'];
                fileExtension = 'jpg';
              }
            }

            if (downloadUrl != null) {
              String title = 'Instagram_Media';
              if (item['user'] != null && item['user']['username'] != null) {
                title = item['user']['username'];
              }
              await _downloadFile(downloadUrl, title, fileExtension);
              return; // إنهاء الدالة بنجاح
            }
          }
        }

        // --- معالجة الهيكلية القديمة (data) كاحتياطي ---
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'];
          final medias = data['medias'] as List?;

          String? downloadUrl;
          String fileExtension = 'mp4';

          if (medias != null && medias.isNotEmpty) {
            // 1. محاولة العثور على فيديو أولاً (للريلز والستوريات الفيديو)
            var media = medias.firstWhere(
              (m) => m['extension'] == 'mp4' || m['type'] == 'video',
              orElse: () => null,
            );

            // 2. إذا لم يوجد فيديو، نبحث عن صورة (للستوريات الصور والمنشورات العادية)
            if (media == null) {
              media = medias.firstWhere(
                (m) =>
                    m['type'] == 'image' ||
                    m['extension'] == 'jpg' ||
                    m['extension'] == 'png',
                orElse: () => null,
              );
            }

            if (media != null) {
              downloadUrl = media['url'];
              fileExtension =
                  media['extension'] ??
                  (media['type'] == 'image' ? 'jpg' : 'mp4');
            }
          }

          if (downloadUrl != null) {
            await _downloadFile(
              downloadUrl,
              data['title'] ?? 'Instagram_Media',
              fileExtension,
            );
          } else {
            Get.snackbar(
              'تنبيه',
              'لم يتم العثور على رابط فيديو صالح',
              colorText: Colors.white,
            );
          }
        } else {
          Get.snackbar(
            'خطأ',
            'فشل في جلب البيانات من انستقرام',
            colorText: Colors.white,
          );
        }
      } else if (response.statusCode == 403) {
        print('RapidAPI Error (Fetch): ${response.body}');
        Get.snackbar(
          'خطأ في الاشتراك (403)',
          'تأكد من الاشتراك في خدمة API المستخدمة في RapidAPI.',
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'خطأ',
          'خطأ في الاتصال: ${response.statusCode}',
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ غير متوقع: $e', colorText: Colors.white);
    } finally {
      isLoading = false;
      update();
    }
  }

  void clearInput() {
    urlController.clear();
    update();
  }

  Future<void> _downloadFile(String url, String title, String extension) async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    if (status.isGranted || await Permission.manageExternalStorage.isGranted) {
      try {
        final dir = Directory(
          '/storage/emulated/0/Download/WhatsappDownloader',
        );
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final cleanTitle = title
            .replaceAll(RegExp(r'[^\w\s]+'), '')
            .trim()
            .replaceAll(' ', '_');
        final fileName =
            'IG_${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final savePath = '${dir.path}/$fileName';

        Get.snackbar(
          'جاري التحميل',
          'بدأ تحميل الملف...',
          showProgressIndicator: true,
          colorText: Colors.white,
        );

        final request = await HttpClient().getUrl(Uri.parse(url));
        // إضافة User-Agent لتجنب خطأ 403 عند تحميل الملف من خوادم إنستقرام
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        );

        final response = await request.close();

        if (response.statusCode == 200) {
          final file = File(savePath);
          await response.pipe(file.openWrite());
          Get.snackbar(
            'تم',
            'تم حفظ الملف في التنزيلات',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } else {
          Get.snackbar('خطأ', 'فشل تحميل الملف', colorText: Colors.white);
        }
      } catch (e) {
        Get.snackbar('خطأ', 'فشل حفظ الملف: $e', colorText: Colors.white);
      }
    } else {
      Get.snackbar(
        'تنبيه',
        'يرجى منح صلاحية التخزين لتحميل الفيديو',
        colorText: Colors.white,
      );
    }
  }
}
