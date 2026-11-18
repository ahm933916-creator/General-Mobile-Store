import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/database_helper.dart';
import '../services/image_storage_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AppUser> _users = [];
  Map<int, double> _userDebts = {};
  final GlobalKey _tablePreviewKey = GlobalKey(); // مفتاح الجدول المخصص للمعاينة والحفظ كصورة

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() async {
    final users = await DatabaseHelper.instance.getUsers();
    Map<int, double> debts = {};
    for (var user in users) {
      if (user.id != null) {
        debts[user.id!] = await DatabaseHelper.instance.getUserTotalDebt(user.id!);
      }
    }
    setState(() {
      _users = users;
      _userDebts = debts;
    });
  }

  // نافذة معاينة تقرير العملاء في جدول منظم تماماً مثل المنتجات والفاتورة
  void _showTablePreviewDialog() async {
    final prefs = await SharedPreferences.getInstance();
    String appTitle = prefs.getString('app_title') ?? 'شركة إدارة المخزون والمبيعات';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معاينة تقرير العملاء كجدول للطباعة والحفظ', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                    const Text('قائمة العملاء والمستخدمين:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    // جدول منظم واحترافي
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 620,
                        child: Table(
                      border: TableBorder.all(color: Colors.grey.shade300),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(2.0),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.5),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: const Color(0xFF7B2FA0)),
                          children: const [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('الكود', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('اسم العميل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('الهاتف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('إجمالي الديون (ل.س)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          ],
                        ),
                        ..._users.map((user) {
                          double debt = _userDebts[user.id] ?? 0.0;
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(user.code, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(user.name, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(user.phone, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(debt.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold))),
                            ],
                          );
                        }),
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
          // زر الحفظ التلقائي في المجلد المحدد بالإعدادات
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C3FC1), foregroundColor: Colors.white),
            icon: const Icon(Icons.save_alt),
            label: const Text('حفظ جدول العملاء كصورة'),
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
                  fileName: 'users_table_report_${DateTime.now().millisecondsSinceEpoch}.png',
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم حفظ جدول العملاء كصورة بنجاح في: $savePath'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                print("خطأ أثناء حفظ الصورة: $e");
              }
            },
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _showUserDialog({AppUser? userToEdit}) {
    final isEditing = userToEdit != null;
    final codeCtrl = TextEditingController(text: isEditing ? userToEdit.code : 'USR-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}');
    final nameCtrl = TextEditingController(text: isEditing ? userToEdit.name : '');
    final phoneCtrl = TextEditingController(text: isEditing ? userToEdit.phone : '');
    final addressCtrl = TextEditingController(text: isEditing ? (userToEdit.address ?? '') : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'تعديل بيانات العميل' : 'إضافة عميل جديد', textDirection: TextDirection.rtl),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'كود العميل', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العميل', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
              const SizedBox(height: 10),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C3FC1), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;

              final user = AppUser(
                id: isEditing ? userToEdit.id : null,
                code: codeCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                address: addressCtrl.text.trim(),
              );

              if (isEditing) {
                await DatabaseHelper.instance.updateUser(user);
              } else {
                await DatabaseHelper.instance.insertUser(user);
              }

              if (context.mounted) Navigator.pop(context);
              _loadUsers();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العملاء والمستخدمين'),
        backgroundColor: const Color(0xFF9C3FC1),
        actions: [
          // زر المعاينة والجدول الموحد تماماً مثل المنتجات
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.table_chart),
            label: const Text('معاينة وطباعة جدول'),
            onPressed: _showTablePreviewDialog,
          ),
          const SizedBox(width: 10),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        backgroundColor: const Color(0xFF9C3FC1),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _users.isEmpty
            ? const Center(child: Text('لا توجد عملاء مسجلون'))
            : ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  double debt = _userDebts[user.id] ?? 0.0;
                  return Card(
                    child: ListTile(
                      title: Text('${user.name} (كود: ${user.code})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('الهاتف: ${user.phone} | العنوان: ${user.address ?? "غير محدد"} | الدين: $debt ل.س', style: const TextStyle(color: Colors.red)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showUserDialog(userToEdit: user)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              if (user.id != null) {
                                await DatabaseHelper.instance.deleteUser(user.id!);
                                _loadUsers();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
