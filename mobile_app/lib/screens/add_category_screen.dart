import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key, required this.existingCategories});

  final List<CategoryItem> existingCategories;

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();
  late _CategoryVisual _selectedVisual;

  @override
  void initState() {
    super.initState();
    _selectedVisual = _visuals.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final exists = widget.existingCategories.any((item) => item.name == name);
    if (exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分类名称已存在，请换一个名称。')));
      return;
    }

    Navigator.of(context).pop(NewCategoryDraft(name: name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加分类')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('分类信息', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '分类名称',
                      hintText: '例如：传动系统',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? '请输入分类名称'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subtitleController,
                    decoration: const InputDecoration(
                      labelText: '分类说明',
                      hintText: '例如：齿轮、轴承与连接件',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? '请输入分类说明'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  Text('图标与配色', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _visuals.map((visual) {
                      final selected = identical(visual, _selectedVisual);
                      return InkWell(
                        onTap: () => setState(() => _selectedVisual = visual),
                        borderRadius: BorderRadius.circular(18),
                        child: Ink(
                          width: 98,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? visual.color.withValues(alpha: 0.16)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected ? visual.color : AppTheme.line,
                              width: selected ? 1.6 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: visual.color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(visual.icon, color: Colors.white),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                visual.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF5FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('当前版本会把分类提交到后端接口，保存成功后会同步刷新首页、分类页和商品录入表单。'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: _submit, child: const Text('保存分类')),
          ],
        ),
      ),
    );
  }
}

class _CategoryVisual {
  const _CategoryVisual({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

const _visuals = <_CategoryVisual>[
  _CategoryVisual(
    label: '滤芯',
    icon: Icons.filter_alt_rounded,
    color: AppTheme.amber,
  ),
  _CategoryVisual(label: '点火', icon: Icons.bolt_rounded, color: AppTheme.blue),
  _CategoryVisual(
    label: '密封',
    icon: Icons.water_drop_rounded,
    color: AppTheme.mint,
  ),
  _CategoryVisual(
    label: '紧固',
    icon: Icons.build_circle_rounded,
    color: AppTheme.coral,
  ),
  _CategoryVisual(
    label: '燃油',
    icon: Icons.local_gas_station_rounded,
    color: AppTheme.navy,
  ),
  _CategoryVisual(
    label: '冷却',
    icon: Icons.mode_fan_off_rounded,
    color: AppTheme.slate,
  ),
];
