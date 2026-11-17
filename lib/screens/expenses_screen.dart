import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/database_helper.dart';
import '../services/image_storage_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List _expenses = [];
  List _expenseTypes = [];
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterType;
  String? _dateFilterType;
  String? _specificDate;
  String? _startDate;
  String? _endDate;

  final GlobalKey _tablePreviewKey = GlobalKey(); // مفتاح الجدول المنظم للمعاينة والحفظ كصورة

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final expensesList = await DatabaseHelper.instance.getExpenses();
    final typesList = await DatabaseHelper.instance.getExpenseTypes();
    setState(() {
      _expenses = expensesList;
      _expenseTypes = typesList;
    });
  }

  // نافذة معاينة تقرير المصروفات في جدول منظم تماماً مثل المنتجات والفاتورة
  void _showTablePreviewDialog() async {
    final prefs = await SharedPreferences.getInstance();
    String appTitle = prefs.getString('app_title') ?? 'شركة إدارة المخزون والمبيعات';

    if (!mounted) return;

    final filteredExpenses = _expenses.where((exp) {
      final query = _searchQuery.toLowerCase();
      bool matchesSearch = exp.type.toLowerCase().contains(query) || exp.date.contains(query) || exp.cost.toString().contains(query);
      bool matchesType = _filterType == null || exp.type == _filterType;

      bool matchesDate = true;
      if (_dateFilterType == 'specific' && _specificDate != null) {
        matchesDate = exp.date == _specificDate;
      } else if (_dateFilterType == 'range' && _startDate != null && _endDate != null) {
        matchesDate = exp.date.compareTo(_startDate!) >= 0 && exp.date.compareTo(_endDate!) <= 0;
      }

      return matchesSearch && matchesType && matchesDate;
    }).toList();

    double totalExpenses = filteredExpenses.fold(0.0, (sum, exp) => sum + exp.cost);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معاينة تقرير المصروفات كجدول للطباعة والحفظ', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

                    const Text('سجل المصروفات والمدفوعات:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // جدول منظم واحترافي
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 620,
                        child: Table(
                      border: TableBorder.all(color: Colors.grey.shade300),
                      columnWidths: const {
                        0: FlexColumnWidth(2.0),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.5),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.teal.shade700),
                          children: const [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('نوع المصروف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('التاريخ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('التكلفة (ل.س)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          ],
                        ),
                        ...filteredExpenses.map((exp) {
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(exp.type, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(exp.date, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(exp.cost.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                            ],
                          );
                        }),
                      ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text('إجمالي المصروفات: $totalExpenses ل.س', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 20),
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
            label: const Text('حفظ جدول المصروفات كصورة'),
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
                  fileName: 'expenses_table_report_${DateTime.now().millisecondsSinceEpoch}.png',
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم حفظ جدول المصروفات كصورة بنجاح في: $savePath'), backgroundColor: Colors.green),
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

  void _showAddExpenseTypeDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة نوع مصروف جديد', textDirection: TextDirection.rtl),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم النوع')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await DatabaseHelper.instance.insertExpenseType(nameCtrl.text.trim());
                if (context.mounted) Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddEditExpenseDialog({Expense? expenseToEdit}) {
    if (_expenseTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إضافة نوع مصروف من الزر العلوي أولاً!')));
      return;
    }

    final isEditing = expenseToEdit != null;
    String selectedType = isEditing ? expenseToEdit.type : (_expenseTypes.first as ExpenseType).name;
    final costCtrl = TextEditingController(text: isEditing ? expenseToEdit.cost.toString() : '');
    String selectedDate = isEditing ? expenseToEdit.date : DateTime.now().toIso8601String().split('T')[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'تعديل المصروف' : 'إضافة مصروف جديد', textDirection: TextDirection.rtl),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: _expenseTypes.map((t) {
                    final typeObj = t as ExpenseType;
                    return DropdownMenuItem(value: typeObj.name, child: Text(typeObj.name));
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                  decoration: const InputDecoration(labelText: 'نوع المصروف'),
                ),
                const SizedBox(height: 10),
                TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text('التاريخ: $selectedDate')),
                    TextButton(
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.parse(selectedDate), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (picked != null) setDialogState(() => selectedDate = picked.toIso8601String().split('T')[0]);
                      },
                      child: const Text('تغيير التاريخ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (costCtrl.text.trim().isNotEmpty) {
                  if (isEditing) {
                    await DatabaseHelper.instance.updateExpense(Expense(id: expenseToEdit.id, type: selectedType, date: selectedDate, cost: double.tryParse(costCtrl.text.trim()) ?? 0.0));
                  } else {
                    await DatabaseHelper.instance.insertExpense(Expense(type: selectedType, date: selectedDate, cost: double.tryParse(costCtrl.text.trim()) ?? 0.0));
                  }
                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                }
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
    final filteredExpenses = _expenses.where((exp) {
      final query = _searchQuery.toLowerCase();
      bool matchesSearch = exp.type.toLowerCase().contains(query) || exp.date.contains(query) || exp.cost.toString().contains(query);
      bool matchesType = _filterType == null || exp.type == _filterType;

      bool matchesDate = true;
      if (_dateFilterType == 'specific' && _specificDate != null) {
        matchesDate = exp.date == _specificDate;
      } else if (_dateFilterType == 'range' && _startDate != null && _endDate != null) {
        matchesDate = exp.date.compareTo(_startDate!) >= 0 && exp.date.compareTo(_endDate!) <= 0;
      }

      return matchesSearch && matchesType && matchesDate;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المصروفات'),
        backgroundColor: Colors.teal,
        actions: [
          // زر معاينة الجدول المنظم والمطابق لشاشة المنتجات
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.table_chart),
            label: const Text('معاينة وطباعة جدول'),
            onPressed: _showTablePreviewDialog,
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.add_box),
            label: const Text('نوع مصروف'),
            onPressed: _showAddExpenseTypeDialog,
          ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditExpenseDialog(),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(labelText: 'بحث عام...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _filterType,
                    hint: const Text('نوع المصروف'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('كل الأنواع')),
                      ..._expenseTypes.map((t) => DropdownMenuItem(value: (t as ExpenseType).name, child: Text(t.name))),
                    ],
                    onChanged: (val) => setState(() => _filterType = val),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text('يوم محدد'),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (picked != null) {
                      setState(() {
                        _dateFilterType = 'specific';
                        _specificDate = picked.toIso8601String().split('T')[0];
                        _startDate = null;
                        _endDate = null;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text('بين تاريخين'),
                  onPressed: () async {
                    DateTimeRange? picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (picked != null) {
                      setState(() {
                        _dateFilterType = 'range';
                        _startDate = picked.start.toIso8601String().split('T')[0];
                        _endDate = picked.end.toIso8601String().split('T')[0];
                        _specificDate = null;
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
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Text(
                  _dateFilterType == 'specific'
                      ? '📅 التاريخ المختار: $_specificDate'
                      : '📅 الفترة المختارة: من $_startDate إلى $_endDate',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                  textAlign: TextAlign.right,
                ),
              ),
            const SizedBox(height: 10),
            filteredExpenses.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد مصروفات مطابقة')))
                : Column(
                    children: filteredExpenses.map((exp) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
                        child: ListTile(
                          title: Text('${exp.type} - ${exp.cost} ل.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('التاريخ: ${exp.date}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddEditExpenseDialog(expenseToEdit: exp)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                                if (exp.id != null) {
                                  await DatabaseHelper.instance.deleteExpense(exp.id!);
                                  _loadData();
                                }
                              }),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}
