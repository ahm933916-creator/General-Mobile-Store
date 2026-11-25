import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/models.dart';
import '../services/database_helper.dart';
import '../services/image_storage_service.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _dateFilterType;
  String? _specificDate;
  String? _startDate;
  String? _endDate;

  @override
  void initState() { super.initState(); load(); }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List _filteredInvoices() {
    final query = _searchQuery.trim().toLowerCase();
    return invoices.where((invoice) {
      final number = invoice['invoiceNumber']?.toString().toLowerCase() ?? '';
      final supplier = invoice['supplierName']?.toString().toLowerCase() ?? '';
      final date = invoice['date']?.toString() ?? '';
      final matchesSearch = query.isEmpty || number.contains(query) || supplier.contains(query);
      var matchesDate = true;
      if (_dateFilterType == 'specific' && _specificDate != null) {
        matchesDate = date == _specificDate;
      } else if (_dateFilterType == 'range' && _startDate != null && _endDate != null) {
        matchesDate = date.compareTo(_startDate!) >= 0 && date.compareTo(_endDate!) <= 0;
      }
      return matchesSearch && matchesDate;
    }).toList();
  }

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

  Future<void> createInvoice({Map? invoiceToEdit}) async {
    if (products.isEmpty || suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف مورداً ومنتجاً أولاً')));
      return;
    }
    final number = TextEditingController(text: invoiceToEdit?['invoiceNumber']?.toString() ?? 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final barcode = TextEditingController();
    final price = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final paid = TextEditingController(text: invoiceToEdit?['paidAmount']?.toString() ?? '');
    Supplier supplier = suppliers.cast<Supplier>().firstWhere((s) => s.id == invoiceToEdit?['supplierId'], orElse: () => suppliers.first as Supplier);
    Product? selectedProduct;
    bool paidManually = invoiceToEdit != null && (invoiceToEdit['paidAmount'] as num?)?.toDouble() != (invoiceToEdit['totalAmount'] as num?)?.toDouble();
    final items = <Map<String, dynamic>>[
      for (final item in (invoiceToEdit?['items'] as List? ?? const []))
        {'productId': item['productId'], 'productName': item['productName'], 'price': (item['price'] as num).toDouble(), 'quantity': (item['quantity'] as num).toInt(), 'total': (item['total'] as num).toDouble()},
    ];

    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final total = items.fold<double>(0, (sum, item) => sum + (item['total'] as double));
        if (!paidManually) paid.text = total.toStringAsFixed(2);
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
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الشراء', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            SizedBox(height: 52, child: ElevatedButton.icon(onPressed: addProduct, icon: const Icon(Icons.add), label: const Text('إضافة المنتج للفاتورة'))),
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
            ElevatedButton(onPressed: () async { if (items.isEmpty) return; final data = {'invoiceNumber': number.text, 'date': invoiceToEdit?['date']?.toString() ?? DateTime.now().toIso8601String().split('T').first, 'supplierId': supplier.id, 'totalAmount': total, 'paidAmount': paidAmount, 'remainingDebt': debt, 'currencyCode': invoiceToEdit?['currencyCode'] ?? currencySettings.value.code, 'exchangeRate': invoiceToEdit?['exchangeRate'] ?? currencySettings.value.rate, 'items': items}; final result = invoiceToEdit == null ? await DatabaseHelper.instance.insertPurchaseInvoice(data) : await DatabaseHelper.instance.updatePurchaseInvoice(invoiceToEdit['id'] as int, data); if (result > 0 && dialogContext.mounted) Navigator.pop(dialogContext); load(); }, child: Text(invoiceToEdit == null ? 'حفظ الفاتورة النهائية' : 'حفظ تعديل الفاتورة')),
          ],
        );
      },
    ));
  }

  void _showTablePreview() {
    final visibleInvoices = _filteredInvoices();
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
                      ...visibleInvoices.map((i) => TableRow(children: [
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

  void _showPurchaseInvoicePreview(Map invoice) {
    final key = GlobalKey();
    final items = invoice['items'] as List? ?? const [];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('معاينة فاتورة المشتريات للطباعة'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(18),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Center(child: Text('شركة إدارة المخزون والمبيعات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    Text('رقم الفاتورة: ${invoice['invoiceNumber']}'),
                    Text('التاريخ: ${invoice['date']}'),
                    Text('المورد: ${invoice['supplierName'] ?? 'مورد'}'),
                    const Divider(),
                    ...items.map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${item['productName']} | الكمية: ${item['quantity']} | السعر: ${formatStoredAmount((item['price'] as num).toDouble(), code: invoice['currencyCode']?.toString(), rate: (invoice['exchangeRate'] as num?)?.toDouble())} | الإجمالي: ${formatStoredAmount((item['total'] as num).toDouble(), code: invoice['currencyCode']?.toString(), rate: (invoice['exchangeRate'] as num?)?.toDouble())}'))),
                    const Divider(),
                    Text('مجموع الفاتورة: ${formatStoredAmount((invoice['totalAmount'] as num).toDouble(), code: invoice['currencyCode']?.toString(), rate: (invoice['exchangeRate'] as num?)?.toDouble())}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('الدفعة الواصلة: ${formatStoredAmount((invoice['paidAmount'] as num).toDouble(), code: invoice['currencyCode']?.toString(), rate: (invoice['exchangeRate'] as num?)?.toDouble())}'),
                    Text('الدين المتبقي: ${formatStoredAmount((invoice['remainingDebt'] as num).toDouble(), code: invoice['currencyCode']?.toString(), rate: (invoice['exchangeRate'] as num?)?.toDouble())}', style: const TextStyle(color: Colors.red)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
          ElevatedButton.icon(icon: const Icon(Icons.print), label: const Text('حفظ / طباعة'), onPressed: () async {
            final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
            if (boundary == null) return;
            final image = await boundary.toImage(pixelRatio: 3);
            final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
            final path = await ImageStorageService.saveBytes(bytes: bytes, fileName: 'purchase_${invoice['invoiceNumber']}.png');
            if (dialogContext.mounted) { Navigator.pop(dialogContext); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ الفاتورة في: $path'))); }
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleInvoices = _filteredInvoices();
    final total = visibleInvoices.fold<double>(0, (sum, i) => sum + convertStoredAmount((i['totalAmount'] as num).toDouble(), code: i['currencyCode']?.toString(), rate: (i['exchangeRate'] as num?)?.toDouble()));
    final debt = visibleInvoices.fold<double>(0, (sum, i) => sum + convertStoredAmount((i['remainingDebt'] as num).toDouble(), code: i['currencyCode']?.toString(), rate: (i['exchangeRate'] as num?)?.toDouble()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('المشتريات'),
        actions: [
          TextButton.icon(style: TextButton.styleFrom(foregroundColor: Colors.white), icon: const Icon(Icons.table_chart), label: const Text('معاينة الجدول'), onPressed: _showTablePreview),
          TextButton.icon(style: TextButton.styleFrom(foregroundColor: Colors.white), icon: const Icon(Icons.people), label: const Text('الموردون'), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen())); load(); }),
          IconButton(icon: const Icon(Icons.refresh), onPressed: load),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: createInvoice, child: const Icon(Icons.add)),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: _stat('مجموع المشتريات', total, Colors.blue)), Expanded(child: _stat('الديون', debt, Colors.red)), Expanded(child: _stat('الصافي', total - debt, Colors.orange))])),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'بحث برقم الفاتورة أو اسم المورد...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('يوم محدد'),
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setState(() { _dateFilterType = 'specific'; _specificDate = picked.toIso8601String().split('T').first; _startDate = null; _endDate = null; });
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text('بين تاريخين'),
                  onPressed: () async {
                    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setState(() { _dateFilterType = 'range'; _startDate = picked.start.toIso8601String().split('T').first; _endDate = picked.end.toIso8601String().split('T').first; _specificDate = null; });
                  },
                ),
                if (_dateFilterType != null) TextButton(onPressed: () => setState(() { _dateFilterType = null; _specificDate = null; _startDate = null; _endDate = null; }), child: const Text('إلغاء الفلتر')),
              ],
            ),
          ),
          if (_dateFilterType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _dateFilterType == 'specific' ? 'التاريخ المختار: $_specificDate' : 'الفترة: من $_startDate إلى $_endDate',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9C3FC1)),
                ),
              ),
            ),
          Expanded(
            child: visibleInvoices.isEmpty
                ? const Center(child: Text('لا توجد فواتير مشتريات مطابقة'))
                : ListView.builder(
                    itemCount: visibleInvoices.length,
                    itemBuilder: (context, index) {
                      final invoice = visibleInvoices[index];
                      final code = invoice['currencyCode']?.toString();
                      final rate = (invoice['exchangeRate'] as num?)?.toDouble();
                      return Card(child: ListTile(title: Text('فاتورة ${invoice['invoiceNumber']} | ${invoice['supplierName'] ?? 'مورد'}'), subtitle: Text('${invoice['date']}\nالإجمالي: ${formatStoredAmount((invoice['totalAmount'] as num).toDouble(), code: code, rate: rate)} | الدين: ${formatStoredAmount((invoice['remainingDebt'] as num).toDouble(), code: code, rate: rate)}'), isThreeLine: true, trailing: Wrap(spacing: 0, children: [IconButton(tooltip: 'تعديل الفاتورة', icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => createInvoice(invoiceToEdit: invoice)), IconButton(tooltip: 'معاينة وطباعة', icon: const Icon(Icons.print, color: Colors.green), onPressed: () => _showPurchaseInvoicePreview(invoice)), IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { await DatabaseHelper.instance.deletePurchaseInvoice(invoice['id']); load(); })])));
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, double value, Color color) => Card(child: Padding(padding: const EdgeInsets.all(6), child: Column(children: [Text(label, style: TextStyle(color: color, fontSize: 11)), ValueListenableBuilder(valueListenable: currencySettings, builder: (_, __, ___) => Text(currencySettings.value.format(value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))])));
}
