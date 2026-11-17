import 'dart:io';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';

class BarcodeImageService {
  static Future<String> generateQrImage({required String code, required String prefix}) async {
    // نولّد أولاً في مجلد مؤقت قابل للكتابة، ثم تنقله شاشة المنتجات
    // إلى ProductImages/<اسم المنتج> عند الضغط على حفظ.
    final directory = await getTemporaryDirectory();
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
