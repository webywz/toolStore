import 'package:flutter/material.dart';

class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.brand,
    required this.model,
    required this.category,
    required this.price,
    required this.summary,
    required this.compatibility,
    required this.specs,
    required this.safetyTips,
    required this.usageScenes,
    this.imageUrls = const [],
    required this.icon,
    required this.color,
  });

  final int id;
  final int categoryId;
  final String name;
  final String brand;
  final String model;
  final String category;
  final double price;
  final String summary;
  final List<String> compatibility;
  final Map<String, String> specs;
  final List<String> safetyTips;
  final List<String> usageScenes;
  final List<String> imageUrls;
  final IconData icon;
  final Color color;
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final int id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class SearchQueryOptions {
  const SearchQueryOptions({
    required this.query,
    this.categoryId,
    this.minPrice,
    this.maxPrice,
    this.sortBy = 'relevance',
    this.page = 1,
    this.limit = 8,
  });

  final String query;
  final int? categoryId;
  final double? minPrice;
  final double? maxPrice;
  final String sortBy;
  final int page;
  final int limit;
}

class SearchPage {
  const SearchPage({
    required this.products,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<Product> products;
  final int total;
  final int page;
  final int limit;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.account,
    required this.nickname,
    this.avatarUrl,
    this.isAdmin = false,
  });

  final int id;
  final String account;
  final String nickname;
  final String? avatarUrl;
  final bool isAdmin;

  AppUser copyWith({
    String? nickname,
    String? avatarUrl,
    bool clearAvatar = false,
  }) {
    return AppUser(
      id: id,
      account: account,
      nickname: nickname ?? this.nickname,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      isAdmin: isAdmin,
    );
  }
}

class AnswerSource {
  const AnswerSource({required this.title, required this.detail});

  final String title;
  final String detail;
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.messageId,
    this.sessionId,
    this.feedbackRating,
    this.sources = const [],
    this.recommendedProducts = const [],
  });

  final String text;
  final bool isUser;
  final String? messageId;
  final String? sessionId;
  final int? feedbackRating;
  final List<AnswerSource> sources;
  final List<Product> recommendedProducts;
}

class ConversationSessionSummary {
  const ConversationSessionSummary({
    required this.sessionId,
    required this.lastQuestion,
    required this.updatedAtLabel,
  });

  final String sessionId;
  final String lastQuestion;
  final String updatedAtLabel;
}

class ConversationDetail {
  const ConversationDetail({
    required this.sessionId,
    required this.updatedAtLabel,
    required this.messages,
    this.title,
  });

  final String sessionId;
  final String? title;
  final String updatedAtLabel;
  final List<ChatMessage> messages;
}

class RecognitionRecord {
  const RecognitionRecord({
    required this.id,
    required this.title,
    required this.time,
    required this.confidence,
    required this.product,
    this.imageUrl,
    this.detectedCategory,
    this.description,
    this.features = const [],
    this.usage,
    this.safetyTips = const [],
  });

  final String id;
  final String title;
  final String time;
  final double confidence;
  final Product product;
  final String? imageUrl;
  final String? detectedCategory;
  final String? description;
  final List<String> features;
  final String? usage;
  final List<String> safetyTips;
}

class NewCategoryDraft {
  const NewCategoryDraft({required this.name});

  final String name;
}

class NewProductDraft {
  const NewProductDraft({
    required this.categoryId,
    required this.name,
    required this.brand,
    required this.model,
    required this.price,
    required this.summary,
    required this.compatibility,
    required this.specs,
    required this.usageScenes,
    required this.safetyTips,
    required this.keywords,
    this.imageUrls = const [],
    this.recognitionId,
  });

  final int categoryId;
  final String name;
  final String brand;
  final String model;
  final double price;
  final String summary;
  final List<String> compatibility;
  final Map<String, String> specs;
  final List<String> usageScenes;
  final List<String> safetyTips;
  final List<String> keywords;
  final List<String> imageUrls;
  final String? recognitionId;
}

class KnowledgeItem {
  const KnowledgeItem({
    required this.id,
    required this.title,
    required this.content,
    required this.productIds,
    required this.engineModels,
    required this.sourceRef,
    required this.sourceType,
    required this.version,
    required this.status,
    required this.createdAtLabel,
    required this.updatedAtLabel,
  });

  final int id;
  final String title;
  final String content;
  final List<int> productIds;
  final List<String> engineModels;
  final String? sourceRef;
  final String? sourceType;
  final int version;
  final String status;
  final String createdAtLabel;
  final String updatedAtLabel;
}

class KnowledgeJob {
  const KnowledgeJob({
    required this.id,
    required this.status,
    required this.totalCount,
    required this.successCount,
    required this.failedCount,
    required this.updatedAtLabel,
    this.errorSummary,
  });

  final int id;
  final String status;
  final int totalCount;
  final int successCount;
  final int failedCount;
  final String updatedAtLabel;
  final String? errorSummary;
}

class KnowledgeVersionEntry {
  const KnowledgeVersionEntry({
    required this.id,
    required this.knowledgeId,
    required this.version,
    required this.title,
    required this.content,
    required this.productIds,
    required this.engineModels,
    required this.status,
    required this.createdAtLabel,
    this.sourceRef,
    this.sourceType,
  });

  final int id;
  final int knowledgeId;
  final int version;
  final String title;
  final String content;
  final List<int> productIds;
  final List<String> engineModels;
  final String? sourceRef;
  final String? sourceType;
  final String status;
  final String createdAtLabel;
}
