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
      title: 'إدارة المواعيد والمنتجات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: baseTextTheme.apply(fontSizeFactor: 1.08),
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
