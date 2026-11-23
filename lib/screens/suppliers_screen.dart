import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_helper.dart';
import '../currency_controller.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Supplier> suppliers = [];
  Map<int, double> debts = {};
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    final value = await DatabaseHelper.instance.getSuppliers();
    final loadedDebts = <int, double>{};
    for (final supplier in value) {
      if (supplier.id != null) loadedDebts[supplier.id!] = await DatabaseHelper.instance.getSupplierTotalDebt(supplier.id!, targetCode: currencySettings.value.code, targetRate: currencySettings.value.rate);
    }
    if (mounted) setState(() { suppliers = value; debts = loadedDebts; });
  }

  Future<void> edit([Supplier? old]) async {
    final code = TextEditingController(text: old?.code ?? 'SUP-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}');
    final name = TextEditingController(text: old?.name ?? '');
    final phone = TextEditingController(text: old?.phone ?? '');
    final address = TextEditingController(text: old?.address ?? '');
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(old == null ? 'إضافة مورد' : 'تعديل مورد'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: code, decoration: const InputDecoration(labelText: 'كود المورد')),
        const SizedBox(height: 8), TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المورد')),
        const SizedBox(height: 8), TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
        const SizedBox(height: 8), TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () async {
          if (name.text.trim().isEmpty || phone.text.trim().isEmpty) return;
          final item = Supplier(id: old?.id, code: code.text.trim(), name: name.text.trim(), phone: phone.text.trim(), address: address.text.trim());
          if (old == null) { await DatabaseHelper.instance.insertSupplier(item); } else { await DatabaseHelper.instance.updateSupplier(item); }
          if (dialogContext.mounted) Navigator.pop(dialogContext);
          load();
        }, child: const Text('حفظ')),
      ],
    ));
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة الموردين')),
    floatingActionButton: FloatingActionButton(onPressed: edit, child: const Icon(Icons.add)),
    body: suppliers.isEmpty ? const Center(child: Text('لا يوجد موردون')) : ListView.builder(
      padding: const EdgeInsets.all(10), itemCount: suppliers.length,
      itemBuilder: (context, index) { final s = suppliers[index]; return Card(child: ListTile(
        title: Text('${s.name} (${s.code})'), subtitle: Text('الهاتف: ${s.phone}\nالعنوان: ${s.address ?? 'غير محدد'}\nالدين: ${currencySettings.value.format(debts[s.id] ?? 0)}'), isThreeLine: true,
        trailing: Wrap(children: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => edit(s)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { if (s.id != null) await DatabaseHelper.instance.deleteSupplier(s.id!); load(); }),
        ]),
      )); },
    ),
  );
}
