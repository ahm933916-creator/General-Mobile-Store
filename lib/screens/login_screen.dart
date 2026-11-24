import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'customer_menu_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool loading = false;

  Future<void> _login() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) return;
    setState(() => loading = true);
    final account = await DatabaseHelper.instance.authenticateAccount(username.text, password.text);
    if (!mounted) return;
    if (account != null) {
      if (account['role'] == 'customer') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CustomerMenuScreen(initialUsername: username.text.trim())));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(role: account['role'].toString(), displayName: account['displayName'].toString())));
      }
      return;
    }
    final customer = await DatabaseHelper.instance.authenticateCustomer(username.text, password.text);
    if (!mounted) return;
    setState(() => loading = false);
    if (customer != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CustomerMenuScreen(customer: customer)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسم المستخدم أو كلمة المرور غير صحيحة')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircleAvatar(radius: 38, child: Icon(Icons.lock_person, size: 42)),
                  const SizedBox(height: 14),
                  const Text('تسجيل الدخول', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('إدارة المبيعات والمخزون والطلبات'),
                  const SizedBox(height: 24),
                  TextField(controller: username, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: obscure, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.password), suffixIcon: IconButton(icon: Icon(Icons.visibility), onPressed: () => setState(() => obscure = !obscure)))),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: loading ? null : _login, icon: const Icon(Icons.login), label: Text(loading ? 'جارٍ الدخول...' : 'دخول'))),
                  const SizedBox(height: 12),
                  const Text('حسابات البداية: خالد / 123، علي / 456، اسامة / 789', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
