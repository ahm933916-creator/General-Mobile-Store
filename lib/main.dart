import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/home_screen.dart';

void main() {
  // تهيئة قاعدة البيانات خصيصاً لسطح المكتب (Linux, Windows, macOS)
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
    final isPhone = logicalWidth < 600;
    final baseTextTheme = ThemeData.light().textTheme;
    return MaterialApp(
      title: 'إدارة المبيعات والمنتجات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: baseTextTheme.copyWith(
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: isPhone ? 15 : 17),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: isPhone ? 14 : 16),
          bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: isPhone ? 12 : 14),
          labelLarge: baseTextTheme.labelLarge?.copyWith(fontSize: isPhone ? 13 : 15),
          titleMedium: baseTextTheme.titleMedium?.copyWith(fontSize: isPhone ? 15 : 17),
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isPhone ? 11 : 15),
          labelStyle: TextStyle(fontSize: isPhone ? 13 : 15),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: TextStyle(fontSize: isPhone ? 13 : 15),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
