import 'package:flutter/material.dart';
import 'products_screen.dart';
import 'users_screen.dart';
import 'appointments_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart'; // ⚙️ استيراد صفحة الإعدادات الجديدة

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // ⚙️ إضافة شاشة الإعدادات إلى قائمة الشاشات
  final List<Widget> _screens = const [
    AppointmentsScreen(),
    ProductsScreen(),
    UsersScreen(),
    ExpensesScreen(),
    ReportsScreen(),
    SettingsScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          backgroundColor: const Color(0xFF20394C),
          selectedItemColor: const Color(0xFFF0C744),
          unselectedItemColor: const Color(0xFF9FB0BD),
          type: BottomNavigationBarType.fixed, // هام جداً لضمان ظهور أكثر من 4 عناصر بانتظام
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'المبيعات'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'المنتجات'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'المستخدمين'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'المصروفات'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'التقارير'),
            // ⚙️ إضافة أيقونة وزر الإعدادات الجديد في الشريط السفلي بجانبهم
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }
}
