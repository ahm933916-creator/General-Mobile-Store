import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_helper.dart';
import '../currency_controller.dart';
import 'product_map_screen.dart';
import 'suppliers_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List invoices = [], products = [], suppliers = [];
  final GlobalKey _tableKey = GlobalKey();
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    final values = await Future.wait([
      DatabaseHelper.instance.getPurchaseInvoices(), DatabaseHelper.instance.getProducts(), DatabaseHelper.instance.getSuppliers(),
    ]);
    if (mounted) setState(() { invoices = values[0]; products = values[1]; suppliers = values[2]; });
  }

  Future<void> createInvoice() async {
    if (products.isEmpty || suppliers.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف مورداً ومنتجاً أولاً'))); return; }
    final number = TextEditingController(text: 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final barcode = TextEditingController(); final paid = TextEditingController();
    final price = TextEditingController(); final qty = TextEditingController(text: '1');
    Supplier supplier = suppliers.first; Product? selected; bool manualPaid = false;
    final items = <Map<String, dynamic>>[];

    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, set) {
      final total = items.fold<double>(0, (sum, item) => sum + (item['total'] as double));
      final paidValue = double.tryParse(paid.text) ?? total;
      final debt = (total - paidValue).clamp(0, double.infinity).toDouble();
      void choose(Product product) { selected = product; price.text = product.purchasePrice.toStringAsFixed(0); qty.text = '1'; set(() {}); }
      void add() {
        if (selected == null) return;
        final quantity = int.tryParse(qty.text) ?? 0; if (quantity <= 0) return;
        final value = double.tryParse(price.text) ?? 0;
        final same = items.where((item) => item['productId'] == selected!.id).toList();
        if (same.isEmpty) { items.add({'productId': selected!.id, 'productName': selected!.name, 'price': value, 'quantity': quantity, 'total': value * quantity}); }
        else { same.first['quantity'] += quantity; same.first['total'] = same.first['quantity'] * value; }
        selected = null; price.clear(); qty.text = '1'; set(() {});
      }
      return AlertDialog(
        title: const Text('إنشاء فاتورة مشتريات'),
        content: SizedBox(width: 760, child: SingleChildScrollView(child: Column(children: [
          TextField(controller: number, readOnly: true, decoration: const InputDecoration(labelText: 'رقم الفاتورة')),
          const SizedBox(height: 8),
          DropdownButtonFormField<Supplier>(value: supplier, items: suppliers.map<DropdownMenuItem<Supplier>>((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.code})'))).toList(), onChanged: (v) { if (v != null) set(() => supplier = v); }, decoration: const InputDecoration(labelText: 'المورد')),
          const SizedBox(height: 8),
          TextField(controller: barcode, decoration: const InputDecoration(labelText: 'مسح الباركود أو إدخال كود المنتج', prefixIcon: Icon(Icons.qr_code_scanner)), onSubmitted: (value) { try { choose(products.cast<Product>().firstWhere((p) => p.code.toLowerCase() == value.trim().toLowerCase())); } catch (_) {} }),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: DropdownButtonFormField<Product>(value: selected, hint: const Text('اختر المنتج'), items: products.cast<Product>().map<DropdownMenuItem<Product>>((p) => DropdownMenuItem(value: p, child: Text('${p.name} (المخزون ${p.quantity})'))).toList(), onChanged: (v) { if (v != null) choose(v); }, decoration: const InputDecoration(labelText: 'المنتج'))),
            IconButton(icon: const Icon(Icons.map, color: Color(0xFF9C3FC1)), tooltip: 'خريطة المنتجات', onPressed: () async { final p = await Navigator.push<Product>(context, MaterialPageRoute(builder: (_) => ProductMapScreen(products: products.cast<Product>()))); if (p != null) choose(p); }),
          ]),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الشراء'))), const SizedBox(width: 8), Expanded(child: TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية'))), IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: add)]),
          const Divider(),
          ...items.asMap().entries.map((entry) => ListTile(title: Text('${entry.key + 1}. ${entry.value['productName']}'), subtitle: Text('الكمية: ${entry.value['quantity']} | ${currencySettings.value.format(entry.value['total'])}'), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => set(() => items.removeAt(entry.key))))),
          const Divider(),
          Row(children: [Expanded(child: Text('الإجمالي: ${currencySettings.value.format(total)}', style: const TextStyle(fontWeight: FontWeight.bold))), Expanded(child: TextField(controller: paid, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الدفعة'), onChanged: (_) { manualPaid = true; set(() {}); }))]),
          Align(alignment: Alignment.centerRight, child: Text('الدين: ${currencySettings.value.format(debt)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () async { if (items.isEmpty) return; final value = manualPaid ? (double.tryParse(paid.text) ?? 0) : total; await DatabaseHelper.instance.insertPurchaseInvoice({'invoiceNumber': number.text, 'date': DateTime.now().toIso8601String().split('T').first, 'supplierId': supplier.id, 'totalAmount': total, 'paidAmount': value, 'remainingDebt': (total - value).clamp(0, double.infinity), 'currencyCode': currencySettings.value.code, 'exchangeRate': currencySettings.value.rate, 'items': items}); if (dialogContext.mounted) Navigator.pop(dialogContext); load(); }, child: const Text('حفظ الفاتورة')),
        ],
      );
    }));
  }

  void _showTablePreview() {
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('معاينة جدول المشتريات'),
      content: SizedBox(width: 760, child: SingleChildScrollView(child: RepaintBoundary(
        key: _tableKey,
        child: Container(color: Colors.white, padding: const EdgeInsets.all(12), child: Directionality(
          textDirection: TextDirection.rtl,
          child: Table(border: TableBorder.all(color: Colors.grey), children: [
            const TableRow(decoration: BoxDecoration(color: Color(0xFF7B2FA0)), children: [
              Padding(padding: EdgeInsets.all(6), child: Text('الفاتورة', style: TextStyle(color: Colors.white))), Padding(padding: EdgeInsets.all(6), child: Text('التاريخ', style: TextStyle(color: Colors.white))), Padding(padding: EdgeInsets.all(6), child: Text('المورد', style: TextStyle(color: Colors.white))), Padding(padding: EdgeInsets.all(6), child: Text('الإجمالي', style: TextStyle(color: Colors.white))),
            ]),
            ...invoices.map((i) => TableRow(children: [Padding(padding: const EdgeInsets.all(6), child: Text('${i['invoiceNumber']}')), Padding(padding: const EdgeInsets.all(6), child: Text('${i['date']}')), Padding(padding: const EdgeInsets.all(6), child: Text('${i['supplierName'] ?? 'مورد'}')), Padding(padding: const EdgeInsets.all(6), child: Text(formatStoredAmount((i['totalAmount'] as num).toDouble(), code: i['currencyCode']?.toString(), rate: (i['exchangeRate'] as num?)?.toDouble())))])),
          ]),
        )),
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
    ));
  }

  @override Widget build(BuildContext context) {
    final total = invoices.fold<double>(0, (sum, i) => sum + (i['totalAmount'] as num).toDouble());
    final debt = invoices.fold<double>(0, (sum, i) => sum + (i['remainingDebt'] as num).toDouble());
    return Scaffold(
      appBar: AppBar(title: const Text('المشتريات'), actions: [TextButton.icon(style: TextButton.styleFrom(foregroundColor: Colors.white), icon: const Icon(Icons.table_chart), label: const Text('معاينة الجدول'), onPressed: _showTablePreview), TextButton.icon(style: TextButton.styleFrom(foregroundColor: Colors.white), icon: const Icon(Icons.people), label: const Text('الموردون'), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen())); load(); }), IconButton(icon: const Icon(Icons.refresh), onPressed: load)]),
      floatingActionButton: FloatingActionButton(onPressed: createInvoice, child: const Icon(Icons.add)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: _stat('المشتريات', total, Colors.blue)), Expanded(child: _stat('الأرباح', 0, Colors.green)), Expanded(child: _stat('الديون', debt, Colors.red)), Expanded(child: _stat('الصافي', total - debt, Colors.orange))])),
        Expanded(child: invoices.isEmpty ? const Center(child: Text('لا توجد فواتير مشتريات')) : ListView.builder(itemCount: invoices.length, itemBuilder: (context, index) { final i = invoices[index]; final code = i['currencyCode']?.toString(); final rate = (i['exchangeRate'] as num?)?.toDouble(); return Card(child: ListTile(title: Text('فاتورة ${i['invoiceNumber']} | ${i['supplierName'] ?? 'مورد'}'), subtitle: Text('${i['date']}\nالإجمالي: ${formatStoredAmount((i['totalAmount'] as num).toDouble(), code: code, rate: rate)} | الدين: ${formatStoredAmount((i['remainingDebt'] as num).toDouble(), code: code, rate: rate)}'), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { await DatabaseHelper.instance.deletePurchaseInvoice(i['id']); load(); }))); })),
      ]),
    );
  }
  Widget _stat(String label, double value, Color color) => Card(child: Padding(padding: const EdgeInsets.all(6), child: Column(children: [Text(label, style: TextStyle(color: color, fontSize: 11)), ValueListenableBuilder(valueListenable: currencySettings, builder: (_, __, ___) => Text(currencySettings.value.format(value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))])));
}
