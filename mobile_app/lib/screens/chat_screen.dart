import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.onOpenProduct,
    required this.onSendQuestion,
    required this.onSubmitFeedback,
  });

  final ValueChanged<Product> onOpenProduct;
  final Future<ChatMessage> Function(String question) onSendQuestion;
  final Future<void> Function(
    ChatMessage message, {
    required int rating,
    String? comment,
  })
  onSubmitFeedback;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final TextEditingController _controller;
  final List<ChatMessage> _messages = <ChatMessage>[];
  final Set<String> _submittingFeedbackIds = <String>{};
  bool _replying = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _replying) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
      _replying = true;
    });

    try {
      final reply = await widget.onSendQuestion(text);
      if (!mounted) return;
      setState(() {
        _messages.add(reply);
        _replying = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _replying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _collectFeedback(ChatMessage message, int rating) async {
    final messageId = message.messageId;
    if (messageId == null || messageId.isEmpty) return;
    final commentController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final submitting = _submittingFeedbackIds.contains(messageId);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '提交问答反馈',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rating > 0 ? '说明这条回答哪里有帮助。' : '说明这条回答哪里不准，方便后续优化。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: '可选填写，例如：型号正确，但缺少更换周期。',
                        labelText: '补充说明',
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final comment = commentController.text.trim();
                                setState(
                                  () => _submittingFeedbackIds.add(messageId),
                                );
                                setSheetState(() {});
                                try {
                                  await widget.onSubmitFeedback(
                                    message,
                                    rating: rating,
                                    comment: comment.isEmpty ? null : comment,
                                  );
                                  if (!mounted) return;
                                  final index = _messages.indexOf(message);
                                  if (index >= 0) {
                                    setState(() {
                                      _messages[index] = ChatMessage(
                                        text: message.text,
                                        isUser: false,
                                        messageId: message.messageId,
                                        sessionId: message.sessionId,
                                        feedbackRating: rating,
                                        sources: message.sources,
                                        recommendedProducts:
                                            message.recommendedProducts,
                                      );
                                      _submittingFeedbackIds.remove(messageId);
                                    });
                                  } else {
                                    setState(
                                      () => _submittingFeedbackIds.remove(
                                        messageId,
                                      ),
                                    );
                                  }
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('问答反馈已提交')),
                                  );
                                } catch (error) {
                                  if (!mounted) return;
                                  setState(
                                    () => _submittingFeedbackIds.remove(
                                      messageId,
                                    ),
                                  );
                                  setSheetState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) => ActionChip(
                  label: Text(aiPrompts[index]),
                  onPressed: () => _controller.text = aiPrompts[index],
                ),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: aiPrompts.length,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              itemCount: _messages.length + (_replying ? 1 : 0),
              itemBuilder: (context, index) {
                if (_replying && index == _messages.length) {
                  return const _ThinkingBubble();
                }

                final message = _messages[index];
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  style: Theme.of(context).textTheme.bodyMedium,
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
                      if (message.messageId != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('有帮助'),
                              selected: message.feedbackRating == 1,
                              onSelected: message.feedbackRating == 1
                                  ? null
                                  : (_) => _collectFeedback(message, 1),
                            ),
                            FilterChip(
                              label: const Text('不准确'),
                              selected: message.feedbackRating == -1,
                              onSelected: message.feedbackRating == -1
                                  ? null
                                  : (_) => _collectFeedback(message, -1),
                            ),
                          ],
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
                        hintText: '继续追问适配关系、替代件或保养建议',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _send,
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
