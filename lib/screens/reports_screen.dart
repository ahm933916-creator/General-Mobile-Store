import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import '../services/image_storage_service.dart';
import '../currency_controller.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List _salesInvoices = [];
  List _expenses = [];
  
  String? _dateFilterType;
  String? _specificDate;
  String? _startDate;
  String? _endDate;

  final GlobalKey _tablePreviewKey = GlobalKey(); // مفتاح الجدول المخصص للمعاينة والطباعة والحفظ كصورة

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  void _loadReportData() async {
    try {
      final invoices = await DatabaseHelper.instance.getSalesInvoices();
      final expensesList = await DatabaseHelper.instance.getExpenses();
      setState(() {
        _salesInvoices = invoices;
        _expenses = expensesList;
      });
    } catch (e) {
      print("خطأ في تحميل التقارير: $e");
    }
  }

  // نافذة معاينة التقرير المالي الشامل في جدول منظم (نفس مبدأ المنتجات والفاتورة)
  void _showTablePreviewDialog() async {
    final prefs = await SharedPreferences.getInstance();
    String appTitle = prefs.getString('app_title') ?? 'شركة إدارة المخزون والمبيعات';

    if (!mounted) return;

    // حساب البيانات المفلترة لتظهر داخل جدول المعاينة
    final filteredInvoices = _salesInvoices.where((inv) {
      bool matchesDate = true;
      String invDate = inv['date'] ?? '';
      
      if (_dateFilterType == 'specific' && _specificDate != null) {
        matchesDate = invDate == _specificDate;
      } else if (_dateFilterType == 'range' && _startDate != null && _endDate != null) {
        matchesDate = invDate.compareTo(_startDate!) >= 0 && invDate.compareTo(_endDate!) <= 0;
      }
      return matchesDate;
    }).toList();

    final filteredExpenses = _expenses.where((exp) {
      bool matchesDate = true;
      String expDate = exp.date;
      if (_dateFilterType == 'specific' && _specificDate != null) {
        matchesDate = expDate == _specificDate;
      } else if (_dateFilterType == 'range' && _startDate != null && _endDate != null) {
        matchesDate = expDate.compareTo(_startDate!) >= 0 && expDate.compareTo(_endDate!) <= 0;
      }
      return matchesDate;
    }).toList();

    double totalSales = filteredInvoices.fold(0.0, (sum, inv) => sum + convertStoredAmount((inv['totalAmount'] as num).toDouble(), code: inv['currencyCode']?.toString(), rate: (inv['exchangeRate'] as num?)?.toDouble()));
    double totalPaid = filteredInvoices.fold(0.0, (sum, inv) => sum + convertStoredAmount((inv['paidAmount'] as num).toDouble(), code: inv['currencyCode']?.toString(), rate: (inv['exchangeRate'] as num?)?.toDouble()));
    double totalDebt = filteredInvoices.fold(0.0, (sum, inv) => sum + convertStoredAmount((inv['remainingDebt'] as num).toDouble(), code: inv['currencyCode']?.toString(), rate: (inv['exchangeRate'] as num?)?.toDouble()));
    double totalExpenses = filteredExpenses.fold(0.0, (sum, exp) => sum + convertStoredAmount(exp.cost, code: exp.currencyCode, rate: exp.exchangeRate));
    double treasuryBalance = totalPaid - totalExpenses;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معاينة التقرير المالي كجدول للطباعة والحفظ', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.94,
          height: MediaQuery.sizeOf(context).height * 0.72,
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 4,
                      children: [
                        Text('$appTitle 📦', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF9C3FC1))),
                        Text('التاريخ: ${DateTime.now().toString().split(' ')[0]}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const Divider(height: 20, thickness: 2),
                    
                    if (_dateFilterType != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _dateFilterType == 'specific' ? '📅 فترة التقرير ليوم: $_specificDate' : '📅 فترة التقرير: من $_startDate إلى $_endDate',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF9C3FC1)),
                        ),
                      ),

                    const Text('الملخص المالي الشامل:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // جدول الملخص المالي
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 620,
                        child: Table(
                      border: TableBorder.all(color: Colors.grey.shade300),
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: const Color(0xFF7B2FA0)),
                          children: const [
                            Padding(padding: EdgeInsets.all(6.0), child: Text('المبيعات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('الوااصل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('الديون', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('المصروفات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('الخزنة (الصافي)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(padding: EdgeInsets.all(6.0), child: Text('$totalSales', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('$totalPaid', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('$totalDebt', style: const TextStyle(fontSize: 11, color: Colors.orange), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('$totalExpenses', style: const TextStyle(fontSize: 11, color: Colors.red), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('$treasuryBalance', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple), textAlign: TextAlign.center)),
                          ],
                        ),
                      ],
                        ),
                      ),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C3FC1), foregroundColor: Colors.white),
            icon: const Icon(Icons.save_alt),
            label: const Text('حفظ جدول التقرير كصورة'),
            onPressed: () async {
              try {
                await Future.delayed(const Duration(milliseconds: 100));
                RenderRepaintBoundary? boundary = _tablePreviewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                if (boundary == null) return;

                ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                Uint8List pngBytes = byteData!.buffer.asUint8List();

                final savePath = await ImageStorageService.saveBytes(
                  bytes: pngBytes,
                  fileName: 'financial_report_table_${DateTime.now().millisecondsSinceEpoch}.png',
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم حفظ جدول التقرير كصورة بنجاح في: $savePath'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ تعذر الحفظ في المجلد الخارجي المختار: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = _salesInvoices.where((inv) {
      bool matchesDate = true;
      String invDate = inv['date'] ?? '';
      
      if (_dateFilterType == 'specific' && _specificDate != null) {
        matchesDate = invDate == _specificDate;
      } else if (_dateFilterType == 'range' && _startDate != null && _endDate != null) {
        matchesDate = invDate.compareTo(_startDate!) >= 0 && invDate.compareTo(_endDate!) <= 0;
      }
      return matchesDate;
    }).toList();

    final filteredExpenses = _expenses.where((exp) {
      bool matchesDate = true;
      String expDate = exp.date;
      if (_dateFilterType == 'specific' && _specificDate != null) {
        matchesDate = expDate == _specificDate;
      } else if (_dateFilterType == 'range' && _startDate != null && _endDate != null) {
        matchesDate = expDate.compareTo(_startDate!) >= 0 && expDate.compareTo(_endDate!) <= 0;
      }
      return matchesDate;
    }).toList();

    double totalSales = filteredInvoices.fold(0.0, (sum, inv) => sum + convertStoredAmount((inv['totalAmount'] as num).toDouble(), code: inv['currencyCode']?.toString(), rate: (inv['exchangeRate'] as num?)?.toDouble()));
    double totalPaid = filteredInvoices.fold(0.0, (sum, inv) => sum + convertStoredAmount((inv['paidAmount'] as num).toDouble(), code: inv['currencyCode']?.toString(), rate: (inv['exchangeRate'] as num?)?.toDouble()));
    double totalDebt = filteredInvoices.fold(0.0, (sum, inv) => sum + convertStoredAmount((inv['remainingDebt'] as num).toDouble(), code: inv['currencyCode']?.toString(), rate: (inv['exchangeRate'] as num?)?.toDouble()));
    double totalExpenses = filteredExpenses.fold(0.0, (sum, exp) => sum + convertStoredAmount(exp.cost, code: exp.currencyCode, rate: exp.exchangeRate));
    double treasuryBalance = totalPaid - totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير المبيعات والأرباح والخزنة'),
        backgroundColor: const Color(0xFF9C3FC1),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات',
            onPressed: _loadReportData,
          ),
          // زر فتح معاينة جدول التقرير المنظم تماماً مثل المنتجات
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.table_chart),
            label: const Text('معاينة وطباعة جدول'),
            onPressed: _showTablePreviewDialog,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C3FC1), foregroundColor: Colors.white),
                  icon: const Icon(Icons.date_range),
                  label: const Text('يوم محدد'),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
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
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C3FC1), foregroundColor: Colors.white),
                  icon: const Icon(Icons.date_range),
                  label: const Text('بين تاريخين'),
                  onPressed: () async {
                    DateTimeRange? picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
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
                  TextButton(
                    onPressed: () => setState(() {
                      _dateFilterType = null;
                      _specificDate = null;
                      _startDate = null;
                      _endDate = null;
                    }),
                    child: const Text('إلغاء الفلتر'),
                  ),
              ],
            ),
            if (_dateFilterType != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: const Color(0xFF2D465B), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF617C93))),
                child: Text(
                  _dateFilterType == 'specific' ? '📅 التقرير ليوم: $_specificDate' : '📅 التقرير للفترة: من $_startDate إلى $_endDate',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF9C3FC1)),
                  textAlign: TextAlign.right,
                ),
              ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(child: _buildSummaryCard('إجمالي المبيعات', '$totalSales ل.س', Colors.blue)),
                const SizedBox(width: 6),
                Expanded(child: _buildSummaryCard('الدفعة الواصلة', '$totalPaid ل.س', Colors.green)),
                const SizedBox(width: 6),
                Expanded(child: _buildSummaryCard('الديون المتبقية', '$totalDebt ل.س', Colors.orange)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildSummaryCard('المصروفات', '$totalExpenses ل.س', Colors.redAccent)),
                const SizedBox(width: 6),
                Expanded(child: _buildSummaryCard('الخزنة (الصافي)', '$treasuryBalance ل.س', Colors.purple)),
              ],
            ),
            const Divider(height: 25, thickness: 2),
            const Center(
              child: Text('يتم احتساب المبيعات والأرباح والخزنة من الفواتير المحفوظة دون عرض سجل الفواتير هنا.'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}
