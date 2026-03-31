import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';

class BackendApiException implements Exception {
  const BackendApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionExpiredException extends BackendApiException {
  const SessionExpiredException() : super('登录状态已失效，请重新登录。');
}

class ChatReply {
  const ChatReply({required this.message, required this.sessionId});

  final ChatMessage message;
  final String sessionId;
}

class BackendApi {
  BackendApi({String? baseUrl, this.onUnauthorized})
    : _baseUrl = _resolveBaseUrl(baseUrl);

  static const _defaultServerBaseUrl = 'http://47.123.7.235';

  final String _baseUrl;
  final VoidCallback? onUnauthorized;
  final http.Client _client = http.Client();
  final Map<int, Product> _productCache = <int, Product>{};
  final Map<int, CategoryItem> _categoryCache = <int, CategoryItem>{};

  String? _token;
  bool _handlingUnauthorized = false;

  static String _resolveBaseUrl(String? explicitBaseUrl) {
    if (explicitBaseUrl != null && explicitBaseUrl.trim().isNotEmpty) {
      return explicitBaseUrl.trim();
    }
    const envBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (envBaseUrl.isNotEmpty) return envBaseUrl;
    return _defaultServerBaseUrl;
  }

  String? get currentToken => _token;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  void restoreToken(String token) {
    _token = token.trim().isEmpty ? null : token.trim();
  }

  void clearToken() {
    _token = null;
  }

  Future<void> login({
    required String account,
    required String password,
  }) async {
    final data =
        await _request(
              'POST',
              '/api/v1/auth/login',
              body: {'account': account, 'password': password},
              requiresAuth: false,
            )
            as Map<String, dynamic>;
    _token = data['token'] as String?;
    if (_token == null || _token!.isEmpty) {
      throw const BackendApiException('登录成功，但未返回 token。');
    }
  }

  Future<void> register({
    required String account,
    required String password,
    required String nickname,
  }) async {
    final data =
        await _request(
              'POST',
              '/api/v1/auth/register',
              body: {
                'account': account,
                'password': password,
                'nickname': nickname,
              },
              requiresAuth: false,
            )
            as Map<String, dynamic>;
    _token = data['token'] as String?;
    if (_token == null || _token!.isEmpty) {
      throw const BackendApiException('注册成功，但未返回 token。');
    }
  }

  Future<void> resetPassword({
    required String account,
    required String newPassword,
  }) async {
    await _request(
      'POST',
      '/api/v1/auth/reset-password',
      body: {'account': account, 'new_password': newPassword},
      requiresAuth: false,
    );
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _request(
      'POST',
      '/api/v1/auth/change-password',
      body: {'old_password': oldPassword, 'new_password': newPassword},
    );
  }

