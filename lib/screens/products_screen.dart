import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/database_helper.dart';
import '../services/barcode_image_service.dart';
import '../services/image_storage_service.dart';
import 'categories_screen.dart';
import 'barcode_scanner_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List _productsWithCat = [];
  List<Category> _categories = [];
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey _tablePreviewKey = GlobalKey(); // مفتاح الجدول المخصص للمعاينة والحفظ

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final categoriesList = await DatabaseHelper.instance.getCategories();
      final prodWithCat = await DatabaseHelper.instance.getProductsWithCategory();

      setState(() {
        _categories = categoriesList;
        _productsWithCat = prodWithCat;
      });
    } catch (e) {
      print("خطأ في التحميل: $e");
    }
  }

  // تكبير صورة المنتج عند الضغط عليها
  void _showImageZoomDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: 400,
          height: 400,
          child: InteractiveViewer(
            child: Image.file(File(imagePath), fit: BoxFit.contain),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  // نافذة معاينة تقرير المنتجات في جدول منظم (نفس مبدأ معاينة الفاتورة قبل الطباعة والحفظ)
  void _showTablePreviewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معاينة تقرير المنتجات كجدول للطباعة والحفظ', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 700,
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
                    // ترويسة التقرير الرسمية مثل الفاتورة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('شركة إدارة المخزون والمبيعات 📦', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                        Text('التاريخ: ${DateTime.now().toString().split(' ')[0]}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const Divider(height: 20, thickness: 2),
                    const Text('قائمة المنتجات المخزنة:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    // جدول منظم واحترافي تماماً مثل الفاتورة
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade300),
                      columnWidths: const {
                        0: FlexColumnWidth(1.0),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.5),
                      },
                      children: [
                        // ترويسة الجدول
                        TableRow(
                          decoration: BoxDecoration(color: Colors.teal.shade700),
                          children: const [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('الصورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('اسم المنتج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('التصنيف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('الكمية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('سعر المبيع (ل.س)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          ],
                        ),
                        // محتوى الجدول مع عرض صور المنتجات المصغرة
                        ..._productsWithCat.map((prod) {
                          String? img = prod['imagePath'];
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Center(
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: img != null && File(img).existsSync()
                                        ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(File(img), fit: BoxFit.cover))
                                        : const Icon(Icons.inventory_2, size: 20, color: Colors.teal),
                                  ),
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(prod['name'] ?? '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(prod['categoryName'] ?? 'بدون', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(prod['quantity'].toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(prod['sellingPrice'].toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
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
          // زر حفظ الجدول كصورة تلقائياً بنفس مبدأ الفاتورة
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            icon: const Icon(Icons.save_alt),
            label: const Text('حفظ / طباعة الجدول كصورة'),
            onPressed: () async {
              try {
                await Future.delayed(const Duration(milliseconds: 100));
                RenderRepaintBoundary? boundary = _tablePreviewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                if (boundary == null) return;

                ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                Uint8List pngBytes = byteData!.buffer.asUint8List();

                final prefs = await SharedPreferences.getInstance();
                final configuredDirectory = prefs.getString('save_directory');
                final directory = Directory(configuredDirectory ?? '/home/${Platform.environment['USER']}/Downloads');
                await directory.create(recursive: true);
                String savePath = '${directory.path}/products_table_report_${DateTime.now().millisecondsSinceEpoch}.png';

                await File(savePath).writeAsBytes(pngBytes);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم حفظ جدول التقرير كصورة بنجاح في: $savePath'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                print("خطأ في الحفظ: $e");
              }
            },
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  // نافذة معاينة وتكبير الباركود
  void _showBarcodePreviewDialog(String productName, String productCode, String? barcodeImgPath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(productName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8), color: Colors.white),
              child: barcodeImgPath != null && File(barcodeImgPath).existsSync()
                  ? InteractiveViewer(child: Image.file(File(barcodeImgPath), fit: BoxFit.contain))
                  : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.qr_code_2, size: 80, color: Colors.black87), Text('باركود افتراضي', style: TextStyle(fontSize: 12, color: Colors.grey))]),
            ),
            const SizedBox(height: 12),
            Text(productCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
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

  Future<String?> _readBarcodeFromImage(String path) async {
    if (Platform.isLinux || Platform.isWindows) return null;
    final controller = MobileScannerController(autoStart: false);
    try {
      final capture = await controller.analyzeImage(path);
      final values = capture?.barcodes
          .map((barcode) => barcode.rawValue?.trim())
          .whereType<String>()
          .toList() ?? <String>[];
      return values.isEmpty ? null : values.first;
    } finally {
      await controller.dispose();
    }
  }

  // نافذة إضافة أو تعديل منتج
  Future<void> _showProductDialog({Product? productToEdit}) async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ يجب إضافة تصنيفات أولاً!')));
      return;
    }

    final isEditing = productToEdit != null;
    final dialogWidth = MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * 0.88 : 580.0;
    final barcodeCtrl = TextEditingController(text: isEditing ? productToEdit.code : 'BC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}');
    final nameCtrl = TextEditingController(text: isEditing ? productToEdit.name : '');
    final quantityCtrl = TextEditingController(text: isEditing ? productToEdit.quantity.toString() : '1');
    final purchasePriceCtrl = TextEditingController(text: isEditing ? productToEdit.purchasePrice.toString() : '0.0');
    final sellingPriceCtrl = TextEditingController(text: isEditing ? productToEdit.sellingPrice.toString() : '0.0');
    final rentalPriceCtrl = TextEditingController(text: isEditing ? productToEdit.rentalPrice.toString() : '0.0');
    
    int selectedCategoryId = isEditing ? productToEdit.categoryId : _categories.first.id!;
    String selectedStatus = isEditing ? productToEdit.status : 'متوفر';
    bool isForSale = isEditing ? productToEdit.isForSale : true;
    bool isForRent = isEditing ? productToEdit.isForRent : false;
    String? productImagePath = isEditing ? productToEdit.imagePath : null;
    String? barcodeImagePath = isEditing ? productToEdit.barcodeImagePath : null;

    if (!isEditing) {
      try {
        barcodeImagePath = await BarcodeImageService.generateQrImage(
          code: barcodeCtrl.text.trim(),
          prefix: 'barcode_${barcodeCtrl.text.trim()}',
        );
      } catch (_) {
        // The required save directory may not be configured yet. The image
        // will be generated again when the user presses Save.
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
            title: Text(isEditing ? 'تعديل منتج' : 'إضافة منتج جديد', textDirection: TextDirection.rtl),
            content: SizedBox(
              width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(6)),
                        child: productImagePath != null && File(productImagePath!).existsSync()
                            ? Image.file(File(productImagePath!), fit: BoxFit.cover)
                            : const Icon(Icons.image, color: Colors.grey, size: 30),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[50], foregroundColor: Colors.teal[800]),
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('اختيار صورة المنتج', style: TextStyle(fontSize: 11)),
                          onPressed: () async {
                            FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
                            if (res != null && res.files.single.path != null) {
                              setDialogState(() => productImagePath = res.files.single.path);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(border: Border.all(color: Colors.teal), borderRadius: BorderRadius.circular(6), color: Colors.white),
                        child: barcodeImagePath != null && File(barcodeImagePath!).existsSync()
                            ? Image.file(File(barcodeImagePath!), fit: BoxFit.cover)
                            : const Icon(Icons.qr_code, color: Colors.teal, size: 28),
                      ),
                      Expanded(
                        child: TextField(
                          controller: barcodeCtrl,
                          decoration: const InputDecoration(labelText: 'كود الباركود', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.folder_open, color: Colors.teal),
                        tooltip: 'تحميل باركود من الملفات',
                        onPressed: () async {
                          FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
                          if (res != null && res.files.single.path != null) {
                            final selectedPath = res.files.single.path!;
                            setDialogState(() => barcodeImagePath = selectedPath);
                            try {
                              final decodedCode = await _readBarcodeFromImage(selectedPath);
                              if (decodedCode != null && decodedCode.isNotEmpty) {
                                setDialogState(() => barcodeCtrl.text = decodedCode);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم قراءة الكود وتحديث صورة الباركود')));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ تم اختيار الصورة، لكن تعذر قراءة الكود منها')));
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ تم اختيار الصورة دون قراءة الكود: $e')));
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                        tooltip: 'مسح الباركود',
                        onPressed: () async {
                          final scannedCode = await _scanBarcodeWithCamera();
                          if (scannedCode != null && scannedCode.isNotEmpty) {
                            String? generatedImage;
                            try {
                              generatedImage = await BarcodeImageService.generateQrImage(
                                code: scannedCode,
                                prefix: 'barcode_$scannedCode',
                              );
                            } catch (_) {}
                            setDialogState(() {
                              barcodeCtrl.text = scannedCode;
                              barcodeImagePath = generatedImage;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: selectedCategoryId,
                    items: _categories.map((cat) => DropdownMenuItem<int>(value: cat.id, child: Text(cat.name))).toList(),
                    onChanged: (val) => setDialogState(() => selectedCategoryId = val!),
                    decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('المنتج للبيع'),
                    subtitle: const Text('عند إلغاء التفعيل لا يمكن تعديل الكمية والحالة وأسعار الشراء والمبيع'),
                    value: isForSale,
                    onChanged: (value) => setDialogState(() => isForSale = value ?? false),
                    activeColor: Colors.teal,
                  ),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: quantityCtrl, enabled: isForSale, decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedStatus,
                          items: ['متوفر', 'نفد المخزون', 'موقوف'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: isForSale ? (val) => setDialogState(() => selectedStatus = val!) : null,
                          decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: purchasePriceCtrl, enabled: isForSale, decoration: const InputDecoration(labelText: 'سعر الشراء', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: sellingPriceCtrl, enabled: isForSale, decoration: const InputDecoration(labelText: 'سعر المبيع', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('المنتج للإيجار'),
                    value: isForRent,
                    onChanged: (value) => setDialogState(() => isForRent = value ?? false),
                    activeColor: Colors.teal,
                  ),
                  if (isForRent)
                    TextField(
                      controller: rentalPriceCtrl,
                      decoration: const InputDecoration(labelText: 'سعر الإيجار', border: OutlineInputBorder(), prefixIcon: Icon(Icons.home_work_outlined)),
                      keyboardType: TextInputType.number,
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
                if (barcodeCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ يرجى إدخال الكود والاسم')));
                  return;
                }
                if (!isForSale && !isForRent) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ يجب تفعيل البيع أو الإيجار على الأقل')));
                  return;
                }

                String? permanentProductImage;
                String? permanentBarcodeImage;
                try {
                  permanentProductImage = await ImageStorageService.copyToConfiguredDirectory(
                    sourcePath: productImagePath,
                    prefix: 'product_${barcodeCtrl.text.trim()}',
                  );
                  permanentBarcodeImage = barcodeImagePath == null
                      ? await BarcodeImageService.generateQrImage(
                          code: barcodeCtrl.text.trim(),
                          prefix: 'barcode_${barcodeCtrl.text.trim()}',
                        )
                      : await ImageStorageService.copyToConfiguredDirectory(
                          sourcePath: barcodeImagePath,
                          prefix: 'barcode_${barcodeCtrl.text.trim()}',
                        );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ تعذر حفظ الصور في مجلد الإعدادات: $e'), backgroundColor: Colors.red),
                    );
                  }
                  return;
                }

                final product = Product(
                  id: isEditing ? productToEdit.id : null,
                  code: barcodeCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  categoryId: selectedCategoryId,
                  imagePath: permanentProductImage ?? productImagePath,
                  barcodeImagePath: permanentBarcodeImage ?? barcodeImagePath,
                  status: selectedStatus,
                  quantity: int.tryParse(quantityCtrl.text) ?? 1,
                  purchasePrice: double.tryParse(purchasePriceCtrl.text) ?? 0.0,
                  sellingPrice: double.tryParse(sellingPriceCtrl.text) ?? 0.0,
                  isForSale: isForSale,
                  isForRent: isForRent,
                  rentalPrice: double.tryParse(rentalPriceCtrl.text) ?? 0.0,
                );

                if (isEditing) {
                  await DatabaseHelper.instance.updateProduct(product);
                } else {
                  await DatabaseHelper.instance.insertProduct(product);
                }

                if (context.mounted) Navigator.pop(context);
                _loadData();
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _productsWithCat.where((prod) {
      final name = (prod['name'] ?? '').toString().toLowerCase();
      final code = (prod['code'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات والمخزون'),
        backgroundColor: Colors.teal,
        actions: [
          // زر فتح معاينة جدول التقرير المنظم تماماً مثل الفاتورة
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.table_chart),
            label: const Text('معاينة وطباعة جدول'),
            onPressed: _showTablePreviewDialog,
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.category),
            label: const Text('إدارة التصنيفات'),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const CategoriesScreen()));
              _loadData();
            },
          ),
          const SizedBox(width: 10),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'بحث بالاسم أو الكود...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredProducts.isEmpty
                  ? const Center(child: Text('لا توجد منتجات مسجلة'))
                      : ListView.builder(
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                        final prodMap = filteredProducts[index];
                        String? img = prodMap['imagePath'];
                        String? barcodeImg = prodMap['barcodeImagePath'];
                        String name = prodMap['name'] ?? 'منتج';
                        String code = prodMap['code'] ?? '';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (img != null && File(img).existsSync()) _showImageZoomDialog(img);
                                  },
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)),
                                    child: img != null && File(img).existsSync()
                                        ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(File(img), fit: BoxFit.cover))
                                        : const Icon(Icons.inventory_2, color: Colors.teal, size: 22),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _showBarcodePreviewDialog(name, code, barcodeImg),
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.teal.shade300), color: Colors.teal.shade50),
                                    child: barcodeImg != null && File(barcodeImg).existsSync()
                                        ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(File(barcodeImg), fit: BoxFit.cover))
                                        : const Icon(Icons.qr_code, color: Colors.teal, size: 22),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '$name  •  كود: $code  •  التصنيف: ${prodMap['categoryName'] ?? "بدون"}  •  الكمية: ${prodMap['quantity']}  •  سعر المبيع: ${prodMap['sellingPrice']} ل.س',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.rtl,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'تعديل',
                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 21),
                                  onPressed: () => _showProductDialog(productToEdit: Product.fromMap(Map<String, dynamic>.from(prodMap))),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'حذف',
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 21),
                                  onPressed: () async {
                                    await DatabaseHelper.instance.deleteProduct(prodMap['id']);
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
