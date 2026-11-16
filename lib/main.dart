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
    final baseTextTheme = ThemeData.light().textTheme;
    return MaterialApp(
      title: 'إدارة المبيعات والمنتجات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: baseTextTheme.copyWith(
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 17),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 16),
          bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: 14),
          labelLarge: baseTextTheme.labelLarge?.copyWith(fontSize: 15),
          titleMedium: baseTextTheme.titleMedium?.copyWith(fontSize: 17),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          isDense: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          labelStyle: TextStyle(fontSize: 15),
        ),
        dropdownMenuTheme: const DropdownMenuThemeData(
          textStyle: TextStyle(fontSize: 15),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
