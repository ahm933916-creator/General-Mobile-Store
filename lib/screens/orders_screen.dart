import 'package:flutter/material.dart';
import '../currency_controller.dart';
import '../services/database_helper.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  final statuses = const {'pending': 'قيد المراجعة', 'preparing': 'قيد التجهيز', 'shipped': 'تم الشحن', 'delivered': 'تم التوصيل', 'cancelled': 'ملغى'};

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final value = await DatabaseHelper.instance.getOrders(); if (mounted) setState(() { orders = value; loading = false; }); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('طلبات المتجر'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
    body: loading ? const Center(child: CircularProgressIndicator()) : orders.isEmpty ? const Center(child: Text('لا توجد طلبات حتى الآن')) : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.all(10), itemCount: orders.length, itemBuilder: (_, index) {
      final order = orders[index];
      final items = (order['items'] as List).cast<Map<String, dynamic>>();
      final status = order['status'].toString();
      return Card(child: ExpansionTile(
        leading: CircleAvatar(child: Text('${order['id']}')),
        title: Text('طلب #${order['id']} - ${order['customerName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${statuses[status] ?? status} | ${currencySettings.value.format((order['totalAmount'] as num).toDouble())}\n${order['phone']} - ${order['address']}\n${order['deliveredAt'] == null ? 'طلب إلكتروني' : 'تاريخ التوصيل: ${order['deliveredAt'].toString().substring(0, 10)}'}'),
        children: [
          ...items.map((item) => ListTile(title: Text(item['productName'].toString()), trailing: Text('× ${item['quantity']}'))),
          Padding(padding: const EdgeInsets.all(12), child: DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'حالة الطلب', border: OutlineInputBorder()), items: statuses.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) async { if (value == null) return; await DatabaseHelper.instance.updateOrderStatus(order['id'] as int, value); if (context.mounted && (value == 'shipped' || value == 'delivered')) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التأكد من الفاتورة الإلكترونية وإضافتها للمبيعات إذا لم تكن موجودة'))); _load(); })),
        ],
      ));
    })),
  );
}