  Future<AppUser> fetchCurrentUser() async {
    final data =
        await _request('GET', '/api/v1/users/me') as Map<String, dynamic>;
    return AppUser(
      id: data['id'] as int,
      account: data['account'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '现场账号',
      avatarUrl: _resolveUrl(data['avatar_url'] as String?),
      isAdmin: data['is_admin'] as bool? ?? false,
    );
  }

  Future<List<CategoryItem>> fetchCategories() async {
    final data = await _request('GET', '/api/v1/categories') as List<dynamic>;
    final categories = data
        .map((item) => _mapCategory(item as Map<String, dynamic>))
        .toList(growable: false);
    for (final category in categories) {
      _categoryCache[category.id] = category;
    }
    return categories;
  }

  Future<List<Product>> fetchProducts() async {
    final data =
        await _request('GET', '/api/v1/products') as Map<String, dynamic>;
    final productSummaries =
        (data['products'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
    final products = await Future.wait(
      productSummaries.map((item) => fetchProduct(item['id'] as int)),
    );
    return products;
  }

  Future<Product> fetchProduct(int productId) async {
    final cached = _productCache[productId];
    if (cached != null) return cached;

    final data =
        await _request('GET', '/api/v1/products/$productId')
            as Map<String, dynamic>;
    final product = _mapProductDetail(data);
    _productCache[product.id] = product;
    return product;
  }

  Future<SearchPage> searchProducts(SearchQueryOptions options) async {
    final data =
        await _request(
              'POST',
              '/api/v1/search/intelligent-search',
              body: {
                'query': options.query,
                'search_type': 'auto',
                'category_id': options.categoryId,
                'min_price': options.minPrice,
                'max_price': options.maxPrice,
                'sort_by': options.sortBy,
                'page': options.page,
                'limit': options.limit,
              },
            )
            as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final products = await Future.wait(
      results.map((item) => fetchProduct(item['product_id'] as int)),
    );
    return SearchPage(
      products: products,
      total: data['total'] as int? ?? products.length,
      page: data['page'] as int? ?? options.page,
      limit: data['limit'] as int? ?? options.limit,
    );
  }

  Future<List<String>> fetchSearchSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <String>[];
    final data =
        await _request(
              'GET',
              '/api/v1/search/suggestions?q=${Uri.encodeQueryComponent(trimmed)}',
            )
            as Map<String, dynamic>;
    return (data['suggestions'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .toList(growable: false);
  }

  Future<List<Product>> fetchFavorites() async {
    final data =
        await _request('GET', '/api/v1/favorites') as Map<String, dynamic>;
    final products = (data['products'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return Future.wait(products.map((item) => fetchProduct(item['id'] as int)));
  }

  Future<void> addFavorite(int productId) async {
    await _request('POST', '/api/v1/favorites/$productId');
  }

  Future<void> removeFavorite(int productId) async {
    await _request('DELETE', '/api/v1/favorites/$productId');
  }

  Future<List<RecognitionRecord>> fetchRecognitions() async {
    final data =
        await _request('GET', '/api/v1/ai/recognitions')
            as Map<String, dynamic>;
    final records = (data['records'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final recognitions = <RecognitionRecord>[];
    for (final item in records) {
      final product = await _resolveProductByName(
        item['item_name'] as String? ?? '',
      );
      recognitions.add(
        RecognitionRecord(
          id: item['recognition_id'] as String? ?? '',
          title: item['item_name'] as String? ?? '识别记录',
          time: _formatTime(item['created_at'] as String?),
          confidence: 0.86,
          product: product,
          imageUrl: item['thumbnail'] as String?,
        ),
      );
    }
    return recognitions;
  }

  Future<List<String>> fetchQuestionHistory() async {
    final sessions = await fetchConversationSummaries();
    return sessions.map((item) => item.lastQuestion).toList(growable: false);
  }

  Future<List<ConversationSessionSummary>> fetchConversationSummaries() async {
    final data =
        await _request('GET', '/api/v1/ai/conversations')
            as Map<String, dynamic>;
    final sessions = (data['sessions'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return sessions
        .map(
          (item) => ConversationSessionSummary(
            sessionId: item['session_id'] as String? ?? '',
            lastQuestion: item['last_question'] as String? ?? '',
            updatedAtLabel: _formatTime(item['updated_at'] as String?),
          ),
        )
        .where((item) => item.lastQuestion.isNotEmpty)
        .toList(growable: false);
  }

  Future<ConversationDetail> fetchConversationDetail(String sessionId) async {
    final data =
        await _request('GET', '/api/v1/ai/conversations/$sessionId')
            as Map<String, dynamic>;
    final messages = (data['messages'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final mappedMessages = <ChatMessage>[];
    for (final item in messages) {
      final recommended =
          (item['recommended_products'] as List<dynamic>? ?? const <dynamic>[])
              .cast<Map<String, dynamic>>();
      final recommendedProducts = <Product>[];
      for (final productJson in recommended) {
        final productId = productJson['product_id'] as int?;
        if (productId != null) {
          recommendedProducts.add(await fetchProduct(productId));
        }
      }
      final citations =
          (item['citations'] as List<dynamic>? ?? const <dynamic>[])
              .cast<Map<String, dynamic>>();
      mappedMessages.add(
        ChatMessage(
          text: item['content'] as String? ?? '',
          isUser: (item['role'] as String? ?? 'assistant') == 'user',
          messageId: item['message_id'] as String?,
          sessionId: data['session_id'] as String? ?? sessionId,
          sources: citations
              .map(
                (citation) => AnswerSource(
                  title: citation['title'] as String? ?? '知识引用',
                  detail: citation['snippet'] as String? ?? '',
                ),
              )
              .toList(growable: false),
          recommendedProducts: recommendedProducts,
        ),
      );
    }
    return ConversationDetail(
      sessionId: data['session_id'] as String? ?? sessionId,
      title: data['title'] as String?,
      updatedAtLabel: _formatTime(data['updated_at'] as String?),
      messages: mappedMessages,
    );
  }

  Future<ChatReply> askQuestion(String question, {String? sessionId}) async {
    final data =
        await _request(
              'POST',
              '/api/v1/ai/rag-chat',
              body: {'question': question, 'session_id': sessionId},
            )
            as Map<String, dynamic>;
    final recommended =
        (data['recommended_products'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
    final recommendedProducts = <Product>[];
    for (final item in recommended) {
      final productId = item['product_id'] as int?;
      if (productId != null) {
        recommendedProducts.add(await fetchProduct(productId));
      }
    }
    final citations = (data['citations'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final message = ChatMessage(
      text: data['answer'] as String? ?? '暂无回答',
      isUser: false,
      messageId: data['message_id'] as String?,
      sessionId: data['session_id'] as String? ?? sessionId,
      sources: citations
          .map(
            (item) => AnswerSource(
              title: item['title'] as String? ?? '知识引用',
              detail: item['snippet'] as String? ?? '',
            ),
          )
          .toList(growable: false),
      recommendedProducts: recommendedProducts,
    );
    return ChatReply(
      message: message,
      sessionId: data['session_id'] as String? ?? sessionId ?? '',
    );
  }

  Future<void> submitConversationFeedback({
    required String sessionId,
    required String messageId,
    required int rating,
    String? comment,
  }) async {
    await _request(
      'POST',
      '/api/v1/ai/conversations/$sessionId/feedback',
      body: {'message_id': messageId, 'rating': rating, 'comment': comment},
    );
  }

  Future<RecognitionRecord> recognizeImage({
    required String source,
    required List<int> fileBytes,
    required String filename,
    required String contentType,
  }) async {
    final data =
        await _multipartRequest(
              '/api/v1/ai/recognize-image',
              fields: {'source': source},
              fileFieldName: 'file',
              filename: filename,
              contentType: contentType,
              fileBytes: fileBytes,
            )
            as Map<String, dynamic>;
    return _mapRecognitionRecord(data);
  }

  Future<RecognitionRecord> _mapRecognitionRecord(
    Map<String, dynamic> data,
  ) async {
    final matched =
        (data['matched_products'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
    Product product;
    if (matched.isNotEmpty && matched.first['product_id'] is int) {
      product = await fetchProduct(matched.first['product_id'] as int);
    } else {
      product = await _resolveProductByName(
        (data['result'] as Map<String, dynamic>? ??
                    const <String, dynamic>{})['item_name']
                as String? ??
            '',
      );
    }
    return RecognitionRecord(
      id: data['recognition_id'] as String? ?? '',
      title:
          (data['result'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})['item_name']
              as String? ??
          '识别结果',
      time: '刚刚',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
      product: product,
      imageUrl: data['image_url'] as String?,
      detectedCategory:
          (data['result'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})['category']
              as String?,
      description:
          (data['result'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})['description']
              as String?,
      features:
          ((data['result'] as Map<String, dynamic>? ??
                          const <String, dynamic>{})['features']
                      as List<dynamic>? ??
                  const <dynamic>[])
              .map((item) => item.toString())
              .toList(growable: false),
      usage:
          (data['result'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})['usage']
              as String?,
      safetyTips:
          ((data['result'] as Map<String, dynamic>? ??
                          const <String, dynamic>{})['safety_tips']
                      as List<dynamic>? ??
                  const <dynamic>[])
              .map((item) => item.toString())
              .toList(growable: false),
    );
  }

  Future<void> submitRecognitionFeedback(
    String recognitionId, {
    required String feedbackType,
    int? correctProductId,
    String? comment,
  }) async {
    await _request(
      'POST',
      '/api/v1/ai/recognitions/$recognitionId/feedback',
      body: {
        'feedback_type': feedbackType,
        'correct_product_id': correctProductId,
        'comment': comment,
      },
    );
  }

  Future<CategoryItem> createCategory(String name) async {
    final data =
        await _request(
              'POST',
              '/api/v1/internal/categories',
              body: {'name': name, 'parent_id': null, 'icon_url': null},
            )
            as Map<String, dynamic>;
    final category = _mapCategory(<String, dynamic>{
      'id': data['id'],
      'name': data['name'],
      'children': const <dynamic>[],
    });
    _categoryCache[category.id] = category;
    return category;
  }

  Future<Product> createProduct(NewProductDraft draft) async {
    final data =
        await _request(
              'POST',
              '/api/v1/internal/products',
              body: {
                'category_id': draft.categoryId,
                'name': draft.name,
                'brand': draft.brand,
                'model_no': draft.model,
                'description': draft.summary,
                'price': draft.price,
                'images': draft.imageUrls,
                'specs': draft.specs,
                'compatibility': draft.compatibility,
                'usage_scenarios': draft.usageScenes.join('、'),
                'safety_tips': draft.safetyTips,
                'keywords': draft.keywords,
              },
            )
            as Map<String, dynamic>;
    final product = await fetchProduct(data['id'] as int);
    _productCache[product.id] = product;
    return product;
  }

  Future<Product> updateProduct(int productId, NewProductDraft draft) async {
    final data =
        await _request(
              'PUT',
              '/api/v1/internal/products/$productId',
              body: {
                'category_id': draft.categoryId,
                'name': draft.name,
                'brand': draft.brand,
                'model_no': draft.model,
                'description': draft.summary,
                'price': draft.price,
                'images': draft.imageUrls,
                'specs': draft.specs,
                'compatibility': draft.compatibility,
                'usage_scenarios': draft.usageScenes.join('、'),
                'safety_tips': draft.safetyTips,
                'keywords': draft.keywords,
              },
            )
            as Map<String, dynamic>;
    _productCache.remove(productId);
    final product = await fetchProduct(data['id'] as int);
    _productCache[product.id] = product;
    return product;
  }

  Future<void> deleteProduct(int productId) async {
    await _request('DELETE', '/api/v1/internal/products/$productId');
    _productCache.remove(productId);
  }

  Future<AppUser> updateCurrentUser({
    required String nickname,
    String? avatarUrl,
  }) async {
    final data =
        await _request(
              'PUT',
              '/api/v1/users/me',
              body: {'nickname': nickname, 'avatar_url': avatarUrl},
            )
            as Map<String, dynamic>;
    return AppUser(
      id: data['id'] as int,
      account: data['account'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '',
      avatarUrl: _resolveUrl(data['avatar_url'] as String?),
      isAdmin: data['is_admin'] as bool? ?? false,
    );
  }

  Future<AppUser> uploadCurrentUserAvatar({
    required List<int> fileBytes,
    required String filename,
    required String contentType,
  }) async {
    final data =
        await _multipartRequest(
              '/api/v1/users/me/avatar',
              fields: const <String, String>{},
              fileFieldName: 'file',
              filename: filename,
              contentType: contentType,
              fileBytes: fileBytes,
            )
            as Map<String, dynamic>;
    return AppUser(
      id: data['id'] as int,
      account: data['account'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '',
      avatarUrl: _resolveUrl(data['avatar_url'] as String?),
      isAdmin: data['is_admin'] as bool? ?? false,
    );
  }

  Future<Product> _resolveProductByName(String name) async {
    final cachedMatch = _firstOrNull(
      _productCache.values.where((item) => item.name == name),
    );
    if (cachedMatch != null) return cachedMatch;

    final products = _productCache.values.toList(growable: false);
    final fuzzyMatch = _firstOrNull(
      products.where(
        (item) => name.contains(item.name) || item.name.contains(name),
      ),
    );
    if (fuzzyMatch != null) return fuzzyMatch;

    final fetchedProducts = await fetchProducts();
    final fetchedMatch = _firstOrNull(
      fetchedProducts.where(
        (item) =>
            item.name == name ||
            name.contains(item.name) ||
            item.name.contains(name),
      ),
    );
    if (fetchedMatch != null) return fetchedMatch;

    return Product(
      id: -DateTime.now().millisecondsSinceEpoch,
      categoryId: 0,
      name: name.isEmpty ? '未知商品' : name,
      brand: 'Unknown',
      model: 'N/A',
      category: '未分类',
      price: 0,
      summary: '后端已返回识别记录，但当前本地尚未同步到完整商品详情。',
      compatibility: const <String>[],
      specs: const <String, String>{},
      safetyTips: const <String>[],
      usageScenes: const <String>[],
      imageUrls: const <String>[],
      icon: Icons.inventory_2_rounded,
      color: AppTheme.slate,
    );
  }

  Future<List<KnowledgeItem>> fetchKnowledgeItems({String? keyword}) async {
    final suffix = keyword == null || keyword.trim().isEmpty
        ? ''
        : '?keyword=${Uri.encodeQueryComponent(keyword.trim())}';
    final data =
        await _request('GET', '/api/v1/internal/knowledge/items$suffix')
            as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return items.map(_mapKnowledgeItem).toList(growable: false);
  }

  Future<List<KnowledgeVersionEntry>> fetchKnowledgeVersions(
    int knowledgeId,
  ) async {
    final data =
        await _request('GET', '/api/v1/internal/knowledge/items/$knowledgeId/versions')
            as Map<String, dynamic>;
    final versions =
        (data['versions'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
    return versions.map(_mapKnowledgeVersion).toList(growable: false);
  }

  Future<KnowledgeItem> rollbackKnowledgeVersion(
    int knowledgeId, {
    required int version,
  }) async {
    final data =
        await _request(
              'POST',
              '/api/v1/internal/knowledge/items/$knowledgeId/rollback',
              body: {'version': version},
            )
            as Map<String, dynamic>;
    return _mapKnowledgeItem(data);
  }

  Future<List<KnowledgeJob>> fetchKnowledgeJobs() async {
    final data =
        await _request('GET', '/api/v1/internal/knowledge/jobs')
            as Map<String, dynamic>;
    final jobs = (data['jobs'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return jobs.map(_mapKnowledgeJob).toList(growable: false);
  }

  Future<List<int>> uploadKnowledgeDocument({
    required String filename,
    required List<int> fileBytes,
    String contentType = 'text/plain',
    List<int> productIds = const <int>[],
  }) async {
    final data =
        await _multipartRequest(
              '/api/v1/internal/knowledge/upload-document',
              fields: {'product_ids': productIds.join(',')},
              fileFieldName: 'file',
              filename: filename,
              contentType: contentType,
              fileBytes: fileBytes,
            )
            as Map<String, dynamic>;
    final ids = (data['knowledge_ids'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item as int)
        .toList(growable: false);
    return ids;
  }

  Future<KnowledgeJob> reindexKnowledge(
    List<int> knowledgeIds, {
    String rebuildMode = 'incremental',
  }) async {
    final data =
        await _request(
              'POST',
              '/api/v1/internal/knowledge/reindex',
              body: {
                'knowledge_ids': knowledgeIds,
                'rebuild_mode': rebuildMode,
              },
            )
            as Map<String, dynamic>;
    final jobId = data['job_id'] as int? ?? 0;
    final jobs = await fetchKnowledgeJobs();
    final matched = _firstOrNull(jobs.where((item) => item.id == jobId));
    return matched ??
        KnowledgeJob(
          id: jobId,
          status: data['status'] as String? ?? 'completed',
          totalCount: knowledgeIds.length,
          successCount: knowledgeIds.length,
          failedCount: 0,
          updatedAtLabel: '刚刚',
        );
  }

  Future<KnowledgeItem> updateKnowledgeItem(
    KnowledgeItem item, {
    required String title,
    required String content,
    required List<String> engineModels,
    required List<int> productIds,
  }) async {
    final data =
        await _request(
              'PUT',
              '/api/v1/internal/knowledge/items/${item.id}',
              body: {
                'title': title,
                'content': content,
                'product_ids': productIds,
                'engine_models': engineModels,
              },
            )
            as Map<String, dynamic>;
    return _mapKnowledgeItem(data);
  }

  Future<void> deleteKnowledgeItem(int knowledgeId) async {
    await _request('DELETE', '/api/v1/internal/knowledge/items/$knowledgeId');
  }

  Future<void> deleteKnowledgeItems(List<int> knowledgeIds) async {
    await _request(
      'POST',
      '/api/v1/internal/knowledge/items/batch-delete',
      body: {'knowledge_ids': knowledgeIds},
    );
  }

  CategoryItem _mapCategory(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '未分类';
    final children = (json['children'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final visual = _visualForCategory(name);
    final subtitle = children.isEmpty
        ? '待补充子分类'
        : children
              .map((item) => item['name'] as String? ?? '')
              .where((item) => item.isNotEmpty)
              .join('、');
    return CategoryItem(
      id: json['id'] as int? ?? 0,
      name: name,
      subtitle: subtitle.isEmpty ? '待补充子分类' : subtitle,
      icon: visual.icon,
      color: visual.color,
    );
  }

  Product _mapProductDetail(Map<String, dynamic> data) {
    final categoryName = data['category'] as String? ?? '未分类';
    final visual = _visualForCategory(categoryName);
    final usageText = data['usage_scenarios'] as String? ?? '';
    return Product(
      id: data['id'] as int,
      categoryId: data['category_id'] as int? ?? 0,
      name: data['name'] as String? ?? '未命名商品',
      brand: data['brand'] as String? ?? '',
      model: data['model'] as String? ?? '',
      category: categoryName,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      summary: data['description'] as String? ?? '',
      compatibility:
          (data['compatibility'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(growable: false),
      specs:
          ((data['specs'] as Map<String, dynamic>? ??
                  const <String, dynamic>{}))
              .map((key, value) => MapEntry(key, value.toString())),
      safetyTips: (data['safety_tips'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(growable: false),
      usageScenes: usageText.isEmpty
          ? const <String>[]
          : usageText
                .split(RegExp(r'[、,，/]'))
                .where((item) => item.trim().isNotEmpty)
                .map((item) => item.trim())
                .toList(growable: false),
      imageUrls: (data['images'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .map(_resolveUrl)
          .whereType<String>()
          .toList(growable: false),
      icon: visual.icon,
      color: visual.color,
    );
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request(method, uri);
    request.headers['accept'] = 'application/json';
    if (requiresAuth) {
      final token = _token;
      if (token == null || token.isEmpty) {
        throw const BackendApiException('当前未登录，无法访问受保护接口。');
      }
      request.headers['authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    final response = await _client.send(request).timeout(
      const Duration(seconds: 10),
    );
    final payload = await response.stream.bytesToString();
    return _decodeResponse(
      response.statusCode,
      payload,
      notifyUnauthorized: requiresAuth,
    );
  }

  Future<dynamic> _multipartRequest(
    String path, {
    required Map<String, String> fields,
    required String fileFieldName,
    required String filename,
    required String contentType,
    required List<int> fileBytes,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const BackendApiException('当前未登录，无法访问受保护接口。');
    }
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri)
      ..headers['accept'] = 'application/json'
      ..headers['authorization'] = 'Bearer $token'
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          fileFieldName,
          fileBytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      );

    final response = await _client.send(request).timeout(
      const Duration(seconds: 20),
    );
    final payload = await response.stream.bytesToString();
    return _decodeResponse(
      response.statusCode,
      payload,
      notifyUnauthorized: true,
    );
  }

  dynamic _decodeResponse(
    int statusCode,
    String payload, {
    required bool notifyUnauthorized,
  }) {
    final decoded = payload.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(payload) as Map<String, dynamic>;
    if (notifyUnauthorized && statusCode == 401) {
      _handleUnauthorized();
      throw const SessionExpiredException();
    }
    if (statusCode >= 400 || decoded['success'] == false) {
      final error = decoded['error'] as Map<String, dynamic>?;
      throw BackendApiException(
        error?['message'] as String? ?? '请求失败，状态码 $statusCode',
      );
    }
    return decoded['data'];
  }

  void _handleUnauthorized() {
    _token = null;
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    try {
      onUnauthorized?.call();
    } finally {
      _handlingUnauthorized = false;
    }
  }

  KnowledgeItem _mapKnowledgeItem(Map<String, dynamic> json) {
    return KnowledgeItem(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '未命名片段',
      content: json['content'] as String? ?? '',
      productIds: (json['product_ids'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item as int)
          .toList(growable: false),
      engineModels:
          (json['engine_models'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(growable: false),
      sourceRef: json['source_ref'] as String?,
      sourceType: json['source_type'] as String?,
      version: json['version'] as int? ?? 1,
      status: json['status'] as String? ?? 'unknown',
      createdAtLabel: _formatTime(json['created_at'] as String?),
      updatedAtLabel: _formatTime(json['updated_at'] as String?),
    );
  }

  KnowledgeJob _mapKnowledgeJob(Map<String, dynamic> json) {
    return KnowledgeJob(
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? 'unknown',
      totalCount: json['total_count'] as int? ?? 0,
      successCount: json['success_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      updatedAtLabel: _formatTime(json['updated_at'] as String?),
      errorSummary: json['error_summary'] as String?,
    );
  }

  KnowledgeVersionEntry _mapKnowledgeVersion(Map<String, dynamic> json) {
    return KnowledgeVersionEntry(
      id: json['id'] as int? ?? 0,
      knowledgeId: json['knowledge_id'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
      title: json['title'] as String? ?? '未命名版本',
      content: json['content'] as String? ?? '',
      productIds: (json['product_ids'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item as int)
          .toList(growable: false),
      engineModels:
          (json['engine_models'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(growable: false),
      sourceRef: json['source_ref'] as String?,
      sourceType: json['source_type'] as String?,
      status: json['status'] as String? ?? 'unknown',
      createdAtLabel: _formatTime(json['created_at'] as String?),
    );
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '刚刚';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    final now = DateTime.now();
    final difference = now.difference(parsed);
    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
    if (difference.inDays < 1) return '${difference.inHours} 小时前';
    return '${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  String? _resolveUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/')) {
      return '$_baseUrl$raw';
    }
    return raw;
  }

  _CategoryVisual _visualForCategory(String categoryName) {
    if (categoryName.contains('滤芯')) {
      return const _CategoryVisual(Icons.filter_alt_rounded, AppTheme.amber);
    }
    if (categoryName.contains('点火') || categoryName.contains('火花塞')) {
      return const _CategoryVisual(Icons.bolt_rounded, AppTheme.blue);
    }
    if (categoryName.contains('密封') || categoryName.contains('O 型圈')) {
      return const _CategoryVisual(Icons.water_drop_rounded, AppTheme.mint);
    }
    if (categoryName.contains('紧固') ||
        categoryName.contains('螺丝') ||
        categoryName.contains('卡箍')) {
      return const _CategoryVisual(Icons.build_circle_rounded, AppTheme.coral);
    }
    if (categoryName.contains('燃油')) {
      return const _CategoryVisual(
        Icons.local_gas_station_rounded,
        AppTheme.navy,
      );
    }
    if (categoryName.contains('冷却') || categoryName.contains('叶轮')) {
      return const _CategoryVisual(Icons.mode_fan_off_rounded, AppTheme.slate);
    }
    return const _CategoryVisual(Icons.category_rounded, AppTheme.blue);
  }

  T? _firstOrNull<T>(Iterable<T> items) {
    for (final item in items) {
      return item;
    }
    return null;
  }
}

class _CategoryVisual {
  const _CategoryVisual(this.icon, this.color);

  final IconData icon;
  final Color color;
}
