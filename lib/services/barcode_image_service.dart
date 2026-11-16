import 'dart:io';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BarcodeImageService {
  static Future<String> generateQrImage({required String code, required String prefix}) async {
    final prefs = await SharedPreferences.getInstance();
    final configuredPath = prefs.getString('save_directory');
    if (configuredPath == null || configuredPath.trim().isEmpty) {
      throw const FileSystemException('لم يتم تحديد مجلد حفظ الصور من الإعدادات');
    }

    final directory = Directory(configuredPath);
    await directory.create(recursive: true);
    final safePrefix = prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final path = p.join(directory.path, '${safePrefix}_${DateTime.now().millisecondsSinceEpoch}.png');
    final painter = QrPainter(data: code, version: QrVersions.auto, gapless: false);
    final bytes = await painter.toImageData(360, format: ui.ImageByteFormat.png);
    if (bytes == null) throw const FileSystemException('تعذر توليد صورة الباركود');
    await File(path).writeAsBytes(bytes.buffer.asUint8List());
    return path;
  }
}
