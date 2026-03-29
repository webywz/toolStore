import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenSearch,
    required this.onOpenCamera,
    required this.onOpenHistory,
    required this.onOpenProduct,
    required this.onOpenCategory,
    required this.onSwitchToChat,
    required this.categoriesList,
    required this.productsList,
    required this.recentRecognitions,
  });

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenCamera;
  final VoidCallback onOpenHistory;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<String> onOpenCategory;
  final VoidCallback onSwitchToChat;
  final List<CategoryItem> categoriesList;
  final List<Product> productsList;
  final List<RecognitionRecord> recentRecognitions;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF102A6B), AppTheme.navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0x26FFFFFF),
                          child: Icon(
                            Icons.sailing_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '现场查询模式',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '船用五金 AI 工具',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '拍一张，先确认型号。\n问一句，再确认适配。',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '当前已接入本地后端接口，优先服务现场维修、巡检和替代件确认。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 22),
                    InkWell(
                      onTap: onOpenSearch,
                      borderRadius: BorderRadius.circular(22),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search_rounded, color: AppTheme.slate),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '搜型号、配件名、故障现象',
                                style: TextStyle(
                                  color: AppTheme.slate,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(Icons.tune_rounded, color: AppTheme.navy),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _StatusPill(
                            label: '商品总数',
                            value: '${productsList.length}',
                            tone: AppTheme.amber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatusPill(
                            label: '识别历史',
                            value: '${recentRecognitions.length} 条',
                            tone: AppTheme.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SizedBox(
                height: 158,
                child: Row(
                  children: [
                    Expanded(
                      child: QuickActionCard(
                        title: '拍照识别',
                        subtitle: '现场优先入口',
                        icon: Icons.camera_alt_rounded,
                        color: AppTheme.amber,
                        onTap: onOpenCamera,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: QuickActionCard(
                        title: 'AI 问答',
                        subtitle: '带引用回答',
                        icon: Icons.auto_awesome_rounded,
                        color: AppTheme.blue,
                        onTap: onSwitchToChat,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SectionHeading(
                title: '常用分类',
                actionLabel: '查看全部',
                onAction: categoriesList.isEmpty
                    ? null
                    : () => onOpenCategory(categoriesList.first.name),
              ),
              const SizedBox(height: 12),
              if (categoriesList.isEmpty)
                const _EmptyCard(message: '后端还没有分类数据，先去“我的”里添加分类。')
              else
                SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final item = categoriesList[index];
                      return InkWell(
                        onTap: () => onOpenCategory(item.name),
                        borderRadius: BorderRadius.circular(24),
                        child: Ink(
                          width: 120,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(item.icon, color: item.color),
                              ),
                              const Spacer(),
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                item.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemCount: categoriesList.length,
                  ),
                ),
              const SizedBox(height: 22),
              SectionHeading(
                title: '最近识别',
                actionLabel: '历史记录',
                onAction: onOpenHistory,
              ),
              const SizedBox(height: 12),
              if (recentRecognitions.isEmpty)
                const _EmptyCard(message: '还没有识别历史，先试一次拍照识别。'),
              ...recentRecognitions
                  .take(3)
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => onOpenProduct(record.product),
                        borderRadius: BorderRadius.circular(24),
                        child: Ink(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.line),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: record.product.color.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  record.product.icon,
                                  color: record.product.color,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${record.product.name} · ${record.time}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              SoftBadge(
                                label: '${(record.confidence * 100).round()}%',
                                color: record.confidence >= 0.85
                                    ? AppTheme.mint
                                    : AppTheme.amber,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 10),
              const SectionHeading(title: '推荐商品'),
              const SizedBox(height: 12),
              if (productsList.isEmpty)
                const _EmptyCard(message: '商品库为空，先在“我的”里添加商品。'),
              ...productsList
                  .take(3)
                  .map(
                    (product) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ProductCard(
                        product: product,
                        badge: '高频使用',
                        onTap: () => onOpenProduct(product),
                      ),
                    ),
                  ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: tone,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
