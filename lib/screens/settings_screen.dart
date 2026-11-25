import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/image_storage_service.dart';
import '../theme_controller.dart';
import '../currency_controller.dart';
import 'accounts_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _appNameController = TextEditingController(text: 'شركة إدارة المخزون والمبيعات');
  String _savedDirectory = '';
  bool _isDarkMode = true;
  String _currencyCode = 'SYP';
  final TextEditingController _rateController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // تحميل الإعدادات المحفوظة مسبقاً
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDirectory = prefs.getString('save_directory');
    final isInternalAndroidPath = Platform.isAndroid &&
        (storedDirectory?.contains('/data/user/0/') == true || storedDirectory?.contains('/data/data/') == true);
    final selectedDirectory = storedDirectory != null && storedDirectory.trim().isNotEmpty && !isInternalAndroidPath
        ? storedDirectory
        : '';
    setState(() {
      _appNameController.text = prefs.getString('app_title') ?? 'شركة إدارة المخزون والمبيعات';
      _savedDirectory = selectedDirectory;
      _isDarkMode = prefs.getBool('dark_mode') ?? true;
      _currencyCode = prefs.getString('currency_code') ?? 'SYP';
      _rateController.text = (prefs.getDouble('currency_rate') ?? 1).toStringAsFixed(0);
    });
    if (storedDirectory != selectedDirectory) await prefs.setString('save_directory', selectedDirectory);
  }

  // حفظ الإعدادات
  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_title', _appNameController.text.trim());
    await prefs.setString('save_directory', _savedDirectory);
    await prefs.setBool('dark_mode', _isDarkMode);
    await saveCurrencySettings(code: _currencyCode, rate: double.tryParse(_rateController.text) ?? 1);

    try {
      await ImageStorageService.configuredDirectory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ لم يتم حفظ الإعدادات: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

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
        backgroundColor: const Color(0xFF9C3FC1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('المصروفات'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('التقارير'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 1. تعديل الاسم العام للبرنامج
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('عنوان البرنامج العام في الأعلى', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF9C3FC1))),
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

            // 2. اختيار مظهر التطبيق
            Card(
              elevation: 3,
              child: SwitchListTile(
                secondary: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFFF0C744)),
                title: const Text('مظهر التطبيق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                subtitle: Text(_isDarkMode ? 'الوضع الداكن - خلفية غامقة' : 'الوضع النهاري - خلفية بيضاء'),
                value: _isDarkMode,
                activeColor: const Color(0xFFF0C744),
                onChanged: (value) async {
                  setState(() => _isDarkMode = value);
                  await saveThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                },
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('العملة وسعر الصرف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9C3FC1))),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(value: _currencyCode, items: const [DropdownMenuItem(value: 'SYP', child: Text('الليرة السورية (ل.س)')), DropdownMenuItem(value: 'USD', child: Text('الدولار الأمريكي (\$)'))], onChanged: (v) => setState(() => _currencyCode = v ?? 'SYP'), decoration: const InputDecoration(labelText: 'العملة'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _rateController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر صرف الدولار بالليرة'))),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 3,
              child: ListTile(
                leading: const Icon(Icons.manage_accounts, color: Color(0xFF9C3FC1)),
                title: const Text('تعديل المستخدمين'),
                subtitle: const Text('تعديل المدير والمحاسب وإضافة حسابات إدارية جديدة'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())),
              ),
            ),
            const SizedBox(height: 16),

            // 3. تحديد المجلد لحفظ لقطات الشاشة
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مجلد حفظ لقطات الشاشة والتقارير', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF9C3FC1))),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _savedDirectory.isEmpty
                              ? 'لم يتم اختيار مجلد خارجي بعد'
                              : 'المجلد الحالي: $_savedDirectory',
                          style: TextStyle(
                            fontSize: 13,
                            color: _savedDirectory.isEmpty ? Colors.red : Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D465B), foregroundColor: const Color(0xFFF0C744)),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('تغيير المجلد'),
                          onPressed: () async {
                            String? selectedDir = await FilePicker.platform.getDirectoryPath();
                            if (selectedDir != null) {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('save_directory', selectedDir);
                              setState(() {
                                _savedDirectory = selectedDir;
                              });
                              try {
                                await ImageStorageService.configuredDirectory();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم اختيار مجلد خارجي قابل للكتابة'), backgroundColor: Colors.green));
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ لا يمكن الكتابة في هذا المجلد: $e'), backgroundColor: Colors.red));
                                }
                              }
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: const Color(0xFF9C3FC1)),
                        SizedBox(width: 8),
                        Text('حول البرنامج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF9C3FC1))),
                      ],
                    ),
                    const Divider(height: 20),
                    const Text('نظام إدارة المخزون والمبيعات المتكامل لبيئة Linux', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    const Text(' برمجة وتصميم: المهندس خالد علي عوده', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(' رقم الهاتف: 0986366109', style: TextStyle(fontSize: 14, color: const Color(0xFF9C3FC1), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // زر الحفظ العام
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C3FC1),
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
