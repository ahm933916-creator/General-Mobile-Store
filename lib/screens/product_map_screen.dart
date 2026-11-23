import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';

class ProductMapScreen extends StatefulWidget {
  final List<Product> products;
  const ProductMapScreen({super.key, required this.products});
  @override State<ProductMapScreen> createState() => _ProductMapScreenState();
}

class _ProductMapScreenState extends State<ProductMapScreen> {
  String query = '';
  int? categoryId;
  @override
  Widget build(BuildContext context) {
    final categories = widget.products.map((p) => p.categoryId).toSet();
    final products = widget.products.where((p) => (categoryId == null || p.categoryId == categoryId) && (query.isEmpty || p.name.contains(query) || p.code.contains(query))).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('خريطة المنتجات')),
      body: Directionality(textDirection: TextDirection.rtl, child: Column(children: [
        Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Expanded(child: TextField(decoration: const InputDecoration(labelText: 'تصفية بالاسم أو الباركود', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => query = v))),
          const SizedBox(width: 8),
          DropdownButton<int>(value: categoryId, hint: const Text('كل الأصناف'), items: [const DropdownMenuItem<int>(value: null, child: Text('كل الأصناف')), ...categories.map((id) => DropdownMenuItem(value: id, child: Text('الصنف $id')))], onChanged: (v) => setState(() => categoryId = v)),
        ])),
        Expanded(child: GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisExtent: 190, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: products.length, itemBuilder: (context, index) {
          final product = products[index];
          final hasImage = product.imagePath != null && File(product.imagePath!).existsSync();
          return InkWell(onTap: () => Navigator.pop(context, product), child: Card(child: Column(children: [
            Expanded(child: hasImage ? Image.file(File(product.imagePath!), fit: BoxFit.cover, width: double.infinity) : const Center(child: Icon(Icons.inventory_2, size: 58))),
            Padding(padding: const EdgeInsets.all(6), child: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
            Text('متوفر: ${product.quantity}', style: const TextStyle(fontSize: 12)), const SizedBox(height: 5),
          ])));
        }))
      ])),
    );
  }
}
