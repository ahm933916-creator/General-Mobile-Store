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
    const primaryPurple = Color(0xFF9C3FC1);
    const darkPurple = Color(0xFF7B2FA0);
    const navyBackground = Color(0xFF152B3B);
    const panelColor = Color(0xFF20394C);
    const fieldColor = Color(0xFF2D465B);
    const borderColor = Color(0xFF617C93);
    const gold = Color(0xFFF0C744);
    final baseTextTheme = ThemeData.dark().textTheme;
    return MaterialApp(
      title: 'إدارة المبيعات والمنتجات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navyBackground,
        canvasColor: navyBackground,
        colorScheme: const ColorScheme.dark(
          primary: primaryPurple,
          onPrimary: Colors.white,
          secondary: gold,
          onSecondary: Color(0xFF172A39),
          surface: panelColor,
          onSurface: Colors.white,
          error: Color(0xFFE05252),
          onError: Colors.white,
        ),
        primaryColor: primaryPurple,
        cardColor: panelColor,
        dividerColor: borderColor,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: panelColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: const CardThemeData(
          color: panelColor,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.all(6),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: panelColor,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(color: gold, fontSize: 19, fontWeight: FontWeight.bold),
        ),
        textTheme: baseTextTheme.copyWith(
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: isPhone ? 15 : 17, color: Colors.white),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: isPhone ? 14 : 16, color: Colors.white),
          bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: isPhone ? 12 : 14, color: const Color(0xFFD4DDE3)),
          labelLarge: baseTextTheme.labelLarge?.copyWith(fontSize: isPhone ? 13 : 15, fontWeight: FontWeight.w600),
          titleMedium: baseTextTheme.titleMedium?.copyWith(fontSize: isPhone ? 15 : 17, color: gold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: fieldColor,
          isDense: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isPhone ? 11 : 15),
          labelStyle: TextStyle(color: gold, fontSize: isPhone ? 13 : 15),
          hintStyle: const TextStyle(color: Color(0xFFB8C4CD)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: gold, width: 1.5),
          ),
        ),
        dropdownMenuTheme: const DropdownMenuThemeData(
          textStyle: TextStyle(color: Colors.white),
          menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(panelColor)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryPurple,
            foregroundColor: Colors.white,
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: gold),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
