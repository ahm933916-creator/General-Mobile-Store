import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/home_screen.dart';
import 'theme_controller.dart';
import 'currency_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await loadThemeMode();
  await loadCurrencySettings();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme({required bool dark, required bool isPhone}) {
    const primaryPurple = Color(0xFF9C3FC1);
    const navyBackground = Color(0xFF152B3B);
    const panelColor = Color(0xFF20394C);
    const fieldColor = Color(0xFF2D465B);
    const borderColor = Color(0xFF617C93);
    const gold = Color(0xFFF0C744);
    const lightBackground = Color(0xFFF4F6F8);
    const lightPanel = Colors.white;
    const lightField = Color(0xFFF0F2F5);
    const lightBorder = Color(0xFFB9C3CC);
    final background = dark ? navyBackground : lightBackground;
    final panel = dark ? panelColor : lightPanel;
    final field = dark ? fieldColor : lightField;
    final border = dark ? borderColor : lightBorder;
    final foreground = dark ? Colors.white : const Color(0xFF1D2933);
    final muted = dark ? const Color(0xFFD4DDE3) : const Color(0xFF52606D);
    final baseTextTheme = dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    return ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: primaryPurple,
        onPrimary: Colors.white,
        secondary: gold,
        onSecondary: const Color(0xFF172A39),
        surface: panel,
        onSurface: foreground,
        error: const Color(0xFFE05252),
        onError: Colors.white,
      ),
      primaryColor: primaryPurple,
      cardColor: panel,
      dividerColor: border,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? panelColor : primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.all(6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(color: dark ? gold : primaryPurple, fontSize: 19, fontWeight: FontWeight.bold),
      ),
      textTheme: baseTextTheme.copyWith(
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: isPhone ? 15 : 17, color: foreground),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: isPhone ? 14 : 16, color: foreground),
        bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: isPhone ? 12 : 14, color: muted),
        labelLarge: baseTextTheme.labelLarge?.copyWith(fontSize: isPhone ? 13 : 15, fontWeight: FontWeight.w600),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontSize: isPhone ? 15 : 17, color: dark ? gold : primaryPurple),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isPhone ? 11 : 15),
        labelStyle: TextStyle(color: dark ? gold : primaryPurple, fontSize: isPhone ? 13 : 15),
        hintStyle: TextStyle(color: dark ? const Color(0xFFB8C4CD) : const Color(0xFF687782)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: gold, width: 1.5)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: foreground),
        menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(panel)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: dark ? gold : primaryPurple)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final isPhone = view.physicalSize.width / view.devicePixelRatio < 600;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'إدارة المبيعات والمنتجات',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: _buildTheme(dark: false, isPhone: isPhone),
        darkTheme: _buildTheme(dark: true, isPhone: isPhone),
        home: const HomeScreen(),
      ),
    );
  }
}
