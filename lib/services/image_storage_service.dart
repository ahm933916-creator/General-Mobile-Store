import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps product assets in the user-selected reports/screenshots folder instead
/// of storing a reference to a temporary file picked from another location.
class ImageStorageService {
  static Future<String?> copyToConfiguredDirectory({
    required String? sourcePath,
    required String prefix,
  }) async {
    if (sourcePath == null || sourcePath.trim().isEmpty) return null;

    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final prefs = await SharedPreferences.getInstance();
    final configuredPath = prefs.getString('save_directory');
    if (configuredPath == null || configuredPath.trim().isEmpty) {
      throw const FileSystemException('لم يتم تحديد مجلد حفظ الصور من الإعدادات');
    }

    final targetDirectory = Directory(configuredPath);
    await targetDirectory.create(recursive: true);

    final normalizedSource = p.normalize(source.path);
    final normalizedDirectory = p.normalize(targetDirectory.path);
    if (p.dirname(normalizedSource) == normalizedDirectory) {
      return source.path;
    }

    final extension = p.extension(source.path).toLowerCase().isEmpty
        ? '.jpg'
        : p.extension(source.path).toLowerCase();
    final safePrefix = prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final targetPath = p.join(
      targetDirectory.path,
      '${safePrefix}_${DateTime.now().millisecondsSinceEpoch}$extension',
    );

    // Avoid copying a file onto itself when editing an existing product.
    if (normalizedSource == p.normalize(targetPath)) {
      return source.path;
    }

    final copied = await source.copy(targetPath);
    return copied.path;
  }
}
