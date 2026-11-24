import 'package:flutter/material.dart';
import 'products_screen.dart';
import 'users_screen.dart';
import 'appointments_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart'; // ⚙️ استيراد صفحة الإعدادات الجديدة
import 'purchases_screen.dart';
import 'orders_screen.dart';

class HomeScreen extends StatefulWidget {
  final String role;
  final String displayName;
  const HomeScreen({super.key, this.role = 'manager', this.displayName = 'المدير العام'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens {
    final common = <Widget>[const AppointmentsScreen(), const PurchasesScreen(), const ProductsScreen(), const UsersScreen(), const OrdersScreen()];
    if (widget.role == 'manager') return [...common, const ExpensesScreen(), const ReportsScreen(), const SettingsScreen()];
    return common;
  }

  List<BottomNavigationBarItem> get _items {
    final common = const [
      BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'المبيعات'),
      BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'المشتريات'),
      BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'المنتجات'),
      BottomNavigationBarItem(icon: Icon(Icons.people), label: 'المستخدمين'),
      BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'الطلبات'),
    ];
    if (widget.role == 'manager') return [...common, const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'المصروفات'), const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'التقارير'), const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات')];
    return common;
  }

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
          items: _items,
        ),
      ),
    );
  }
}
