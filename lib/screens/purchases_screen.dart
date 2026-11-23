import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/models.dart';
import '../services/database_helper.dart';
import '../currency_controller.dart';
import 'barcode_scanner_screen.dart';
import 'product_map_screen.dart';
import 'suppliers_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List invoices = [], products = [], suppliers = [];
  final GlobalKey _tableKey = GlobalKey();

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final values = await Future.wait([
      DatabaseHelper.instance.getPurchaseInvoices(),
      DatabaseHelper.instance.getProducts(),
      DatabaseHelper.instance.getSuppliers(),
    ]);
    if (mounted) setState(() {
      invoices = values[0]; products = values[1]; suppliers = values[2];
    });
  }

  Future<String?> _scanBarcode() async {
    if (Platform.isLinux || Platform.isWindows) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ماسح الكاميرا متاح على الهاتف فقط.')));
      return null;
    }
    return Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
  }

  Future<String?> _readBarcodeFromImage(String path) async {
    if (Platform.isLinux || Platform.isWindows) return null;
    final controller = MobileScannerController(autoStart: false);
    try {
      final capture = await controller.analyzeImage(path);
      for (final barcode in capture?.barcodes ?? []) {
        final value = barcode.rawValue?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    } finally { await controller.dispose(); }
  }

  Future<void> createInvoice() async {
    if (products.isEmpty || suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف مورداً ومنتجاً أولاً')));
      return;
    }
    final number = TextEditingController(text: 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final barcode = TextEditingController();
    final price = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final paid = TextEditingController();
    Supplier supplier = suppliers.first;
    Product? selectedProduct;
    bool paidManually = false;
    final items = <Map<String, dynamic>>[];

    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final total = items.fold<double>(0, (sum, item) => sum + (item['total'] as double));
        final paidAmount = paidManually ? (double.tryParse(paid.text) ?? 0) : total;
        final debt = (total - paidAmount).clamp(0, double.infinity).toDouble();

        void choose(Product product) {
          selectedProduct = product;
          price.text = product.purchasePrice.toString();
          quantity.text = '1';
          setDialogState(() {});
        }

        void addProduct() {
          if (selectedProduct == null) return;
          final qty = int.tryParse(quantity.text) ?? 0;
          final unitPrice = double.tryParse(price.text) ?? 0;
          if (qty <= 0 || unitPrice < 0) return;
          final existing = items.where((item) => item['productId'] == selectedProduct!.id).toList();
          if (existing.isEmpty) {
            items.add({'productId': selectedProduct!.id, 'productName': selectedProduct!.name, 'price': unitPrice, 'quantity': qty, 'total': unitPrice * qty});
          } else {
            final item = existing.first;
            item['quantity'] = (item['quantity'] as int) + qty;
            item['price'] = unitPrice;
            item['total'] = (item['quantity'] as int) * unitPrice;
          }
          selectedProduct = null;
          price.clear(); quantity.text = '1'; barcode.clear();
          setDialogState(() {});
        }

        void selectBarcode(String code) {
          barcode.text = code;
          final matches = products.whereType<Product>().where((p) => p.code.toLowerCase() == code.toLowerCase());
          if (matches.isNotEmpty) choose(matches.first);
          else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المنتج غير موجود')));
        }

        return AlertDialog(
          title: const Text('إنشاء فاتورة مشتريات جديدة', textDirection: TextDirection.rtl, style: TextStyle(color: Color(0xFF9C3FC1), fontWeight: FontWeight.bold)),
          content: SizedBox(width: 850, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: number, readOnly: true, decoration: const InputDecoration(labelText: 'رقم الفاتورة', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: TextEditingController(text: DateTime.now().toIso8601String().split('T').first), readOnly: true, decoration: const InputDecoration(labelText: 'تاريخ الفاتورة', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField<Supplier>(initialValue: supplier, items: suppliers.cast<Supplier>().map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.code})'))).toList(), onChanged: (v) { if (v != null) setDialogState(() => supplier = v); }, decoration: const InputDecoration(labelText: 'اختر المورد', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: barcode, decoration: InputDecoration(labelText: 'مسح الباركود أو إدخال كود المنتج', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.qr_code_scanner, color: Color(0xFF9C3FC1)), suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'بحث', icon: const Icon(Icons.search, color: Color(0xFF9C3FC1)), onPressed: () => selectBarcode(barcode.text.trim())),
              IconButton(tooltip: 'الكاميرا', icon: const Icon(Icons.qr_code_scanner, color: Colors.blue), onPressed: () async { final code = await _scanBarcode(); if (code != null) selectBarcode(code); }),
              IconButton(tooltip: 'خريطة المنتجات', icon: const Icon(Icons.grid_view, color: Colors.orange), onPressed: () async { final product = await Navigator.push<Product>(context, MaterialPageRoute(builder: (_) => ProductMapScreen(products: products.cast<Product>()))); if (product != null) choose(product); }),
              IconButton(tooltip: 'اختيار صورة باركود', icon: const Icon(Icons.folder_open, color: Colors.teal), onPressed: () async { final result = await FilePicker.platform.pickFiles(type: FileType.image); final path = result?.files.single.path; if (path == null) return; final code = await _readBarcodeFromImage(path); if (code != null) selectBarcode(code); else if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر قراءة الباركود من الصورة'))); }),
            ])), onSubmitted: selectBarcode),
            const Divider(height: 30, thickness: 2),
            DropdownButtonFormField<Product>(initialValue: selectedProduct, hint: const Text('المنتج المحدد'), isExpanded: true, items: products.cast<Product>().map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (المخزون ${p.quantity})'))).toList(), onChanged: (v) { if (v != null) choose(v); }, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الشراء', border: OutlineInputBorder()))), const SizedBox(width: 8), Expanded(child: TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()))), const SizedBox(width: 8), SizedBox(height: 56, child: ElevatedButton.icon(onPressed: addProduct, icon: const Icon(Icons.add), label: const Text('إضافة المنتج للفاتورة')))]),
            const SizedBox(height: 12),
            const Text('المنتجات المضافة للفاتورة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Container(
              height: 150,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
              child: items.isEmpty
                  ? const Center(child: Text('لم يتم إدراج منتجات في الفاتورة بعد'))
                  : ListView(
                      children: items.asMap().entries.map((entry) {
                        final item = entry.value;
                        return ListTile(
                          title: Text('${entry.key + 1}. ${item['productName']}'),
                          subtitle: Text('الكمية: ${item['quantity']} | السعر: ${currencySettings.value.format((item['price'] as num).toDouble())} | الإجمالي: ${currencySettings.value.format((item['total'] as num).toDouble())}'),
                          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setDialogState(() => items.removeAt(entry.key))),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: Text('مجموع الفاتورة: ${currencySettings.value.format(total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))), Expanded(child: TextField(controller: paid, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الدفعة الواصلة', border: OutlineInputBorder()), onChanged: (_) => setDialogState(() => paidManually = true))), Expanded(child: Text('الديون المتبقية: ${currencySettings.value.format(debt)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)))])
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء', style: TextStyle(color: Color(0xFF9C3FC1)))),
            ElevatedButton(onPressed: () async { if (items.isEmpty) return; final result = await DatabaseHelper.instance.insertPurchaseInvoice({'invoiceNumber': number.text, 'date': DateTime.now().toIso8601String().split('T').first, 'supplierId': supplier.id, 'totalAmount': total, 'paidAmount': paidAmount, 'remainingDebt': debt, 'currencyCode': currencySettings.value.code, 'exchangeRate': currencySettings.value.rate, 'items': items}); if (result > 0 && dialogContext.mounted) Navigator.pop(dialogContext); load(); }, child: const Text('حفظ الفاتورة النهائية')),
          ],
        );
      },
    ));
  }

  void _showTablePreview() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('معاينة جدول المشتريات'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: _tableKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Table(
                    border: TableBorder.all(color: Colors.grey),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFF7B2FA0)),
                        children: [
                          Padding(padding: EdgeInsets.all(6), child: Text('الفاتورة', style: TextStyle(color: Colors.white))),
                          Padding(padding: EdgeInsets.all(6), child: Text('التاريخ', style: TextStyle(color: Colors.white))),
                          Padding(padding: EdgeInsets.all(6), child: Text('المورد', style: TextStyle(color: Colors.white))),
                          Padding(padding: EdgeInsets.all(6), child: Text('الإجمالي', style: TextStyle(color: Colors.white))),
                        ],
                      ),
                      ...invoices.map((i) => TableRow(children: [
                        Padding(padding: const EdgeInsets.all(6), child: Text('${i['invoiceNumber']}')),
                        Padding(padding: const EdgeInsets.all(6), child: Text('${i['date']}')),
                        Padding(padding: const EdgeInsets.all(6), child: Text('${i['supplierName'] ?? 'مورد'}')),
                        Padding(padding: const EdgeInsets.all(6), child: Text(formatStoredAmount((i['totalAmount'] as num).toDouble(), code: i['currencyCode']?.toString(), rate: (i['exchangeRate'] as num?)?.toDouble()))),
                      ])),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = invoices.fold<double>(0, (sum, i) => sum + convertStoredAmount((i['totalAmount'] as num).toDouble(), code: i['currencyCode']?.toString(), rate: (i['exchangeRate'] as num?)?.toDouble()));
    final debt = invoices.fold<double>(0, (sum, i) => sum + convertStoredAmount((i['remainingDebt'] as num).toDouble(), code: i['currencyCode']?.toString(), rate: (i['exchangeRate'] as num?)?.toDouble()));
    return Scaffold(appBar: AppBar(title: const Text('المشتريات'), actions: [TextButton.icon(style: TextButton.styleFrom(foregroundColor: Colors.white), icon: const Icon(Icons.table_chart), label: const Text('معاينة الجدول'), onPressed: _showTablePreview), TextButton.icon(style: TextButton.styleFrom(foregroundColor: Colors.white), icon: const Icon(Icons.people), label: const Text('الموردون'), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen())); load(); }), IconButton(icon: const Icon(Icons.refresh), onPressed: load)]), floatingActionButton: FloatingActionButton(onPressed: createInvoice, child: const Icon(Icons.add)), body: Column(children: [Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: _stat('مجموع المشتريات', total, Colors.blue)), Expanded(child: _stat('الأرباح', 0, Colors.green)), Expanded(child: _stat('الديون', debt, Colors.red)), Expanded(child: _stat('الصافي', total - debt, Colors.orange))])), Expanded(child: invoices.isEmpty ? const Center(child: Text('لا توجد فواتير مشتريات')) : ListView.builder(itemCount: invoices.length, itemBuilder: (context, index) { final i = invoices[index]; final code = i['currencyCode']?.toString(); final rate = (i['exchangeRate'] as num?)?.toDouble(); return Card(child: ListTile(title: Text('فاتورة ${i['invoiceNumber']} | ${i['supplierName'] ?? 'مورد'}'), subtitle: Text('${i['date']}\nالإجمالي: ${formatStoredAmount((i['totalAmount'] as num).toDouble(), code: code, rate: rate)} | الدين: ${formatStoredAmount((i['remainingDebt'] as num).toDouble(), code: code, rate: rate)}'), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { await DatabaseHelper.instance.deletePurchaseInvoice(i['id']); load(); }))); }))]));
  }

  Widget _stat(String label, double value, Color color) => Card(child: Padding(padding: const EdgeInsets.all(6), child: Column(children: [Text(label, style: TextStyle(color: color, fontSize: 11)), ValueListenableBuilder(valueListenable: currencySettings, builder: (_, __, ___) => Text(currencySettings.value.format(value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))])));
}
