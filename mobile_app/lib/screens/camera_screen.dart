import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.candidateProducts,
    required this.onOpenProduct,
    required this.onRecognize,
    required this.onSubmitFeedback,
  });

  final List<Product> candidateProducts;
  final ValueChanged<Product> onOpenProduct;
  final Future<RecognitionRecord> Function({
    required String source,
    required List<int> imageBytes,
    required String filename,
    required String contentType,
  })
  onRecognize;
  final Future<void> Function(
    RecognitionRecord record, {
    required String feedbackType,
    int? correctProductId,
    String? comment,
  })
  onSubmitFeedback;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  double _progress = 0;
  RecognitionRecord? _record;
  XFile? _selectedFile;
  Uint8List? _previewBytes;

  Future<void> _openFeedbackSheet() async {
    final record = _record;
    if (record == null) return;

    final commentController = TextEditingController();
    var feedbackType = 'wrong_product';
    int? selectedProductId = record.product.id > 0 ? record.product.id : null;
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '提交纠错反馈',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '把识别结果和正确商品回传到后端，后续可用于优化匹配。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          [
                                ('wrong_product', '识别错商品'),
                                ('need_more_images', '需要补拍'),
                                ('other', '其他问题'),
                              ]
                              .map(
                                (item) => ChoiceChip(
                                  label: Text(item.$2),
                                  selected: feedbackType == item.$1,
                                  onSelected: (_) {
                                    setSheetState(() {
                                      feedbackType = item.$1;
                                      if (feedbackType != 'wrong_product') {
                                        selectedProductId = null;
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(),
                    ),
                    if (feedbackType == 'wrong_product') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: selectedProductId,
                        decoration: const InputDecoration(labelText: '正确商品'),
                        items: widget.candidateProducts
                            .map(
                              (product) => DropdownMenuItem<int>(
                                value: product.id,
                                child: Text(
                                  product.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: submitting
                            ? null
                            : (value) => setSheetState(
                                () => selectedProductId = value,
                              ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: '补充说明',
                        hintText: '例如：应为 F40 机油滤芯，建议把标签近景一起拍入。',
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final trimmed = commentController.text.trim();
                                if (feedbackType == 'wrong_product' &&
                                    selectedProductId == null) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    const SnackBar(content: Text('请选择正确商品。')),
                                  );
                                  return;
                                }
                                setSheetState(() => submitting = true);
                                try {
                                  await widget.onSubmitFeedback(
                                    record,
                                    feedbackType: feedbackType,
                                    correctProductId:
                                        feedbackType == 'wrong_product'
                                        ? selectedProductId
                                        : null,
                                    comment: trimmed.isEmpty ? null : trimmed,
                                  );
                                  if (!mounted) return;
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    const SnackBar(content: Text('纠错反馈已提交')),
                                  );
                                } catch (error) {
                                  if (!mounted) return;
                                  setSheetState(() => submitting = false);
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        error.toString().replaceFirst(
                                          'Exception: ',
                                          '',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: Text(submitting ? '提交中...' : '提交反馈'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    commentController.dispose();
  }

  Future<void> _pickAndRecognize(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _isAnalyzing = true;
        _progress = 0.22;
        _record = null;
        _selectedFile = picked;
        _previewBytes = bytes;
      });

      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _progress = 0.58);

      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() => _progress = 0.86);

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final fileName = picked.name.isEmpty
          ? 'capture-${DateTime.now().millisecondsSinceEpoch}.jpg'
          : picked.name;
      final record = await widget.onRecognize(
        source: source == ImageSource.camera ? 'camera' : 'album',
        imageBytes: bytes,
        filename: fileName,
        contentType: _contentTypeForFilename(fileName),
      );
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _progress = 1;
        _record = record;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
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
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _record?.product;
    final record = _record;

    return Scaffold(
      appBar: AppBar(title: const Text('拍照识别')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF132B68), Color(0xFF294E9F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -16,
                  top: 24,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SoftBadge(label: '真实上传识别', color: Colors.white),
                      const Spacer(),
                      const Text(
                        '对准型号刻字、接口位置\n或尺寸特征区域拍摄',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '拍照或从相册选择后，会把真实图片直接上传到本地后端识别接口。',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isAnalyzing
                      ? null
                      : () => _pickAndRecognize(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('拍照识别'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing
                      ? null
                      : () => _pickAndRecognize(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('相册识别'),
                ),
              ),
            ],
          ),
          if (_previewBytes != null) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_previewBytes!, fit: BoxFit.cover),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: SoftBadge(
                        label: _selectedFile?.name ?? '当前图片',
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_isAnalyzing) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('识别中', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _progress,
                    borderRadius: BorderRadius.circular(999),
                    minHeight: 10,
                    color: AppTheme.amber,
                    backgroundColor: AppTheme.amber.withValues(alpha: 0.18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '正在提取刻字、轮廓与接口特征...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text('识别结果', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                SoftBadge(
                  label: '置信度 ${((record?.confidence ?? 0) * 100).round()}%',
                  color: AppTheme.mint,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ProductCard(
              product: result,
              badge: '推荐匹配',
              onTap: () => widget.onOpenProduct(result),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('补拍建议', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '如果实物上还有局部刻字，建议补拍标签边缘或接口近景，以进一步确认替代型号。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openFeedbackSheet,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('提交纠错反馈'),
            ),
          ],
        ],
      ),
    );
  }
}
