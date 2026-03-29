import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/backend_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class ConversationDetailScreen extends StatefulWidget {
  const ConversationDetailScreen({
    super.key,
    required this.api,
    required this.summary,
    required this.onOpenProduct,
  });

  final BackendApi api;
  final ConversationSessionSummary summary;
  final ValueChanged<Product> onOpenProduct;

  @override
  State<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  ConversationDetail? _detail;
  bool _loading = true;
  bool _replying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.api.fetchConversationDetail(
        widget.summary.sessionId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _sendFollowUp() async {
    final detail = _detail;
    final question = _controller.text.trim();
    if (detail == null || question.isEmpty || _replying) return;

    setState(() {
      _replying = true;
      _detail = ConversationDetail(
        sessionId: detail.sessionId,
        title: detail.title,
        updatedAtLabel: detail.updatedAtLabel,
        messages: [
          ...detail.messages,
          ChatMessage(text: question, isUser: true),
        ],
      );
      _controller.clear();
    });

    try {
      final reply = await widget.api.askQuestion(
        question,
        sessionId: detail.sessionId,
      );
      if (!mounted) return;
      final updated = _detail;
      if (updated == null) return;
      setState(() {
        _detail = ConversationDetail(
          sessionId: updated.sessionId,
          title: updated.title,
          updatedAtLabel: '刚刚',
          messages: [...updated.messages, reply.message],
        );
        _replying = false;
      });
    } catch (error) {
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      setState(() => _replying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(
        title: Text(detail?.title ?? '问答详情'),
        bottom: detail == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '最近更新 ${detail.updatedAtLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    itemCount: detail!.messages.length + (_replying ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_replying && index == detail.messages.length) {
                        return const _ThinkingBubble();
                      }
                      final message = detail.messages[index];
                      if (message.isUser) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: AppTheme.navy,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              message.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.text,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            if (message.sources.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              ...message.sources.map(
                                (source) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF5FF),
                                    borderRadius: BorderRadius.circular(18),
                                    border: const Border(
                                      left: BorderSide(
                                        color: AppTheme.blue,
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        source.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        source.detail,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (message.recommendedProducts.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              ...message.recommendedProducts.map(
                                (product) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: ProductCard(
                                    product: product,
                                    badge: '推荐商品',
                                    onTap: () => widget.onOpenProduct(product),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: '基于当前会话继续追问',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _sendFollowUp,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(58, 58),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(Icons.arrow_upward_rounded),
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

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(right: 6),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.blue,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
