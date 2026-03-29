import 'package:flutter/material.dart';

import '../models/app_models.dart';

class EditProductScreen extends StatefulWidget {
  const EditProductScreen({
    super.key,
    required this.product,
    required this.categories,
  });

  final Product product;
  final List<CategoryItem> categories;

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _priceController;
  late final TextEditingController _summaryController;
  late final TextEditingController _compatibilityController;
  late final TextEditingController _specsController;
  late final TextEditingController _usageController;
  late final TextEditingController _tipsController;
  late final TextEditingController _imageController;
  String? _selectedCategoryName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _brandController = TextEditingController(text: widget.product.brand);
    _modelController = TextEditingController(text: widget.product.model);
    _priceController = TextEditingController(
      text: widget.product.price.toStringAsFixed(2),
    );
    _summaryController = TextEditingController(text: widget.product.summary);
    _compatibilityController = TextEditingController(
      text: widget.product.compatibility.join(', '),
    );
    _specsController = TextEditingController(
      text: widget.product.specs.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n'),
    );
    _usageController = TextEditingController(
      text: widget.product.usageScenes.join(', '),
    );
    _tipsController = TextEditingController(
      text: widget.product.safetyTips.join(', '),
    );
    _imageController = TextEditingController(
      text: widget.product.imageUrls.isEmpty
          ? ''
          : widget.product.imageUrls.first,
    );
    _selectedCategoryName = widget.product.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _priceController.dispose();
    _summaryController.dispose();
    _compatibilityController.dispose();
    _specsController.dispose();
    _usageController.dispose();
    _tipsController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  List<String> _splitCommaValues(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, String> _parseSpecs(String value) {
    final result = <String, String>{};
    for (final line in value.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(':');
      if (parts.length < 2) continue;
      final key = parts.first.trim();
      final val = parts.sublist(1).join(':').trim();
      if (key.isNotEmpty && val.isNotEmpty) {
        result[key] = val;
      }
    }
    return result;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final category = widget.categories.firstWhere(
      (item) => item.name == _selectedCategoryName,
    );
    final compatibility = _splitCommaValues(_compatibilityController.text);
    final usageScenes = _splitCommaValues(_usageController.text);
    final safetyTips = _splitCommaValues(_tipsController.text);
    final imageUrl = _imageController.text.trim();

    Navigator.of(context).pop(
      NewProductDraft(
        categoryId: category.id,
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        summary: _summaryController.text.trim(),
        compatibility: compatibility,
        specs: _parseSpecs(_specsController.text),
        usageScenes: usageScenes,
        safetyTips: safetyTips,
        keywords: <String>[
          _nameController.text.trim(),
          _brandController.text.trim(),
          _modelController.text.trim(),
          ...compatibility,
        ].where((item) => item.isNotEmpty).toList(),
        imageUrls: imageUrl.isEmpty ? const <String>[] : <String>[imageUrl],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑商品')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryName,
              items: widget.categories
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.name,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedCategoryName = value),
              decoration: const InputDecoration(labelText: '所属分类'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '商品名称'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '请输入商品名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(labelText: '品牌'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '请输入品牌' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modelController,
              decoration: const InputDecoration(labelText: '型号'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '请输入型号' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '价格'),
              validator: (value) =>
                  double.tryParse((value ?? '').trim()) == null
                  ? '请输入有效价格'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summaryController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '简介'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageController,
              decoration: const InputDecoration(labelText: '首图 URL'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _compatibilityController,
              decoration: const InputDecoration(labelText: '适配机型'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _specsController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '规格参数',
                hintText: '每行一条，格式：键: 值',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usageController,
              decoration: const InputDecoration(labelText: '使用场景'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tipsController,
              decoration: const InputDecoration(labelText: '安全提示'),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: _submit, child: const Text('保存修改')),
          ],
        ),
      ),
    );
  }
}
