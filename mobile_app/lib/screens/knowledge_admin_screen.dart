import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../models/app_models.dart';
import '../services/backend_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class KnowledgeAdminScreen extends StatefulWidget {
  const KnowledgeAdminScreen({
    super.key,
    required this.api,
    required this.products,
  });

  final BackendApi api;
  final List<Product> products;

  @override
  State<KnowledgeAdminScreen> createState() => _KnowledgeAdminScreenState();
}

class _KnowledgeAdminScreenState extends State<KnowledgeAdminScreen> {
  late final TextEditingController _searchController;
  final Set<int> _selectedIds = <int>{};
  bool _loading = true;
  List<KnowledgeItem> _items = const <KnowledgeItem>[];
  List<KnowledgeJob> _jobs = const <KnowledgeJob>[];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({String? keyword}) async {
    final effectiveKeyword = keyword ?? _searchController.text.trim();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        widget.api.fetchKnowledgeItems(keyword: effectiveKeyword),
        widget.api.fetchKnowledgeJobs(),
      ]);
      if (!mounted) return;
      final items = results[0] as List<KnowledgeItem>;
      setState(() {
        _items = items;
        _jobs = results[1] as List<KnowledgeJob>;
        _selectedIds.removeWhere(
          (knowledgeId) => !items.any((item) => item.id == knowledgeId),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _reindexAll() async {
    if (_items.isEmpty) return;
    try {
      await widget.api.reindexKnowledge(
        _items.map((item) => item.id).toList(growable: false),
        rebuildMode: 'full',
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已触发全量重建')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _toggleSelection(int knowledgeId) {
    setState(() {
      if (_selectedIds.contains(knowledgeId)) {
        _selectedIds.remove(knowledgeId);
      } else {
        _selectedIds.add(knowledgeId);
      }
    });
  }

  Future<void> _batchReindexSelected() async {
    if (_selectedIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.reindexKnowledge(
        _selectedIds.toList(growable: false)..sort(),
        rebuildMode: 'incremental',
      );
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      await _loadData();
      messenger.showSnackBar(const SnackBar(content: Text('已触发批量重建')));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _batchDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.deleteKnowledgeItems(
        _selectedIds.toList(growable: false)..sort(),
      );
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      await _loadData();
      messenger.showSnackBar(const SnackBar(content: Text('已删除所选知识片段')));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  String _productName(int productId) {
    for (final product in widget.products) {
      if (product.id == productId) return product.name;
    }
    return '商品 #$productId';
  }

  Future<void> _reindexItem(KnowledgeItem item) async {
    try {
      await widget.api.reindexKnowledge(<int>[
        item.id,
      ], rebuildMode: 'incremental');
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已重建：${item.title}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openUploadSheet() async {
    final filenameController = TextEditingController(text: 'manual-note.txt');
    final contentController = TextEditingController();
    final selectedProductIds = <int>{};
    final messenger = ScaffoldMessenger.of(context);
    XFile? selectedFile;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var submitting = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '新增知识片段',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '现在支持选择本地文件或直接粘贴文本上传。PDF、TXT、MD、CSV、JSON 都可以直接走同一入口。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: submitting
                            ? null
                            : () async {
                                const typeGroup = XTypeGroup(
                                  label: 'knowledge',
                                  extensions: <String>[
                                    'pdf',
                                    'txt',
                                    'md',
                                    'markdown',
                                    'csv',
                                    'json',
                                  ],
                                );
                                final file = await openFile(
                                  acceptedTypeGroups: const <XTypeGroup>[
                                    typeGroup,
                                  ],
                                );
                                if (file == null) return;
                                setSheetState(() {
                                  selectedFile = file;
                                  filenameController.text = file.name;
                                });
                              },
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(
                          selectedFile == null
                              ? '选择文件上传'
                              : '已选择：${selectedFile!.name}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: filenameController,
                        decoration: const InputDecoration(labelText: '文件名'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contentController,
                        minLines: 8,
                        maxLines: 14,
                        decoration: const InputDecoration(
                          labelText: '文档内容',
                          hintText: '如果不选文件，也可以直接粘贴维修手册、适配说明、保养建议等文本内容',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '关联商品',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.products
                            .take(12)
                            .map(
                              (product) => FilterChip(
                                label: Text(product.name),
                                selected: selectedProductIds.contains(
                                  product.id,
                                ),
                                onSelected: (selected) {
                                  setSheetState(() {
                                    if (selected) {
                                      selectedProductIds.add(product.id);
                                    } else {
                                      selectedProductIds.remove(product.id);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: submitting
                              ? null
                              : () async {
                                  final filename = filenameController.text
                                      .trim();
                                  final content = contentController.text.trim();
                                  if (filename.isEmpty ||
                                      (selectedFile == null &&
                                          content.isEmpty)) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text('请选择文件，或输入文件名并粘贴文档内容。'),
                                      ),
                                    );
                                    return;
                                  }
                                  setSheetState(() => submitting = true);
                                  try {
                                    final bytes = selectedFile != null
                                        ? await selectedFile!.readAsBytes()
                                        : utf8.encode(contentController.text);
                                    final contentType = _guessContentType(
                                      filename,
                                    );
                                    final knowledgeIds = await widget.api
                                        .uploadKnowledgeDocument(
                                          filename: filename,
                                          fileBytes: bytes,
                                          contentType: contentType,
                                          productIds: selectedProductIds
                                              .toList(),
                                        );
                                    await widget.api.reindexKnowledge(
                                      knowledgeIds,
                                    );
                                    if (!mounted) return;
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    await _loadData();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('知识片段已上传并完成重建'),
                                      ),
                                    );
                                  } catch (error) {
                                    if (!mounted) return;
                                    setSheetState(() => submitting = false);
                                    messenger.showSnackBar(
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
                          child: Text(submitting ? '提交中...' : '上传并重建'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    filenameController.dispose();
    contentController.dispose();
  }

  String _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
      return 'text/markdown';
    }
    return 'text/plain';
  }

  Future<void> _editKnowledgeItem(KnowledgeItem item) async {
    final titleController = TextEditingController(text: item.title);
    final contentController = TextEditingController(text: item.content);
    final engineController = TextEditingController(
      text: item.engineModels.join(', '),
    );
    final selectedProductIds = item.productIds.toSet();
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var submitting = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '编辑知识片段',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: '标题'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: engineController,
                        decoration: const InputDecoration(labelText: '型号关键词'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '关联商品',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.products
                            .map(
                              (product) => FilterChip(
                                label: Text(product.name),
                                selected: selectedProductIds.contains(
                                  product.id,
                                ),
                                onSelected: (selected) {
                                  setSheetState(() {
                                    if (selected) {
                                      selectedProductIds.add(product.id);
                                    } else {
                                      selectedProductIds.remove(product.id);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contentController,
                        minLines: 8,
                        maxLines: 14,
                        decoration: const InputDecoration(labelText: '正文'),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: submitting
                              ? null
                              : () async {
                                  setSheetState(() => submitting = true);
                                  try {
                                    await widget.api.updateKnowledgeItem(
                                      item,
                                      title: titleController.text.trim(),
                                      content: contentController.text.trim(),
                                      productIds: selectedProductIds.toList()
                                        ..sort(),
                                      engineModels: engineController.text
                                          .split(RegExp(r'[,，、/]'))
                                          .map((part) => part.trim())
                                          .where((part) => part.isNotEmpty)
                                          .toList(growable: false),
                                    );
                                    await widget.api.reindexKnowledge(<int>[
                                      item.id,
                                    ], rebuildMode: 'incremental');
                                    if (!mounted) return;
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    await _loadData();
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('知识片段已更新')),
                                    );
                                  } catch (error) {
                                    if (!mounted) return;
                                    setSheetState(() => submitting = false);
                                    messenger.showSnackBar(
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
                          child: Text(submitting ? '保存中...' : '保存修改'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    contentController.dispose();
    engineController.dispose();
  }

  Future<void> _deleteKnowledgeItem(KnowledgeItem item) async {
    try {
      await widget.api.deleteKnowledgeItem(item.id);
      await _loadData();
      if (!mounted) return;
      setState(() => _selectedIds.remove(item.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除：${item.title}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openKnowledgeDetail(KnowledgeItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SoftBadge(label: 'v${item.version}', color: AppTheme.blue),
                    SoftBadge(label: item.status, color: AppTheme.mint),
                    if (item.sourceType != null && item.sourceType!.isNotEmpty)
                      SoftBadge(
                        label: item.sourceType!,
                        color: AppTheme.amber,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      _MetaRow(
                        label: '来源文件',
                        value: item.sourceRef?.isNotEmpty == true
                            ? item.sourceRef!
                            : '手动录入',
                      ),
                      const SizedBox(height: 10),
                      _MetaRow(label: '创建时间', value: item.createdAtLabel),
                      const SizedBox(height: 10),
                      _MetaRow(label: '最近更新', value: item.updatedAtLabel),
                    ],
                  ),
                ),
                if (item.engineModels.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('型号关键词', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.engineModels
                        .map(
                          (model) =>
                              SoftBadge(label: model, color: AppTheme.navy),
                        )
                        .toList(),
                  ),
                ],
                if (item.productIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('关联商品', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.productIds
                        .map(
                          (productId) => SoftBadge(
                            label: _productName(productId),
                            color: AppTheme.blue,
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Text('正文预览', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        item.content,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _editKnowledgeItem(item);
                        },
                        child: const Text('编辑片段'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _openKnowledgeVersions(item);
                        },
                        child: const Text('版本记录'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _reindexItem(item);
                        },
                        child: const Text('立即重建'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openKnowledgeVersions(KnowledgeItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final versions = await widget.api.fetchKnowledgeVersions(item.id);
      if (!mounted) return;
      final fallback = versions.isNotEmpty ? versions.first : null;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          KnowledgeVersionEntry selected = versions.firstWhere(
            (version) => version.version < item.version,
            orElse: () => fallback ?? _currentVersionAsEntry(item),
          );
          return StatefulBuilder(
            builder: (context, setSheetState) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: FractionallySizedBox(
                  heightFactor: 0.9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('版本记录', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      if (versions.isEmpty)
                        const _EmptyCard(message: '当前还没有历史版本。')
                      else ...[
                        SizedBox(
                          height: 108,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: versions.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final version = versions[index];
                              final isSelected = selected.id == version.id;
                              return InkWell(
                                onTap: () => setSheetState(
                                  () => selected = version,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                child: Container(
                                  width: 150,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.navy
                                          : AppTheme.line,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SoftBadge(
                                        label: 'v${version.version}',
                                        color: isSelected
                                            ? AppTheme.navy
                                            : AppTheme.blue,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        version.createdAtLabel,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const Spacer(),
                                      Text(
                                        version.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '对比当前版本 v${item.version}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              ..._buildVersionDiffRows(item, selected),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: selected.version == item.version
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text('确认回滚'),
                                        content: Text(
                                          '将当前知识片段回滚到 v${selected.version}，并立即重建索引。是否继续？',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              dialogContext,
                                            ).pop(false),
                                            child: const Text('取消'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.of(
                                              dialogContext,
                                            ).pop(true),
                                            child: const Text('确认回滚'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    try {
                                      await widget.api.rollbackKnowledgeVersion(
                                        item.id,
                                        version: selected.version,
                                      );
                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }
                                      Navigator.of(sheetContext).pop();
                                      await _loadData();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '已回滚到 v${selected.version}',
                                          ),
                                        ),
                                      );
                                    } catch (error) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
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
                            icon: const Icon(Icons.restore_rounded),
                            label: Text(
                              selected.version == item.version
                                  ? '当前已是该版本'
                                  : '回滚到 v${selected.version}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'v${selected.version} 正文',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    selected.content,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  KnowledgeVersionEntry _currentVersionAsEntry(KnowledgeItem item) {
    return KnowledgeVersionEntry(
      id: item.id,
      knowledgeId: item.id,
      version: item.version,
      title: item.title,
      content: item.content,
      productIds: item.productIds,
      engineModels: item.engineModels,
      sourceRef: item.sourceRef,
      sourceType: item.sourceType,
      status: item.status,
      createdAtLabel: item.updatedAtLabel,
    );
  }

  List<Widget> _buildVersionDiffRows(
    KnowledgeItem current,
    KnowledgeVersionEntry selected,
  ) {
    final widgets = <Widget>[
      _DiffRow(
        label: '标题',
        currentValue: current.title,
        previousValue: selected.title,
      ),
      const SizedBox(height: 10),
      _DiffRow(
        label: '正文长度',
        currentValue: '${current.content.length} 字',
        previousValue: '${selected.content.length} 字',
      ),
      const SizedBox(height: 10),
      _DiffRow(
        label: '型号关键词',
        currentValue: current.engineModels.join('、'),
        previousValue: selected.engineModels.join('、'),
      ),
      const SizedBox(height: 10),
      _DiffRow(
        label: '关联商品',
        currentValue: current.productIds.map(_productName).join('、'),
        previousValue: selected.productIds.map(_productName).join('、'),
      ),
      const SizedBox(height: 10),
      _DiffRow(
        label: '来源',
        currentValue: current.sourceRef ?? '手动录入',
        previousValue: selected.sourceRef ?? '手动录入',
      ),
    ];
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIds.isEmpty ? '知识库管理' : '已选 ${_selectedIds.length} 项',
        ),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              onPressed: _batchReindexSelected,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              onPressed: _batchDeleteSelected,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          if (_selectedIds.isNotEmpty)
            IconButton(
              onPressed: () => setState(() => _selectedIds.clear()),
              icon: const Icon(Icons.close_rounded),
            ),
          IconButton(
            onPressed: _items.isEmpty ? null : _reindexAll,
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUploadSheet,
        backgroundColor: AppTheme.navy,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('上传知识'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) => _loadData(keyword: value),
                    decoration: InputDecoration(
                      hintText: '搜索标题、正文、来源文件',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => _loadData(),
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionHeading(title: '最近重建任务'),
                  const SizedBox(height: 12),
                  if (_jobs.isEmpty)
                    const _EmptyCard(message: '还没有重建任务。')
                  else
                    ..._jobs
                        .take(3)
                        .map(
                          (job) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '任务 #${job.id}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const Spacer(),
                                    SoftBadge(
                                      label: job.status,
                                      color: job.failedCount > 0
                                          ? AppTheme.coral
                                          : AppTheme.mint,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '总数 ${job.totalCount} · 成功 ${job.successCount} · 失败 ${job.failedCount}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '更新时间 ${job.updatedAtLabel}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (job.errorSummary != null &&
                                    job.errorSummary!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    job.errorSummary!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                  const SizedBox(height: 10),
                  const SectionHeading(title: '知识片段'),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    const _EmptyCard(message: '当前还没有知识片段。')
                  else
                    ..._items.map(
                      (item) => InkWell(
                        onTap: () => _openKnowledgeDetail(item),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _selectedIds.contains(item.id)
                                  ? AppTheme.navy
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => _toggleSelection(item.id),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: Icon(
                                        _selectedIds.contains(item.id)
                                            ? Icons.check_circle_rounded
                                            : Icons
                                                  .radio_button_unchecked_rounded,
                                        color: _selectedIds.contains(item.id)
                                            ? AppTheme.navy
                                            : AppTheme.slate,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  SoftBadge(
                                    label: 'v${item.version}',
                                    color: AppTheme.blue,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item.content,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (item.sourceRef != null &&
                                      item.sourceRef!.isNotEmpty)
                                    SoftBadge(
                                      label: item.sourceRef!,
                                      color: AppTheme.amber,
                                    ),
                                  if (item.sourceType != null &&
                                      item.sourceType!.isNotEmpty)
                                    SoftBadge(
                                      label: item.sourceType!,
                                      color: AppTheme.mint,
                                    ),
                                  ...item.engineModels.take(4).map(
                                    (model) => SoftBadge(
                                      label: model,
                                      color: AppTheme.navy,
                                    ),
                                  ),
                                  ...item.productIds.take(3).map(
                                    (productId) => SoftBadge(
                                      label: _productName(productId),
                                      color: AppTheme.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '创建 ${item.createdAtLabel} · 更新 ${item.updatedAtLabel}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _openKnowledgeDetail(item),
                                    child: const Text('详情'),
                                  ),
                                  TextButton(
                                    onPressed: () => _reindexItem(item),
                                    child: const Text('重建'),
                                  ),
                                  TextButton(
                                    onPressed: () => _editKnowledgeItem(item),
                                    child: const Text('编辑'),
                                  ),
                                  TextButton(
                                    onPressed: () => _deleteKnowledgeItem(item),
                                    child: const Text(
                                      '删除',
                                      style: TextStyle(color: AppTheme.coral),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.label,
    required this.currentValue,
    required this.previousValue,
  });

  final String label;
  final String currentValue;
  final String previousValue;

  @override
  Widget build(BuildContext context) {
    final normalizedCurrent = currentValue.isEmpty ? '无' : currentValue;
    final normalizedPrevious = previousValue.isEmpty ? '无' : previousValue;
    final changed = normalizedCurrent != normalizedPrevious;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Text(
          '当前：$normalizedCurrent',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '历史：$normalizedPrevious',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: changed ? AppTheme.coral : AppTheme.slate,
          ),
        ),
      ],
    );
  }
}
