import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/backend_api.dart';
import '../theme/app_theme.dart';
import 'add_category_screen.dart';
import 'camera_screen.dart';
import 'category_screen.dart';
import 'chat_screen.dart';
import 'conversation_detail_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'knowledge_admin_screen.dart';
import 'product_admin_screen.dart';
import 'product_detail_screen.dart';
import 'product_list_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({
    super.key,
    required this.api,
    required this.currentUser,
    required this.onLogout,
  });

  final BackendApi api;
  final AppUser currentUser;
  final Future<void> Function() onLogout;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;
  AppUser? _user;
  List<CategoryItem> _categories = const <CategoryItem>[];
  List<Product> _products = const <Product>[];
  List<Product> _favoriteProducts = const <Product>[];
  List<RecognitionRecord> _recentRecognitions = const <RecognitionRecord>[];
  List<ConversationSessionSummary> _conversationHistory =
      const <ConversationSessionSummary>[];
  bool _loading = true;
  String? _errorMessage;
  String? _chatSessionId;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant RootShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.id != widget.currentUser.id) {
      _user = widget.currentUser;
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        widget.api.fetchCategories(),
        widget.api.fetchProducts(),
        widget.api.fetchFavorites(),
        widget.api.fetchRecognitions(),
        widget.api.fetchConversationSummaries(),
      ]);
      if (!mounted) return;
      setState(() {
        _user = widget.currentUser;
        _categories = results[0] as List<CategoryItem>;
        _products = results[1] as List<Product>;
        _favoriteProducts = results[2] as List<Product>;
        _recentRecognitions = results[3] as List<RecognitionRecord>;
        _conversationHistory = results[4] as List<ConversationSessionSummary>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _refreshCatalog() async {
    final results = await Future.wait<dynamic>([
      widget.api.fetchCategories(),
      widget.api.fetchProducts(),
      widget.api.fetchFavorites(),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = results[0] as List<CategoryItem>;
      _products = results[1] as List<Product>;
      _favoriteProducts = results[2] as List<Product>;
    });
  }

  Future<void> _refreshFavorites() async {
    final favorites = await widget.api.fetchFavorites();
    if (!mounted) return;
    setState(() => _favoriteProducts = favorites);
  }

  Future<void> _refreshHistory() async {
    final results = await Future.wait<dynamic>([
      widget.api.fetchRecognitions(),
      widget.api.fetchConversationSummaries(),
    ]);
    if (!mounted) return;
    setState(() {
      _recentRecognitions = results[0] as List<RecognitionRecord>;
      _conversationHistory = results[1] as List<ConversationSessionSummary>;
    });
  }

  Future<void> _refreshCurrentUser() async {
    final user = await widget.api.fetchCurrentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          isFavorite: _favoriteProducts.any((item) => item.id == product.id),
          onToggleFavorite: _toggleFavorite,
        ),
      ),
    );
  }

  void _openProductList(String title, List<Product> items) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductListScreen(
          title: title,
          products: items,
          onOpenProduct: _openProduct,
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          onOpenProduct: _openProduct,
          onSearchProducts: _searchProducts,
          onFetchSuggestions: _fetchSearchSuggestions,
          suggestedProducts: _products,
          categories: _categories,
        ),
      ),
    );
  }

  void _openCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          candidateProducts: _products,
          onOpenProduct: _openProduct,
          onRecognize: _recognizeProduct,
          onSubmitFeedback: _submitRecognitionFeedback,
        ),
      ),
    );
  }

  void _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          recognitions: _recentRecognitions,
          conversations: _conversationHistory,
          onOpenProduct: _openProduct,
          onOpenConversation: _openConversationDetail,
        ),
      ),
    );
    await _refreshHistory();
  }

  void _openFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FavoritesScreen(
          favorites: _favoriteProducts,
          onOpenProduct: _openProduct,
        ),
      ),
    );
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          onOpenProduct: _openProduct,
          onSendQuestion: _sendQuestion,
          onSubmitFeedback: _submitConversationFeedback,
        ),
      ),
    );
  }

  void _openKnowledgeAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            KnowledgeAdminScreen(api: widget.api, products: _products),
      ),
    );
  }

  void _openConversationDetail(ConversationSessionSummary summary) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationDetailScreen(
          api: widget.api,
          summary: summary,
          onOpenProduct: _openProduct,
        ),
      ),
    );
    await _refreshHistory();
  }

  void _openProductAdmin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductAdminScreen(
          api: widget.api,
          categories: _categories,
          initialProducts: _products,
          onRecognize: _recognizeProduct,
          onOpenProduct: _openProduct,
        ),
      ),
    );
    await _refreshCatalog();
  }

  void _openAddCategory() async {
    final draft = await Navigator.of(context).push<NewCategoryDraft>(
      MaterialPageRoute(
        builder: (_) => AddCategoryScreen(existingCategories: _categories),
      ),
    );
    if (draft == null) return;
    try {
      final category = await widget.api.createCategory(draft.name);
      await _refreshCatalog();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加分类：${category.name}')));
    } catch (error) {
      _showError(error);
    }
  }

  Future<SearchPage> _searchProducts(SearchQueryOptions options) async {
    if (options.query.trim().isEmpty) {
      return SearchPage(
        products: _products.take(options.limit).toList(growable: false),
        total: _products.length,
        page: 1,
        limit: options.limit,
      );
    }
    return widget.api.searchProducts(options);
  }

  Future<List<String>> _fetchSearchSuggestions(String query) async {
    return widget.api.fetchSearchSuggestions(query.trim());
  }

  Future<RecognitionRecord> _recognizeProduct({
    required String source,
    required List<int> imageBytes,
    required String filename,
    required String contentType,
  }) async {
    final record = await widget.api.recognizeImage(
      source: source,
      fileBytes: imageBytes,
      filename: filename,
      contentType: contentType,
    );
    final deduped = _recentRecognitions
        .where((item) => item.id != record.id)
        .toList();
    if (!mounted) return record;
    setState(() => _recentRecognitions = [record, ...deduped]);
    return record;
  }

  Future<void> _submitRecognitionFeedback(
    RecognitionRecord record, {
    required String feedbackType,
    int? correctProductId,
    String? comment,
  }) async {
    await widget.api.submitRecognitionFeedback(
      record.id,
      feedbackType: feedbackType,
      correctProductId: correctProductId,
      comment: comment,
    );
    await _refreshHistory();
  }

  Future<ChatMessage> _sendQuestion(String question) async {
    final reply = await widget.api.askQuestion(
      question,
      sessionId: _chatSessionId,
    );
    if (mounted) {
      setState(() {
        _chatSessionId = reply.sessionId;
        final newSummary = ConversationSessionSummary(
          sessionId: reply.sessionId,
          lastQuestion: question,
          updatedAtLabel: '刚刚',
        );
        _conversationHistory = [
          newSummary,
          ..._conversationHistory.where(
            (item) => item.sessionId != reply.sessionId,
          ),
        ];
      });
    }
    return reply.message;
  }

  Future<void> _submitConversationFeedback(
    ChatMessage message, {
    required int rating,
    String? comment,
  }) async {
    final sessionId = message.sessionId ?? _chatSessionId;
    final messageId = message.messageId;
    if (sessionId == null ||
        sessionId.isEmpty ||
        messageId == null ||
        messageId.isEmpty) {
      throw Exception('当前消息缺少反馈所需的会话信息。');
    }
    await widget.api.submitConversationFeedback(
      sessionId: sessionId,
      messageId: messageId,
      rating: rating,
      comment: comment,
    );
  }

  Future<bool> _toggleFavorite(Product product) async {
    final isFavorite = _favoriteProducts.any((item) => item.id == product.id);
    if (isFavorite) {
      await widget.api.removeFavorite(product.id);
    } else {
      await widget.api.addFavorite(product.id);
    }
    await _refreshFavorites();
    return _favoriteProducts.any((item) => item.id == product.id);
  }

  Future<void> _changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await widget.api.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  Future<void> _updateProfile({
    required String nickname,
    String? avatarUrl,
  }) async {
    final updatedUser = await widget.api.updateCurrentUser(
      nickname: nickname,
      avatarUrl: avatarUrl,
    );
    if (!mounted) return;
    setState(() => _user = updatedUser);
  }

  Future<String?> _uploadAvatar({
    required List<int> fileBytes,
    required String filename,
    required String contentType,
  }) async {
    final updatedUser = await widget.api.uploadCurrentUserAvatar(
      fileBytes: fileBytes,
      filename: filename,
      contentType: contentType,
    );
    if (!mounted) return updatedUser.avatarUrl;
    setState(() => _user = updatedUser);
    return updatedUser.avatarUrl;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: AppTheme.coral,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '后端连接失败',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _bootstrap,
                    child: const Text('重新连接'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final screens = [
      HomeScreen(
        onOpenSearch: _openSearch,
        onOpenCamera: _openCamera,
        onOpenHistory: _openHistory,
        onOpenProduct: _openProduct,
        onOpenCategory: (categoryName) {
          _openProductList(
            categoryName,
            _products.where((item) => item.category == categoryName).toList(),
          );
        },
        onSwitchToChat: _openChat,
        categoriesList: _categories,
        productsList: _products,
        recentRecognitions: _recentRecognitions,
      ),
      CategoryScreen(
        onOpenCategory: (categoryName) {
          _openProductList(
            categoryName,
            _products.where((item) => item.category == categoryName).toList(),
          );
        },
        onOpenProduct: _openProduct,
        categoriesList: _categories,
        productsList: _products,
      ),
      ProductListScreen(
        title: '商品列表',
        products: _products,
        onOpenProduct: _openProduct,
      ),
      ProfileScreen(
        onOpenHistory: _openHistory,
        onOpenFavorites: _openFavorites,
        onOpenKnowledgeAdmin: _openKnowledgeAdmin,
        onOpenAddCategory: _openAddCategory,
        onOpenProductAdmin: _openProductAdmin,
        onUpdateProfile: _updateProfile,
        onUploadAvatar: _uploadAvatar,
        onChangePassword: _changePassword,
        onLogout: widget.onLogout,
        user: _user,
        onRefreshData: () async {
          try {
            await Future.wait<void>([
              _refreshCatalog(),
              _refreshHistory(),
              _refreshCurrentUser(),
            ]);
          } catch (error) {
            _showError(error);
          }
        },
      ),
    ];

    final items = const [
      (label: '首页', icon: Icons.home_rounded),
      (label: '分类', icon: Icons.grid_view_rounded),
      (label: '商品列表', icon: Icons.inventory_2_rounded),
      (label: '我的', icon: Icons.person_rounded),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180B1220),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = _currentIndex == index;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: () => setState(() => _currentIndex = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.navy.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            item.icon,
                            color: selected ? AppTheme.navy : AppTheme.slate,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: selected ? AppTheme.navy : AppTheme.slate,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
