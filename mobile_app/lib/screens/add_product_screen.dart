import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({
    super.key,
    required this.categories,
    required this.onRecognize,
  });

  final List<CategoryItem> categories;
  final Future<RecognitionRecord> Function({
    required String source,
    required List<int> imageBytes,
    required String filename,
    required String contentType,
  })
  onRecognize;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _priceController = TextEditingController();
  final _summaryController = TextEditingController();
  final _compatibilityController = TextEditingController();
  final _specsController = TextEditingController();
  final _usageController = TextEditingController();
  final _tipsController = TextEditingController();

  String? _selectedCategoryName;
  RecognitionRecord? _recognition;
  bool _recognizing = false;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      _selectedCategoryName = widget.categories.first.name;
    }
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

  Future<void> _pickAndRecognize(ImageSource source) async {
    if (_recognizing) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null) return;

      setState(() => _recognizing = true);
      final bytes = await picked.readAsBytes();
      final record = await widget.onRecognize(
        source: source == ImageSource.camera ? 'camera' : 'album',
        imageBytes: bytes,
        filename: picked.name.isEmpty
            ? 'product-${DateTime.now().millisecondsSinceEpoch}.jpg'
            : picked.name,
        contentType: _contentTypeForFilename(picked.name),
      );
      if (!mounted) return;
      _applyRecognition(record);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _recognizing = false);
      }
    }
  }

  String _contentTypeForFilename(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    final extension = dotIndex >= 0
        ? filename.substring(dotIndex + 1).toLowerCase()
        : '';
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  void _applyRecognition(RecognitionRecord record) {
    final suggestedCategory = _matchCategoryName(record);
    setState(() {
      _recognition = record;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = record.title;
      }
      if (_summaryController.text.trim().isEmpty &&
          (record.description ?? '').trim().isNotEmpty) {
        _summaryController.text = record.description!.trim();
      }
      if (_usageController.text.trim().isEmpty &&
          (record.usage ?? '').trim().isNotEmpty) {
        _usageController.text = record.usage!.trim();
      }
      if (_tipsController.text.trim().isEmpty && record.safetyTips.isNotEmpty) {
        _tipsController.text = record.safetyTips.join(', ');
      }
      if (_compatibilityController.text.trim().isEmpty &&
          record.features.isNotEmpty) {
        _compatibilityController.text = record.features.join(', ');
      }
      if (suggestedCategory != null) {
        _selectedCategoryName = suggestedCategory;
      }
    });
  }

  String? _matchCategoryName(RecognitionRecord record) {
    final candidates = <String>[
      if ((record.detectedCategory ?? '').trim().isNotEmpty)
        record.detectedCategory!.trim(),
      if (record.product.category.trim().isNotEmpty)
        record.product.category.trim(),
    ];
    for (final candidate in candidates) {
      for (final category in widget.categories) {
        if (category.name == candidate ||
            category.name.contains(candidate) ||
            candidate.contains(category.name)) {
          return category.name;
        }
      }
    }
    return null;
  }

  void _submit() {
    if (_recognition == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先拍照识别，再保存商品。')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final category = widget.categories.firstWhere(
      (item) => item.name == _selectedCategoryName,
    );
    final price = double.parse(_priceController.text.trim());
    final compatibility = _splitCommaValues(_compatibilityController.text);
    final usageScenes = _splitCommaValues(_usageController.text);
    final safetyTips = _splitCommaValues(_tipsController.text);

    Navigator.of(context).pop(
      NewProductDraft(
        categoryId: category.id,
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        price: price,
        summary: _summaryController.text.trim(),
        compatibility: compatibility,
        specs: _parseSpecs(_specsController.text),
        safetyTips: safetyTips,
        usageScenes: usageScenes,
        keywords: <String>[
          _nameController.text.trim(),
          _brandController.text.trim(),
          _modelController.text.trim(),
          _recognition?.detectedCategory ?? '',
          ...?_recognition?.features,
          ...compatibility,
        ].where((item) => item.isNotEmpty).toList(),
        imageUrls: [
          if ((_recognition?.imageUrl ?? '').isNotEmpty)
            _recognition!.imageUrl!,
        ],
        recognitionId: _recognition?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加商品')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF5FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('先拍照识别', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '新增商品前先上传实物图片，系统会自动带入识别名称、描述和安全提示。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _recognizing
                              ? null
                              : () => _pickAndRecognize(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: Text(_recognizing ? '识别中...' : '拍照识别'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _recognizing
                              ? null
                              : () => _pickAndRecognize(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text('相册识别'),
                        ),
                      ),
                    ],
                  ),
                  if (_recognition != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.mint,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _recognition!.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              Text(
                                '置信度 ${(_recognition!.confidence * 100).round()}%',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          if ((_recognition!.description ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _recognition!.description!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('商品基础信息', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
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
                        (value == null || value.trim().isEmpty)
                        ? '请输入商品名称'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: '品牌'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? '请输入品牌'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(labelText: '型号'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? '请输入型号'
                        : null,
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
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? '请输入简介'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('补充信息', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _compatibilityController,
                    decoration: const InputDecoration(
                      labelText: '适配机型',
                      hintText: '例如：F40, F50, F60',
                    ),
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
                    decoration: const InputDecoration(
                      labelText: '使用场景',
                      hintText: '例如：挂机保养, 出海前巡检',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tipsController,
                    decoration: const InputDecoration(
                      labelText: '安全提示',
                      hintText: '例如：拆装前断电, 更换后检查渗漏',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _recognition == null
                          ? '保存前必须先完成一次拍照识别。识别通过后会把识别图片作为商品首图写入后端。'
                          : '识别已完成，保存成功后首页推荐、分类页和搜索页会直接刷新。',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: _submit, child: const Text('保存商品')),
          ],
        ),
      ),
    );
  }
}
