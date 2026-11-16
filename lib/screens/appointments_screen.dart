import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/database_helper.dart';
import 'barcode_scanner_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List _salesInvoices = [];
  List _users = [];
  List _products = [];
  bool _isLoadingData = false;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  String? _dateFilterType;
  String? _specificDate;
  String? _startDate;
  String? _endDate;

  final GlobalKey _tablePreviewKey = GlobalKey(); // مفتاح الجدول المخصص للمعاينة والطباعة والحفظ كصورة

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoadingData = true);
    try {
      final invoices = await DatabaseHelper.instance.getSalesInvoices();
      final usersList = await DatabaseHelper.instance.getUsers();
      final productsList = await DatabaseHelper.instance.getProducts();

      if (!mounted) return;
      setState(() {
        _salesInvoices = invoices;
        _users = usersList;
        _products = productsList;
        _isLoadingData = false;
      });
    } catch (e) {
      print("خطأ: $e");
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ تعذر تحميل بيانات الفاتورة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // نافذة معاينة تقرير الفواتير والمواعيد في جدول منظم تماماً مثل المنتجات والفاتورة
  void _showTablePreviewDialog() async {
    final prefs = await SharedPreferences.getInstance();
    String appTitle = prefs.getString('app_title') ?? 'شركة إدارة المخزون والمبيعات';

    if (!mounted) return;

    final filteredInvoices = _salesInvoices.where((inv) {
      final userName = (inv['userName'] ?? '').toString().toLowerCase();
      final invNumber = (inv['invoiceNumber'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      bool matchesSearch = userName.contains(query) || invNumber.contains(query);
      bool matchesDate = true;
      String invDate = inv['date'] ?? '';
      if (_dateFilterType == 'specific' && _specificDate != null) {
        matchesDate = invDate == _specificDate;
      } else if (_dateFilterType == 'range' && _startDate != null && _endDate != null) {
        matchesDate = invDate.compareTo(_startDate!) >= 0 && invDate.compareTo(_endDate!) <= 0;
      }
      return matchesSearch && matchesDate;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معاينة تقرير المبيعات والفواتير كجدول للطباعة والحفظ', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 750,
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: _tablePreviewKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ترويسة التقرير الرسمية
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$appTitle 📦', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                        Text('التاريخ: ${DateTime.now().toString().split(' ')[0]}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const Divider(height: 20, thickness: 2),
                    
                    if (_dateFilterType != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _dateFilterType == 'specific' ? '📅 فترة التقرير ليوم: $_specificDate' : '📅 فترة التقرير: من $_startDate إلى $_endDate',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ),

                    const Text('قائمة السجلات والفواتير:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // جدول منظم واحترافي
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade300),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(2.0),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.2),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.teal.shade700),
                          children: const [
                            Padding(padding: EdgeInsets.all(6.0), child: Text('رقم الفاتورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('التاريخ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('اسم العميل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('الإجمالي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('المتبقي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                          ],
                        ),
                        ...filteredInvoices.map((inv) {
                          return TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(6.0), child: Text(inv['invoiceNumber'].toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6.0), child: Text(inv['date'].toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6.0), child: Text(inv['userName'] ?? 'عميل نقدي', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6.0), child: Text(inv['totalAmount'].toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6.0), child: Text(inv['remainingDebt'].toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.red))),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Center(child: Text('شكراً لتعاملكم معنا!', style: TextStyle(fontSize: 11, color: Colors.grey))),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          // زر الحفظ التلقائي في المجلد المحدد بالإعدادات كصورة
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            icon: const Icon(Icons.save_alt),
            label: const Text('حفظ جدول السجلات كصورة'),
            onPressed: () async {
              try {
                await Future.delayed(const Duration(milliseconds: 100));
                RenderRepaintBoundary? boundary = _tablePreviewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                if (boundary == null) return;

                ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                Uint8List pngBytes = byteData!.buffer.asUint8List();

                String targetDir = prefs.getString('save_directory') ?? '/home/${Platform.environment['USER']}/Downloads';
                String savePath = '$targetDir/appointments_table_report_${DateTime.now().millisecondsSinceEpoch}.png';

                await File(savePath).writeAsBytes(pngBytes);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم حفظ جدول السجلات كصورة بنجاح في: $savePath'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                print("خطأ أثناء الحفظ: $e");
              }
            },
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  // معاينة وطباعة الفاتورة الفردية
  void _showPrintInvoiceDialog(Map invoice) {
    GlobalKey printKey = GlobalKey();
    List items = invoice['items'] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معاينة فاتورة المبيعات للطباعة', textAlign: TextAlign.center),
        content: SizedBox(
          width: 600,
          child: RepaintBoundary(
            key: printKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text('📦 شركة إدارة المخزون والمبيعات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  Text('رقم الفاتورة: ${invoice['invoiceNumber']}'),
                  Text('التاريخ: ${invoice['date']}'),
                  Text('العميل: ${invoice['userName'] ?? "عميل نقدي"}'),
                  const Divider(thickness: 2),
                  const Text('المنتجات المباعة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.5),
                    },
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Colors.teal),
                        children: [
                          Padding(padding: EdgeInsets.all(6), child: Text('اسم المنتج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(6), child: Text('الكمية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(6), child: Text('السعر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(6), child: Text('الإجمالي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      ...items.map((item) {
                        return TableRow(
                          children: [
                            Padding(padding: EdgeInsets.all(6), child: Text(item['productName']?.toString() ?? 'منتج')),
                            Padding(padding: EdgeInsets.all(6), child: Text(item['quantity'].toString())),
                            Padding(padding: EdgeInsets.all(6), child: Text('${item['price']}')),
                            Padding(padding: EdgeInsets.all(6), child: Text('${item['total']} ل.س')),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                  const Divider(thickness: 2),
                  Text('إجمالي الفاتورة: ${invoice['totalAmount']} ل.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('الدفعة الواصلة: ${invoice['paidAmount']} ل.س'),
                  Text('الدين المتبقي: ${invoice['remainingDebt']} ل.س', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  const Divider(),
                  const Center(child: Text('شكراً لتعاملكم معنا!', style: TextStyle(fontSize: 12, color: Colors.grey))),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            icon: const Icon(Icons.print),
            label: const Text('حفظ / طباعة الفاتورة كصورة'),
            onPressed: () async {
              try {
                RenderRepaintBoundary boundary = printKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                Uint8List pngBytes = byteData!.buffer.asUint8List();

                final prefs = await SharedPreferences.getInstance();
                String targetDir = prefs.getString('save_directory') ?? '/home/${Platform.environment['USER']}/Downloads';
                String savePath = '$targetDir/invoice_${invoice['invoiceNumber']}.png';

                await File(savePath).writeAsBytes(pngBytes);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم حفظ الفاتورة في: $savePath'), backgroundColor: Colors.green));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ أثناء الطباعة: $e')));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _scanBarcodeWithCamera() async {
    if (Platform.isLinux || Platform.isWindows) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ماسح الكاميرا متاح على الهاتف فقط.')));
      }
      return null;
    }
    return Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
  }

  Future<void> _showAddSalesInvoiceDialog({Map? invoiceToEdit}) async {
    // The page can be displayed before its first async database read finishes.
    // Reload once when the user explicitly asks to add an invoice.
    if (_isLoadingData || _users.isEmpty || _products.isEmpty) {
      await _loadData();
    }

    if (_users.isEmpty || _products.isEmpty) {
      if (!mounted) return;
      final missing = [
        if (_users.isEmpty) 'عميل واحد على الأقل',
        if (_products.isEmpty) 'منتج واحد على الأقل',
      ].join(' و');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('لا يمكن إنشاء الفاتورة'),
          content: Text('يرجى إضافة $missing أولاً، ثم اضغط زر + مرة أخرى.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('حسنًا')),
          ],
        ),
      );
      return;
    }

    final isEditing = invoiceToEdit != null;
    final invoiceNumberCtrl = TextEditingController(text: isEditing ? invoiceToEdit['invoiceNumber'] : 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final invoiceDate = isEditing ? invoiceToEdit['date'] : DateTime.now().toIso8601String().split('T')[0];
    int selectedUserId = isEditing ? invoiceToEdit['userId'] : (_users.first as AppUser).id!;
    
    final barcodeCtrl = TextEditingController();
    Product? selectedProduct;
    final sellingPriceCtrl = TextEditingController();
    final quantityCtrl = TextEditingController(text: '1');
    final paidCtrl = TextEditingController(text: isEditing ? invoiceToEdit['paidAmount'].toString() : '');
    String transactionType = 'sale';

    List invoiceItems = isEditing ? List.from(invoiceToEdit['items'] ?? []) : [];
    bool isPaidManuallyEdited = isEditing;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double totalInvoice = invoiceItems.fold(0.0, (sum, item) => sum + (item['total'] as double));
          
          if (!isPaidManuallyEdited) {
            paidCtrl.text = totalInvoice.toString();
          }

          double paidAmount = double.tryParse(paidCtrl.text) ?? totalInvoice;
          double remainingDebt = totalInvoice - paidAmount;
          if (remainingDebt < 0) remainingDebt = 0;
          final screenWidth = MediaQuery.sizeOf(context).width;
          // Treat tablet-sized windows as compact too; otherwise the product
          // fields become narrow when the dialog is shown in a 900px window.
          final isCompact = screenWidth < 1000;
          final dialogContentWidth = isCompact ? screenWidth * 0.88 - 48 : 850.0;

          void selectProduct(Product? product) {
            setDialogState(() {
              selectedProduct = product;
              if (product == null) return;
              transactionType = product.isForSale ? 'sale' : 'rent';
              sellingPriceCtrl.text = (transactionType == 'rent' ? product.rentalPrice : product.sellingPrice).toString();
              quantityCtrl.text = '1';
            });
          }

          return AlertDialog(
            title: Text(isEditing ? 'تعديل فاتورة مبيعات' : 'إنشاء فاتورة مبيعات جديدة', textDirection: TextDirection.rtl),
            content: SizedBox(
              width: isCompact ? screenWidth * 0.88 : 850,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: dialogContentWidth, child: TextField(controller: invoiceNumberCtrl, decoration: const InputDecoration(labelText: 'رقم الفاتورة', border: OutlineInputBorder()), readOnly: true)),
                        const SizedBox(height: 10),
                        SizedBox(width: dialogContentWidth, child: TextField(controller: TextEditingController(text: invoiceDate), decoration: const InputDecoration(labelText: 'تاريخ الفاتورة', border: OutlineInputBorder()), readOnly: true)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: selectedUserId,
                      items: _users.map((u) {
                        final user = u as AppUser;
                        return DropdownMenuItem<int>(value: user.id, child: Text('${user.name} (${user.code})'));
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedUserId = val!),
                      decoration: const InputDecoration(labelText: 'اختر العميل', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: barcodeCtrl,
                      decoration: InputDecoration(
                        labelText: 'مسح الباركود أو إدخال كود المنتج',
                        prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.teal),
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'بحث بالكود أو الاسم',
                              icon: const Icon(Icons.search, color: Colors.teal),
                              onPressed: () {
                            String codeInput = barcodeCtrl.text.trim().toLowerCase();
                            try {
                              final prod = _products.firstWhere(
                                (p) => (p as Product).code.toLowerCase() == codeInput || (p as Product).name.toLowerCase().contains(codeInput),
                              ) as Product;
                              selectProduct(prod);
                            } catch (_) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ المنتج غير موجود!')));
                            }
                              },
                            ),
                            IconButton(
                              tooltip: 'فتح ماسح الباركود بالكاميرا',
                              icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                              onPressed: () async {
                                final scannedCode = await _scanBarcodeWithCamera();
                                if (scannedCode == null || scannedCode.isEmpty || !context.mounted) return;
                                barcodeCtrl.text = scannedCode;
                                try {
                                  final prod = _products.firstWhere((p) => (p as Product).code.toLowerCase() == scannedCode.toLowerCase()) as Product;
                                  selectProduct(prod);
                                } catch (_) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ تم قراءة الكود، لكنه غير مسجل كمنتج')));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      onSubmitted: (value) {
                        String codeInput = value.trim().toLowerCase();
                        try {
                          final prod = _products.firstWhere(
                            (p) => (p as Product).code.toLowerCase() == codeInput,
                          ) as Product;
                          selectProduct(prod);
                        } catch (_) {}
                      },
                    ),

                    const Divider(height: 30, thickness: 2),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: isCompact ? dialogContentWidth : 300,
                          child: DropdownButtonFormField<Product>(
                            value: selectedProduct,
                            hint: const Text('المنتج المحدد'),
                            isExpanded: true,
                            items: _products.map((p) {
                              final prod = p as Product;
                              return DropdownMenuItem<Product>(value: prod, child: Text('${prod.name} (متوفر: ${prod.quantity})'));
                            }).toList(),
                            onChanged: selectProduct,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                          ),
                        ),
                        if (selectedProduct != null && selectedProduct!.isForSale && selectedProduct!.isForRent)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: DropdownButtonFormField<String>(
                              value: transactionType,
                              items: const [
                                DropdownMenuItem(value: 'sale', child: Text('بيع المنتج')),
                                DropdownMenuItem(value: 'rent', child: Text('إيجار المنتج')),
                              ],
                              onChanged: (value) {
                                if (value == null || selectedProduct == null) return;
                                setDialogState(() {
                                  transactionType = value;
                                  sellingPriceCtrl.text = (value == 'rent' ? selectedProduct!.rentalPrice : selectedProduct!.sellingPrice).toString();
                                });
                              },
                              decoration: const InputDecoration(labelText: 'نوع العملية', border: OutlineInputBorder()),
                            ),
                          ),
                        if (selectedProduct != null && ((!selectedProduct!.isForSale && selectedProduct!.isForRent) || (selectedProduct!.isForSale && !selectedProduct!.isForRent)))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              transactionType == 'rent' ? 'المنتج للإيجار' : 'المنتج للبيع',
                              style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                            ),
                          ),
                        SizedBox(
                          width: isCompact ? dialogContentWidth : 150,
                          child: TextField(
                            controller: sellingPriceCtrl,
                            decoration: InputDecoration(labelText: transactionType == 'rent' ? 'سعر الإيجار' : 'سعر المبيع', border: const OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        SizedBox(
                          width: isCompact ? dialogContentWidth : 120,
                          child: TextField(
                            controller: quantityCtrl,
                            decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        SizedBox(
                          width: isCompact ? dialogContentWidth : 180,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade400)),
                            child: Text(
                              'الإجمالي: ${((double.tryParse(sellingPriceCtrl.text) ?? 0.0) * (int.tryParse(quantityCtrl.text) ?? 1))} ل.س',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: isCompact ? dialogContentWidth : null,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12)),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة المنتج للفاتورة'),
                            onPressed: () {
                            if (selectedProduct != null) {
                              double price = double.tryParse(sellingPriceCtrl.text) ?? 0.0;
                              int qty = int.tryParse(quantityCtrl.text) ?? 1;

                              if (qty > selectedProduct!.quantity && !isEditing) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('❌ خطأ: الكمية المطلوبة أكبر من المتوفر (${selectedProduct!.quantity})'), backgroundColor: Colors.red),
                                );
                                return;
                              }

                              double total = price * qty;

                              setDialogState(() {
                                invoiceItems.add({
                                  'productId': selectedProduct!.id,
                                  'productName': selectedProduct!.name,
                                  'price': price,
                                  'quantity': qty,
                                  'total': total,
                                  'transactionType': transactionType,
                                });
                                selectedProduct = null;
                                transactionType = 'sale';
                                sellingPriceCtrl.clear();
                                quantityCtrl.text = '1';
                                barcodeCtrl.clear();
                              });
                            }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    const Text('المنتجات المضافة للفاتورة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Container(
                      height: 160,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                      child: invoiceItems.isEmpty
                          ? const Center(child: Text('لم يتم إدراج منتجات في الفاتورة بعد'))
                          : ListView.builder(
                              itemCount: invoiceItems.length,
                              itemBuilder: (context, index) {
                                final item = invoiceItems[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                  child: ListTile(
                                    dense: true,
                                    title: Text('${index + 1}. ${item['transactionType'] == 'rent' ? 'إيجار' : 'بيع'}: ${item['productName']} | السعر: ${item['price']} | الكمية: ${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('الإجمالي: ${item['total']} ل.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                        const SizedBox(width: 10),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          onPressed: () {
                                            setDialogState(() {
                                              invoiceItems.removeAt(index);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(child: Text('مجموع الفاتورة: $totalInvoice ل.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: paidCtrl,
                            decoration: const InputDecoration(labelText: 'الدفعة الواصلة', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              setDialogState(() {
                                isPaidManuallyEdited = true;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text('الديون المتبقية: $remainingDebt ل.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () async {
                  if (invoiceItems.isNotEmpty) {
                    if (isEditing) {
                      await DatabaseHelper.instance.deleteSalesInvoice(invoiceToEdit['id']);
                    }

                    String? errorMsg = await DatabaseHelper.instance.insertSalesInvoice({
                      'invoiceNumber': invoiceNumberCtrl.text,
                      'date': invoiceDate,
                      'userId': selectedUserId,
                      'totalAmount': totalInvoice,
                      'paidAmount': paidAmount,
                      'remainingDebt': remainingDebt,
                      'items': invoiceItems,
                    });

                    if (errorMsg != null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
                      }
                    } else {
                      if (context.mounted) Navigator.pop(context);
                      _loadData();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ يرجى إضافة منتج واحد على الأقل للفاتورة')));
                  }
                },
                child: const Text('حفظ الفاتورة النهائية'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = _salesInvoices.where((inv) {
      final userName = (inv['userName'] ?? '').toString().toLowerCase();
      final invNumber = (inv['invoiceNumber'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      bool matchesSearch = userName.contains(query) || invNumber.contains(query);
      bool matchesDate = true;
      String invDate = inv['date'] ?? '';
      if (_dateFilterType == 'specific' && _specificDate != null) {
        matchesDate = invDate == _specificDate;
      } else if (_dateFilterType == 'range' && _startDate != null && _endDate != null) {
        matchesDate = invDate.compareTo(_startDate!) >= 0 && invDate.compareTo(_endDate!) <= 0;
      }

      return matchesSearch && matchesDate;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المبيعات والفواتير'),
        backgroundColor: Colors.teal,
        actions: [
          // زر معاينة الجدول المنظم والمطابق لشاشة المنتجات
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.table_chart),
            label: const Text('معاينة وطباعة جدول'),
            onPressed: _showTablePreviewDialog,
          ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSalesInvoiceDialog(),
        backgroundColor: Colors.teal,
        child: _isLoadingData
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add),
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(labelText: 'بحث برقم الفاتورة أو اسم العميل...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  icon: const Icon(Icons.date_range),
                  label: const Text('يوم محدد'),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2025), lastDate: DateTime(2030));
                    if (picked != null) {
                      setState(() {
                        _dateFilterType = 'specific';
                        _specificDate = picked.toIso8601String().split('T')[0];
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  icon: const Icon(Icons.date_range),
                  label: const Text('بين تاريخين'),
                  onPressed: () async {
                    DateTimeRange? picked = await showDateRangePicker(context: context, firstDate: DateTime(2025), lastDate: DateTime(2030));
                    if (picked != null) {
                      setState(() {
                        _dateFilterType = 'range';
                        _startDate = picked.start.toIso8601String().split('T')[0];
                        _endDate = picked.end.toIso8601String().split('T')[0];
                      });
                    }
                  },
                ),
                if (_dateFilterType != null)
                  TextButton(onPressed: () => setState(() { _dateFilterType = null; _specificDate = null; _startDate = null; _endDate = null; }), child: const Text('إلغاء')),
              ],
            ),
            if (_dateFilterType != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.teal.shade200)),
                child: Text(
                  _dateFilterType == 'specific' ? '📅 التاريخ المختار: $_specificDate' : '📅 الفترة المختارة: من $_startDate إلى $_endDate',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                  textAlign: TextAlign.right,
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredInvoices.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد فواتير مبيعات مطابقة')))
                  : ListView.builder(
                      itemCount: filteredInvoices.length,
                      itemBuilder: (context, index) {
                        final inv = filteredInvoices[index];
                        List items = inv['items'] ?? [];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
                          child: ListTile(
                            title: Text('فاتورة رقم: ${inv['invoiceNumber']} | العميل: ${inv['userName'] ?? "عميل نقدي"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('التاريخ: ${inv['date']} | الإجمالي: ${inv['totalAmount']} ل.س\nالدفعة: ${inv['paidAmount']} ل.س | الدين المتبقي: ${inv['remainingDebt']} ل.س'),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.print, color: Colors.green),
                                  tooltip: 'معاينة وطباعة الفاتورة',
                                  onPressed: () => _showPrintInvoiceDialog(inv),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'تعديل الفاتورة',
                                  onPressed: () => _showAddSalesInvoiceDialog(invoiceToEdit: inv),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'حذف الفاتورة',
                                  onPressed: () async {
                                    await DatabaseHelper.instance.deleteSalesInvoice(inv['id']);
                                    _loadData();
                                  },
                                ),
                              ],
                            ),
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
}
