import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _appNameController = TextEditingController(text: 'شركة إدارة المخزون والمبيعات');
  String _savedDirectory = '/home';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // تحميل الإعدادات المحفوظة مسبقاً
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appNameController.text = prefs.getString('app_title') ?? 'شركة إدارة المخزون والمبيعات';
      _savedDirectory = prefs.getString('save_directory') ?? '/home/${Platform.environment['USER']}/Downloads';
    });
  }

  // حفظ الإعدادات
  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_title', _appNameController.text.trim());
    await prefs.setString('save_directory', _savedDirectory);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حفظ إعدادات البرنامج بنجاح!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات البرنامج'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // 1. تعديل الاسم العام للبرنامج
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('عنوان البرنامج العام في الأعلى', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _appNameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم البرنامج',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. تحديد المجلد لحفظ لقطات الشاشة
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مجلد حفظ لقطات الشاشة والتقارير', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'المجلد الحالي: $_savedDirectory',
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade50, foregroundColor: Colors.teal.shade800),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('تغيير المجلد'),
                          onPressed: () async {
                            String? selectedDir = await FilePicker.platform.getDirectoryPath();
                            if (selectedDir != null) {
                              setState(() {
                                _savedDirectory = selectedDir;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. حول البرنامج (المبرمج والتفاصيل)
            Card(
              elevation: 3,
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.teal),
                        SizedBox(width: 8),
                        Text('حول البرنامج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                      ],
                    ),
                    const Divider(height: 20),
                    const Text('نظام إدارة المخزون والمبيعات المتكامل لبيئة Linux', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    const Text(' برمجة وتصميم: المهندس خالد علي عوده', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(' رقم الهاتف: 0986366109', style: TextStyle(fontSize: 14, color: Colors.teal, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // زر الحفظ العام
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saveSettings,
              child: const Text('حفظ التعديلات والإعدادات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}