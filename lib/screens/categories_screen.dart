import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_helper.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() async {
    final list = await DatabaseHelper.instance.getCategories();
    setState(() {
      _categories = list;
    });
  }

  void _showCategoryDialog({Category? categoryToEdit}) {
    final isEditing = categoryToEdit != null;
    final nameCtrl = TextEditingController(text: isEditing ? categoryToEdit.name : '');
    final codeCtrl = TextEditingController(
      text: isEditing ? (categoryToEdit.code ?? '') : 'CAT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'تعديل التصنيف' : 'إضافة تصنيف جديد', textDirection: TextDirection.rtl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم التصنيف', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'كود التصنيف', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C3FC1), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                final category = Category(
                  id: isEditing ? categoryToEdit.id : null,
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                );

                if (isEditing) {
                  await DatabaseHelper.instance.updateCategory(category);
                } else {
                  await DatabaseHelper.instance.insertCategory(category);
                }

                if (context.mounted) Navigator.pop(context);
                _loadCategories();
              }
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
        title: const Text('إدارة التصنيفات'),
        backgroundColor: const Color(0xFF9C3FC1),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        backgroundColor: const Color(0xFF9C3FC1),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _categories.isEmpty
            ? const Center(child: Text('لا توجد تصنيفات مسجلة'))
            : ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  return Card(
                    child: ListTile(
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('الكود: ${cat.code ?? "بدون"}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showCategoryDialog(categoryToEdit: cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await DatabaseHelper.instance.deleteCategory(cat.id!);
                              _loadCategories();
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