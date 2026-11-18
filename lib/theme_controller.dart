import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حالة الثيم المشتركة بين التطبيق وصفحة الإعدادات.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.dark);

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? true;
  appThemeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
}

Future<void> saveThemeMode(ThemeMode mode) async {
  appThemeMode.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('dark_mode', mode == ThemeMode.dark);
}
