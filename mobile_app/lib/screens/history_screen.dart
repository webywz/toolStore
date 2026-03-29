import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.recognitions,
    required this.conversations,
    required this.onOpenProduct,
    required this.onOpenConversation,
  });

  final List<RecognitionRecord> recognitions;
  final List<ConversationSessionSummary> conversations;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<ConversationSessionSummary> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('历史记录'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '识别历史'),
              Tab(text: '问答历史'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: recognitions.isEmpty
                  ? [const _HistoryEmptyState(message: '还没有识别历史。')]
                  : recognitions
                        .map(
                          (record) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ProductCard(
                              product: record.product,
                              badge:
                                  '${record.time} · ${(record.confidence * 100).round()}%',
                              onTap: () => onOpenProduct(record.product),
                            ),
                          ),
                        )
                        .toList(),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: conversations.isEmpty
                  ? [const _HistoryEmptyState(message: '还没有问答历史。')]
                  : conversations
                        .map(
                          (item) => InkWell(
                            onTap: () => onOpenConversation(item),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppTheme.blue.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: AppTheme.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.lastQuestion,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '最近更新 ${item.updatedAtLabel}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}
