import 'dart:io';
import 'package:flutter/material.dart';
import '../currency_controller.dart';
import '../models/models.dart';
import '../services/database_helper.dart';

class CustomerMenuScreen extends StatefulWidget {
  final AppUser? customer;
  final String? initialUsername;
  const CustomerMenuScreen({super.key, this.customer, this.initialUsername});
  @override State<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends State<CustomerMenuScreen> {
  List<Product> products = [];
  List<Category> categories = [];
  Map<int, int> cart = {};
  AppUser? customer;
  int? categoryId;
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    customer = widget.customer;
    _load();
  }

  Future<void> _load() async {
    final result = await Future.wait([DatabaseHelper.instance.getProducts(), DatabaseHelper.instance.getCategories()]);
    if (!mounted) return;
    setState(() { products = result[0] as List<Product>; categories = result[1] as List<Category>; });
    await _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (customer?.id == null) return;
    final value = await DatabaseHelper.instance.getOrders(userId: customer!.id);
    if (mounted) setState(() => orders = value);
  }

  double get total => cart.entries.fold<double>(0, (sum, entry) {
    final product = products.firstWhere((p) => p.id == entry.key);
    return sum + product.sellingPrice * entry.value;
  });

  void _add(Product product) {
    if ((cart[product.id!] ?? 0) >= product.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الكمية المطلوبة غير متوفرة حالياً')));
      return;
    }
    setState(() => cart[product.id!] = (cart[product.id!] ?? 0) + 1);
  }

  Future<void> _confirmOrder() async {
    if (cart.isEmpty) return;
    final name = TextEditingController(text: customer?.name ?? widget.initialUsername ?? '');
    final password = TextEditingController(text: customer?.password ?? '');
    final phone = TextEditingController(text: customer?.phone ?? '');
    final address = TextEditingController(text: customer?.address ?? '');
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('بيانات العميل لتأكيد الطلب'),
      content: SizedBox(width: 430, child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم المستخدم'), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم المستخدم' : null),
        const SizedBox(height: 10),
        TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور'), validator: (v) => v == null || v.length < 3 ? 'كلمة المرور قصيرة' : null),
        const SizedBox(height: 10),
        TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف'), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل رقم الهاتف' : null),
        const SizedBox(height: 10),
        TextFormField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'عنوان التوصيل'), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل عنوان التوصيل' : null),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true); }, child: const Text('تأكيد الطلب'))],
    ));
    if (confirmed != true) return;
    final userId = await DatabaseHelper.instance.saveCustomer(username: name.text, password: password.text, phone: phone.text, address: address.text);
    customer = AppUser(id: userId, code: 'CUS-$userId', name: name.text.trim(), password: password.text, phone: phone.text.trim(), address: address.text.trim());
    final items = cart.entries.map((entry) {
      final product = products.firstWhere((p) => p.id == entry.key);
      final quantity = entry.value;
      return {'productId': product.id, 'productName': product.name, 'price': product.sellingPrice, 'quantity': quantity, 'total': product.sellingPrice * quantity};
    }).toList();
    await DatabaseHelper.instance.insertOrder({'userId': userId, 'customerName': name.text.trim(), 'phone': phone.text.trim(), 'address': address.text.trim(), 'status': 'pending', 'totalAmount': total, 'currencyCode': currencySettings.value.code, 'exchangeRate': currencySettings.value.rate, 'createdAt': DateTime.now().toIso8601String()}, items);
    setState(() => cart.clear());
    await _loadOrders();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الطلب بنجاح، ستظهر حالته هنا بعد المعالجة')));
  }

  String _status(String value) => {'pending': 'قيد المراجعة', 'preparing': 'قيد التجهيز', 'shipped': 'تم الشحن', 'delivered': 'تم التوصيل', 'cancelled': 'ملغى'}[value] ?? value;

  @override
  Widget build(BuildContext context) {
    final shown = products.where((p) => categoryId == null || p.categoryId == categoryId).where((p) => p.isForSale).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('المتجر الإلكتروني'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load), Badge(label: Text('${cart.values.fold<int>(0, (a, b) => a + b)}'), child: IconButton(icon: const Icon(Icons.shopping_cart), onPressed: () => showModalBottomSheet(context: context, builder: (_) => _cartSheet()))) ]),
      body: Directionality(textDirection: TextDirection.rtl, child: Column(children: [
        Padding(padding: const EdgeInsets.all(10), child: DropdownButtonFormField<int>(value: categoryId, decoration: const InputDecoration(labelText: 'جرد حسب الصنف', border: OutlineInputBorder()), items: [const DropdownMenuItem<int>(value: null, child: Text('كل الأصناف')), ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))], onChanged: (v) => setState(() => categoryId = v))),
        Expanded(child: GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 210, mainAxisExtent: 255, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: shown.length, itemBuilder: (_, index) { final product = shown[index]; final image = product.imagePath; return Card(child: Column(children: [Expanded(child: image != null && File(image).existsSync() ? Image.file(File(image), fit: BoxFit.cover, width: double.infinity) : const Center(child: Icon(Icons.inventory_2, size: 60))), Padding(padding: const EdgeInsets.all(6), child: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))), Text(currencySettings.value.format(product.sellingPrice)), const SizedBox(height: 4), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: product.quantity > 0 ? () => _add(product) : null, icon: const Icon(Icons.add_shopping_cart), label: const Text('إضافة للسلة')))])); })),
        if (orders.isNotEmpty) SizedBox(height: 105, child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10), scrollDirection: Axis.horizontal, children: orders.map((o) => Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('طلب #${o['id']}'), Text(_status(o['status']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9C3FC1))), Text(currencySettings.value.format((o['totalAmount'] as num).toDouble()))])))).toList())),
      ])),
    );
  }

  Widget _cartSheet() => StatefulBuilder(builder: (context, setSheetState) => Directionality(textDirection: TextDirection.rtl, child: SafeArea(child: Column(children: [const Padding(padding: EdgeInsets.all(12), child: Text('سلة الطلب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), Expanded(child: cart.isEmpty ? const Center(child: Text('السلة فارغة')) : ListView(children: cart.entries.map((entry) { final p = products.firstWhere((x) => x.id == entry.key); return ListTile(title: Text(p.name), subtitle: Text('الكمية: ${entry.value} | ${currencySettings.value.format(p.sellingPrice * entry.value)}'), trailing: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () { setState(() { if (entry.value <= 1) { cart.remove(entry.key); } else { cart[entry.key] = entry.value - 1; } }); setSheetState(() {}); })); }).toList())), Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text('الإجمالي: ${currencySettings.value.format(total)}', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: cart.isEmpty ? null : () { Navigator.pop(context); _confirmOrder(); }, icon: const Icon(Icons.check_circle), label: const Text('تأكيد الطلب')))]))]))));
}
