import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حفظ صور المنتجات في مسار دائم قابل للكتابة على Android وLinux.
/// لا يغيّر هذا المسار مجلد التقارير ولقطات الشاشة؛ بل ينشئ داخله ProductImages.
class ImageStorageService {
  static Future<Directory> _rootDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final configuredPath = prefs.getString('save_directory')?.trim();

    if (configuredPath != null && configuredPath.isNotEmpty) {
      final configured = Directory(configuredPath);
      try {
        await configured.create(recursive: true);
        final probe = File(p.join(configured.path, '.general_mobile_store_write_test'));
        await probe.writeAsString('ok', flush: true);
        await probe.delete();
        return configured;
      } catch (_) {
        // بعض مسارات Android المختارة قد تكون غير قابلة للكتابة.
        // نستخدم مجلد التطبيق الدائم بدل فقدان الصورة.
      }
    }

    return getApplicationDocumentsDirectory();
  }

  static String safeName(String value, {String fallback = 'منتج'}) {
    final cleaned = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  static Future<Directory> productDirectory(String productName) async {
    final root = await _rootDirectory();
    final directory = Directory(p.join(root.path, 'ProductImages', safeName(productName)));
    await directory.create(recursive: true);
    return directory;
  }

  static Future<String?> copyProductAsset({
    required String? sourcePath,
    required String productName,
    required String suffix,
  }) async {
    if (sourcePath == null || sourcePath.trim().isEmpty) return null;

    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final directory = await productDirectory(productName);
    final name = safeName(productName);
    final sourceExtension = p.extension(source.path).toLowerCase();
    final extension = sourceExtension.isEmpty ? (suffix == '_barcode' ? '.png' : '.jpg') : sourceExtension;
    final target = File(p.join(directory.path, '$name$suffix$extension'));

    if (p.normalize(source.path) != p.normalize(target.path)) {
      if (await target.exists()) await target.delete();
      await source.copy(target.path);
    }
    return target.path;
  }

  /// يعيد تسمية مجلد المنتج عند تغيير اسمه مع إبقاء الصور داخله.
  static Future<void> renameProductDirectory({
    required String oldName,
    required String newName,
  }) async {
    if (oldName.trim() == newName.trim()) return;
    final root = await _rootDirectory();
    final oldDirectory = Directory(p.join(root.path, 'ProductImages', safeName(oldName)));
    if (!await oldDirectory.exists()) return;

    final newDirectory = Directory(p.join(root.path, 'ProductImages', safeName(newName)));
    await newDirectory.parent.create(recursive: true);
    if (await newDirectory.exists()) {
      await for (final entity in oldDirectory.list()) {
        final target = p.join(newDirectory.path, p.basename(entity.path));
        if (entity is File) await entity.copy(target);
      }
      await oldDirectory.delete(recursive: true);
    } else {
      await oldDirectory.rename(newDirectory.path);
    }
  }

  /// توافق مع الاستدعاءات القديمة؛ يحفظ الملف داخل مجلد ProductImages.
  static Future<String?> copyToConfiguredDirectory({
    required String? sourcePath,
    required String prefix,
  }) async {
    return copyProductAsset(
      sourcePath: sourcePath,
      productName: prefix,
      suffix: '',
    );
  }
}
