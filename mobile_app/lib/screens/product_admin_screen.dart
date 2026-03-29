import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/backend_api.dart';
import '../theme/app_theme.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class ProductAdminScreen extends StatefulWidget {
  const ProductAdminScreen({
    super.key,
    required this.api,
    required this.categories,
    required this.initialProducts,
    required this.onRecognize,
    required this.onOpenProduct,
  });

  final BackendApi api;
  final List<CategoryItem> categories;
  final List<Product> initialProducts;
  final Future<RecognitionRecord> Function({
    required String source,
    required List<int> imageBytes,
    required String filename,
    required String contentType,
  })
  onRecognize;
  final ValueChanged<Product> onOpenProduct;

  @override
  State<ProductAdminScreen> createState() => _ProductAdminScreenState();
}

class _ProductAdminScreenState extends State<ProductAdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  late List<Product> _products;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _products = widget.initialProducts;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return _products;
    return _products
        .where((product) {
          final haystack = [
            product.name,
            product.brand,
            product.model,
            product.category,
          ].join(' ').toLowerCase();
          return haystack.contains(keyword);
        })
        .toList(growable: false);
  }

  Future<void> _createProduct() async {
    final draft = await Navigator.of(context).push<NewProductDraft>(
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          categories: widget.categories,
          onRecognize: widget.onRecognize,
        ),
      ),
    );
    if (draft == null) return;
    setState(() => _submitting = true);
    try {
      final product = await widget.api.createProduct(draft);
      if (!mounted) return;
      setState(() {
        _products = [
          product,
          ..._products.where((item) => item.id != product.id),
        ];
        _submitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已新增商品：${product.name}')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _editProduct(Product product) async {
    final draft = await Navigator.of(context).push<NewProductDraft>(
      MaterialPageRoute(
        builder: (_) =>
            EditProductScreen(product: product, categories: widget.categories),
      ),
    );
    if (draft == null) return;
    setState(() => _submitting = true);
    try {
      final updated = await widget.api.updateProduct(product.id, draft);
      if (!mounted) return;
      setState(() {
        _products = _products
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
        _submitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已更新商品：${updated.name}')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除商品'),
        content: Text('确认删除“${product.name}”？删除后将不再出现在商品列表和搜索结果里。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _submitting = true);
    try {
      await widget.api.deleteProduct(product.id);
      if (!mounted) return;
      setState(() {
        _products = _products.where((item) => item.id != product.id).toList();
        _submitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除商品：${product.name}')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    return Scaffold(
      appBar: AppBar(title: const Text('商品管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitting ? null : _createProduct,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增商品'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: '搜索商品名称、品牌、型号',
            ),
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text('没有匹配的商品。'),
            )
          else
            ...products.map(
              (product) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => widget.onOpenProduct(product),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${product.brand} · ${product.model}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product.category,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppTheme.slate),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _submitting
                              ? null
                              : () => _editProduct(product),
                          icon: const Icon(Icons.edit_rounded),
                        ),
                        IconButton(
                          onPressed: _submitting
                              ? null
                              : () => _deleteProduct(product),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppTheme.coral,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
