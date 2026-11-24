import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../currency_controller.dart';
import '../models/models.dart';
import '../services/database_helper.dart';
import 'login_screen.dart';

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
  Set<int> favorites = {};
  AppUser? customer;
  int? categoryId;
  String query = '';
  String displayCode = 'SYP';
  List<Map<String, dynamic>> orders = [];

  CurrencySettings get displayCurrency => CurrencySettings(code: displayCode, rate: currencySettings.value.rate);

  @override
  void initState() {
    super.initState();
    customer = widget.customer;
    displayCode = currencySettings.value.code;
    _load();
  }

  Future<void> _load() async {
    final result = await Future.wait([
      DatabaseHelper.instance.getProducts(),
      DatabaseHelper.instance.getCategories(),
    ]);
    final prefs = await SharedPreferences.getInstance();
    final key = 'customer_favorites_${customer?.phone ?? widget.initialUsername ?? 'guest'}';
    final saved = prefs.getStringList(key) ?? [];
    if (!mounted) return;
    setState(() {
      products = result[0] as List<Product>;
      categories = result[1] as List<Category>;
      favorites = saved.map(int.parse).toSet();
    });
    await _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (customer?.id == null) return;
    final value = await DatabaseHelper.instance.getOrders(userId: customer!.id);
    if (mounted) setState(() => orders = value);
  }

  double _price(Product product, [int quantity = 1]) {
    return convertStoredAmount(
      product.sellingPrice * quantity,
      code: product.currencyCode,
      rate: currencySettings.value.rate,
      target: displayCurrency,
    );
  }

  String _formatProductPrice(Product product, [int quantity = 1]) => displayCurrency.format(_price(product, quantity));

  double get total => cart.entries.fold(0, (sum, entry) {
        final product = products.firstWhere((p) => p.id == entry.key);
        return sum + _price(product, entry.value);
      });

  Future<void> _toggleFavorite(Product product) async {
    final id = product.id!;
    setState(() {
      if (favorites.contains(id)) {
        favorites.remove(id);
      } else {
        favorites.add(id);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    final key = 'customer_favorites_${customer?.phone ?? widget.initialUsername ?? 'guest'}';
    await prefs.setStringList(key, favorites.map((e) => e.toString()).toList());
  }

  void _add(Product product) {
    if ((cart[product.id!] ?? 0) >= product.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الكمية المطلوبة غير متوفرة حالياً')));
      return;
    }
    setState(() => cart[product.id!] = (cart[product.id!] ?? 0) + 1);
  }

  String _status(String value) => {
        'pending': 'قيد المراجعة',
        'preparing': 'قيد التجهيز',
        'shipped': 'تم الشحن',
        'delivered': 'تم التوصيل',
        'cancelled': 'ملغى',
      }[value] ?? value;

  Future<void> _confirmOrder() async {
    if (cart.isEmpty) return;
    final name = TextEditingController(text: customer?.name ?? '');
    final password = TextEditingController(text: customer?.password ?? '');
    final phone = TextEditingController(text: customer?.phone ?? widget.initialUsername ?? '');
    final address = TextEditingController(text: customer?.address ?? '');
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بيانات العميل لتأكيد الطلب'),
        content: SizedBox(
          width: 430,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم المستخدم'), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل الاسم' : null),
                  TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور'), validator: (v) => v == null || v.length < 3 ? 'كلمة المرور قصيرة' : null),
                  TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف'), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل رقم الهاتف' : null),
                  TextFormField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'عنوان التوصيل'), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل العنوان' : null),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true); }, child: const Text('تأكيد الطلب')),
        ],
      ),
    );
    if (confirmed != true) return;
    final userId = await DatabaseHelper.instance.saveCustomer(username: name.text, password: password.text, phone: phone.text, address: address.text);
    customer = AppUser(id: userId, code: 'CUS-$userId', name: name.text.trim(), password: password.text, phone: phone.text.trim(), address: address.text.trim());
    final items = cart.entries.map((entry) {
      final product = products.firstWhere((p) => p.id == entry.key);
      return {'productId': product.id, 'productName': product.name, 'price': product.sellingPrice, 'quantity': entry.value, 'total': product.sellingPrice * entry.value};
    }).toList();
    final storedTotal = cart.entries.fold<double>(0, (sum, entry) => sum + products.firstWhere((p) => p.id == entry.key).sellingPrice * entry.value);
    await DatabaseHelper.instance.insertOrder({'userId': userId, 'customerName': name.text.trim(), 'phone': phone.text.trim(), 'address': address.text.trim(), 'status': 'pending', 'totalAmount': storedTotal, 'currencyCode': currencySettings.value.code, 'exchangeRate': currencySettings.value.rate, 'createdAt': DateTime.now().toIso8601String()}, items);
    setState(() => cart.clear());
    await _loadOrders();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الطلب بنجاح')));
  }

  void _showOrders() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الطلبات السابقة'),
        content: SizedBox(
          width: 500,
          child: orders.isEmpty
              ? const Text('لا توجد طلبات سابقة')
              : ListView(
                  shrinkWrap: true,
                  children: orders.map((order) {
                    final date = order['createdAt'].toString();
                    final totalValue = convertStoredAmount((order['totalAmount'] as num).toDouble(), code: order['currencyCode']?.toString(), rate: (order['exchangeRate'] as num?)?.toDouble(), target: displayCurrency);
                    return ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text('طلب #${order['id']} - ${_status(order['status'])}'),
                      subtitle: Text('التاريخ: ${date.length >= 10 ? date.substring(0, 10) : date}\n${order['status'] == 'delivered' ? 'تم التوصيل' : 'تاريخ التسليم يظهر عند التوصيل'}'),
                      trailing: Text(displayCurrency.format(totalValue)),
                    );
                  }).toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ),
    );
  }

  void _showDetails(Product product) {
    final paths = [product.imagePath, ...product.galleryPaths].whereType<String>().where((path) => File(path).existsSync()).toList();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(product.name),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 280,
                  child: paths.isEmpty ? const Icon(Icons.inventory_2, size: 100) : PageView(children: paths.map((path) => Image.file(File(path), fit: BoxFit.contain)).toList()),
                ),
                const SizedBox(height: 12),
                Text('السعر: ${_formatProductPrice(product)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('الكمية المتوفرة: ${product.quantity}'),
                if (product.videoPath != null) ListTile(leading: const Icon(Icons.video_library), title: const Text('يوجد فيديو للمنتج'), subtitle: Text(product.videoPath!)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
          ElevatedButton(onPressed: () { Navigator.pop(dialogContext); _add(product); }, child: const Text('إضافة للسلة')),
        ],
      ),
    );
  }

  void _showFavorites(List<Product> favoriteProducts) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('المنتجات المفضلة'),
        content: SizedBox(
          width: 420,
          child: favoriteProducts.isEmpty
              ? const Text('لا توجد منتجات مفضلة')
              : ListView(shrinkWrap: true, children: favoriteProducts.map((product) => ListTile(title: Text(product.name), subtitle: Text(_formatProductPrice(product)), onTap: () { Navigator.pop(dialogContext); _showDetails(product); })).toList()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = products.where((product) => product.isForSale && (categoryId == null || product.categoryId == categoryId) && (query.trim().isEmpty || product.name.contains(query.trim()) || product.code.contains(query.trim()))).toList();
    final favoriteProducts = shown.where((product) => favorites.contains(product.id)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('المتجر الإلكتروني'),
        actions: [
          IconButton(tooltip: 'تغيير العملة', icon: Text(displayCode == 'USD' ? 'ل.س' : '\$'), onPressed: () => setState(() => displayCode = displayCode == 'USD' ? 'SYP' : 'USD')),
          IconButton(tooltip: 'المفضلة', icon: const Icon(Icons.favorite), onPressed: () => _showFavorites(favoriteProducts)),
          IconButton(tooltip: 'الطلبات السابقة', icon: const Icon(Icons.receipt_long), onPressed: _showOrders),
          Badge(label: Text('${cart.values.fold<int>(0, (a, b) => a + b)}'), child: IconButton(tooltip: 'السلة', icon: const Icon(Icons.shopping_cart), onPressed: () => showModalBottomSheet(context: context, builder: (_) => _cartSheet()))),
          IconButton(tooltip: 'تسجيل الخروج', icon: const Icon(Icons.logout), onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false)),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(value: categoryId, decoration: const InputDecoration(labelText: 'جرد حسب الصنف', border: OutlineInputBorder()), items: [const DropdownMenuItem<int>(value: null, child: Text('كل الأصناف')), ...categories.map((category) => DropdownMenuItem(value: category.id, child: Text(category.name)))], onChanged: (value) => setState(() => categoryId = value)),
                  const SizedBox(height: 8),
                  TextField(decoration: const InputDecoration(labelText: 'بحث عام عن منتج أو رمز', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (value) => setState(() => query = value)),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 210, mainAxisExtent: 285, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: shown.length,
                itemBuilder: (_, index) {
                  final product = shown[index];
                  final image = product.imagePath;
                  return Card(
                    child: Column(
                      children: [
                        Expanded(child: GestureDetector(onTap: () => _showDetails(product), child: image != null && File(image).existsSync() ? Image.file(File(image), fit: BoxFit.cover, width: double.infinity) : const Center(child: Icon(Icons.inventory_2, size: 60)))),
                        Padding(padding: const EdgeInsets.all(6), child: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Text(_formatProductPrice(product)),
                        Row(children: [Expanded(child: ElevatedButton.icon(onPressed: product.quantity > 0 ? () => _add(product) : null, icon: const Icon(Icons.add_shopping_cart), label: const Text('إضافة'))), IconButton(icon: Icon(favorites.contains(product.id) ? Icons.favorite : Icons.favorite_border, color: Colors.red), onPressed: () => _toggleFavorite(product))]),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(12), child: Text('سلة الطلب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              Expanded(child: cart.isEmpty ? const Center(child: Text('السلة فارغة')) : ListView(children: cart.entries.map((entry) { final product = products.firstWhere((item) => item.id == entry.key); return ListTile(title: Text(product.name), subtitle: Text('الكمية: ${entry.value} | ${_formatProductPrice(product, entry.value)}'), trailing: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () { setState(() { if (entry.value <= 1) { cart.remove(entry.key); } else { cart[entry.key] = entry.value - 1; } }); setSheetState(() {}); })); }).toList())),
              Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text('الإجمالي: ${displayCurrency.format(total)}', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: cart.isEmpty ? null : () { Navigator.pop(context); _confirmOrder(); }, icon: const Icon(Icons.check_circle), label: const Text('تأكيد الطلب')))])),
            ],
          ),
        ),
      ),
    );
  }
}
