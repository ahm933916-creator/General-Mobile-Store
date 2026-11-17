import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// التخزين الخارجي الوحيد للصور والتقارير.
/// لا يوجد مسار بديل داخل بيانات التطبيق حتى لا تختفي الملفات عن المستخدم.
class ImageStorageService {
  static const _settingKey = 'save_directory';

  static Future<void> ensureExternalStorageAccess() async {
    if (!Platform.isAndroid) return;
    final current = await Permission.manageExternalStorage.status;
    if (current.isGranted) return;
    final result = await Permission.manageExternalStorage.request();
    if (!result.isGranted) {
      throw const FileSystemException(
        'يجب السماح للتطبيق بإدارة الملفات حتى يتم حفظ الصور خارج مجلد التطبيق. افتح إعدادات Android وفعّل السماح بالوصول إلى الملفات.',
      );
    }
  }

  static Future<Directory> configuredDirectory() async {
    await ensureExternalStorageAccess();
    final prefs = await SharedPreferences.getInstance();
    final configuredPath = prefs.getString(_settingKey)?.trim();
    if (configuredPath == null || configuredPath.isEmpty) {
      throw const FileSystemException(
        'لم يتم اختيار مجلد خارجي. افتح الإعدادات واختر مجلد حفظ يمكن الكتابة فيه.',
      );
    }

    final directory = Directory(configuredPath);
    try {
      await directory.create(recursive: true);
      final probe = File(p.join(directory.path, '.general_mobile_store_write_test'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return directory;
    } catch (error) {
      throw FileSystemException(
        'لا يمكن الكتابة في المجلد الخارجي المختار. اختر مجلدًا آخر وامنح Android صلاحية الوصول إليه.',
        directory.path,
      );
    }
  }

  static String safeName(String value, {String fallback = 'منتج'}) {
    final cleaned = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  static Future<Directory> productDirectory(String productName) async {
    final root = await configuredDirectory();
    final directory = Directory(p.join(root.path, 'ProductImages', safeName(productName)));
    try {
      await directory.create(recursive: true);
      return directory;
    } catch (error) {
      throw FileSystemException('تعذر إنشاء مجلد صور المنتج داخل المجلد الخارجي المختار.', directory.path);
    }
  }

  static Future<String?> copyProductAsset({
    required String? sourcePath,
    required String productName,
    required String suffix,
  }) async {
    if (sourcePath == null || sourcePath.trim().isEmpty) return null;
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('لم يتم العثور على الصورة المؤقتة قبل نسخها.', source.path);
    }

    final directory = await productDirectory(productName);
    final name = safeName(productName);
    final sourceExtension = p.extension(source.path).toLowerCase();
    final extension = sourceExtension.isEmpty ? (suffix == '_barcode' ? '.png' : '.jpg') : sourceExtension;
    final target = File(p.join(directory.path, '$name$suffix$extension'));

    try {
      if (p.normalize(source.path) != p.normalize(target.path)) {
        if (await target.exists()) await target.delete();
        await source.copy(target.path);
      }
      return target.path;
    } catch (error) {
      throw FileSystemException('تعذر حفظ صورة المنتج داخل المجلد الخارجي المختار.', target.path);
    }
  }

  static Future<String> saveBytes({
    required List<int> bytes,
    required String fileName,
  }) async {
    final root = await configuredDirectory();
    final target = File(p.join(root.path, safeName(fileName, fallback: 'report.png')));
    try {
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (error) {
      throw FileSystemException('تعذر حفظ التقرير داخل المجلد الخارجي المختار.', target.path);
    }
  }

  static Future<void> renameProductDirectory({required String oldName, required String newName}) async {
    if (oldName.trim() == newName.trim()) return;
    final root = await configuredDirectory();
    final oldDirectory = Directory(p.join(root.path, 'ProductImages', safeName(oldName)));
    if (!await oldDirectory.exists()) return;
    final newDirectory = Directory(p.join(root.path, 'ProductImages', safeName(newName)));
    try {
      await newDirectory.parent.create(recursive: true);
      if (await newDirectory.exists()) {
        await for (final entity in oldDirectory.list()) {
          if (entity is File) await entity.copy(p.join(newDirectory.path, p.basename(entity.path)));
        }
        await oldDirectory.delete(recursive: true);
      } else {
        await oldDirectory.rename(newDirectory.path);
      }
    } catch (error) {
      throw FileSystemException('تعذر إعادة تسمية مجلد صور المنتج الخارجي.', newDirectory.path);
    }
  }

  static Future<String?> copyToConfiguredDirectory({required String? sourcePath, required String prefix}) {
    return copyProductAsset(sourcePath: sourcePath, productName: prefix, suffix: '');
  }
}
