import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Map<String, dynamic>> accounts = [];
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final rows = await DatabaseHelper.instance.getAppAccounts(); if (mounted) setState(() => accounts = rows); }

  Future<void> _edit([Map<String, dynamic>? account]) async {
    final phone = TextEditingController(text: account?['username']?.toString() ?? '');
    final password = TextEditingController(text: account?['password']?.toString() ?? '');
    final name = TextEditingController(text: account?['displayName']?.toString() ?? '');
    String role = account?['role']?.toString() ?? 'accountant';
    final saved = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (context, refresh) => AlertDialog(title: Text(account == null ? 'إضافة حساب إداري' : 'تعديل الحساب'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')), TextField(controller: password, decoration: const InputDecoration(labelText: 'كلمة المرور')), TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم الظاهر')), DropdownButtonFormField<String>(value: role, items: const [DropdownMenuItem(value: 'manager', child: Text('مدير')), DropdownMenuItem(value: 'accountant', child: Text('محاسب')), DropdownMenuItem(value: 'customer', child: Text('مستخدم متجر'))], onChanged: (v) => refresh(() => role = v ?? 'accountant'), decoration: const InputDecoration(labelText: 'الصلاحية'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), ElevatedButton(onPressed: () async { if (phone.text.trim().isEmpty || password.text.isEmpty || name.text.trim().isEmpty) return; await DatabaseHelper.instance.saveAppAccount(id: account?['id'] as int?, phone: phone.text, password: password.text, role: role, displayName: name.text); if (context.mounted) Navigator.pop(context, true); }, child: const Text('حفظ'))]));
    if (saved == true) _load();
  }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('تعديل المستخدمين الإداريين')), floatingActionButton: FloatingActionButton.extended(onPressed: _edit, icon: const Icon(Icons.person_add), label: const Text('إضافة حساب')), body: ListView(padding: const EdgeInsets.all(12), children: accounts.map((a) => Card(child: ListTile(leading: Icon(a['role'] == 'manager' ? Icons.admin_panel_settings : Icons.account_balance_wallet), title: Text(a['displayName'].toString()), subtitle: Text('رقم الهاتف: ${a['username']}\nالصلاحية: ${a['role']}'), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(a)))).toList()));
}
