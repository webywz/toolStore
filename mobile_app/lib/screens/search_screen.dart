import 'dart:async';

import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.onOpenProduct,
    required this.onSearchProducts,
    required this.onFetchSuggestions,
    required this.suggestedProducts,
    required this.categories,
  });

  final ValueChanged<Product> onOpenProduct;
  final Future<SearchPage> Function(SearchQueryOptions options) onSearchProducts;
  final Future<List<String>> Function(String query) onFetchSuggestions;
  final List<Product> suggestedProducts;
  final List<CategoryItem> categories;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const List<_PriceFilter> _priceFilters = <_PriceFilter>[
    _PriceFilter(label: '全部价格'),
    _PriceFilter(label: '100 以下', maxPrice: 100),
    _PriceFilter(label: '100-500', minPrice: 100, maxPrice: 500),
    _PriceFilter(label: '500 以上', minPrice: 500),
  ];

  static const List<(String label, String value)> _sortOptions = <(
    String,
    String,
  )>[
    ('综合相关', 'relevance'),
    ('价格从低到高', 'price_asc'),
    ('价格从高到低', 'price_desc'),
    ('最近新增', 'newest'),
  ];

  late final TextEditingController _controller;
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  bool _loadingMore = false;
  int _currentPage = 1;
  int _total = 0;
  int? _selectedCategoryId;
  String _sortBy = 'relevance';
  _PriceFilter _selectedPriceFilter = _priceFilters.first;
  List<Product> _results = const <Product>[];
  List<String> _suggestions = const <String>[];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _results = widget.suggestedProducts.take(8).toList(growable: false);
    _total = _results.length;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  SearchQueryOptions _buildOptions({required int page}) {
    return SearchQueryOptions(
      query: _controller.text.trim(),
      categoryId: _selectedCategoryId,
      minPrice: _selectedPriceFilter.minPrice,
      maxPrice: _selectedPriceFilter.maxPrice,
      sortBy: _sortBy,
      page: page,
      limit: 8,
    );
  }

  Future<void> _runSearch({
    String? rawQuery,
    required int page,
    required bool append,
  }) async {
    final effectiveQuery = (rawQuery ?? _controller.text).trim();
    if (!append) {
      setState(() {
        _query = rawQuery ?? _controller.text;
        if (effectiveQuery.isEmpty) {
          _results = widget.suggestedProducts.take(8).toList(growable: false);
          _suggestions = const <String>[];
          _total = _results.length;
          _currentPage = 1;
          _loading = false;
          _loadingMore = false;
        } else {
          _loading = true;
        }
      });
    } else {
      setState(() => _loadingMore = true);
    }
    if (effectiveQuery.isEmpty) return;

    try {
      final options = _buildOptions(page: page);
      final searchFuture = widget.onSearchProducts(options);
      final suggestionFuture = append
          ? Future<List<String>>.value(_suggestions)
          : widget.onFetchSuggestions(effectiveQuery);
      final results = await Future.wait<dynamic>([searchFuture, suggestionFuture]);
      if (!mounted || _controller.text.trim() != effectiveQuery) return;
      final pageData = results[0] as SearchPage;
      final mergedProducts = append
          ? [
              ..._results,
              ...pageData.products.where(
                (product) => !_results.any((item) => item.id == product.id),
              ),
            ]
          : pageData.products;
      setState(() {
        _results = mergedProducts;
        _suggestions = results[1] as List<String>;
        _total = pageData.total;
        _currentPage = pageData.page;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      _runSearch(rawQuery: value, page: 1, append: false);
    });
  }

  void _applyFilters() {
    if (_controller.text.trim().isEmpty) {
      setState(() {
        _results = widget.suggestedProducts.take(8).toList(growable: false);
        _total = _results.length;
      });
      return;
    }
    _runSearch(page: 1, append: false);
  }

  @override
  Widget build(BuildContext context) {
    final hasMore = _results.length < _total;
    return Scaffold(
      appBar: AppBar(title: const Text('智能搜索')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            onSubmitted: (value) =>
                _runSearch(rawQuery: value, page: 1, append: false),
            decoration: const InputDecoration(
              hintText: '输入型号、品牌、故障现象',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 16),
          if (_query.isEmpty) ...[
            const SectionHeading(title: '热门搜索'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: hotSearches
                  .map(
                    (item) => ActionChip(
                      label: Text(item),
                      onPressed: () {
                        _controller.text = item;
                        _runSearch(rawQuery: item, page: 1, append: false);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
          ] else ...[
            Container(
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
                        '共 $_total 条结果',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        '第 $_currentPage 页',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('分类筛选', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('全部分类'),
                        selected: _selectedCategoryId == null,
                        onSelected: (_) {
                          setState(() => _selectedCategoryId = null);
                          _applyFilters();
                        },
                      ),
                      ...widget.categories.map(
                        (category) => ChoiceChip(
                          label: Text(category.name),
                          selected: _selectedCategoryId == category.id,
                          onSelected: (_) {
                            setState(() => _selectedCategoryId = category.id);
                            _applyFilters();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('价格筛选', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _priceFilters
                        .map(
                          (filter) => ChoiceChip(
                            label: Text(filter.label),
                            selected: identical(filter, _selectedPriceFilter),
                            onSelected: (_) {
                              setState(() => _selectedPriceFilter = filter);
                              _applyFilters();
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('排序方式', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sortOptions
                        .map(
                          (option) => ChoiceChip(
                            label: Text(option.$1),
                            selected: _sortBy == option.$2,
                            onSelected: (_) {
                              setState(() => _sortBy = option.$2);
                              _applyFilters();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_suggestions.isNotEmpty) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _suggestions
                    .map(
                      (item) => ActionChip(
                        label: Text(item),
                        onPressed: () {
                          _controller.text = item;
                          _runSearch(rawQuery: item, page: 1, append: false);
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_results.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    '没有找到完全匹配结果',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '建议调整筛选条件、改搜型号片段，或者切换到拍照识别。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else ...[
            ..._results.map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ProductCard(
                  product: product,
                  badge: _query.isEmpty ? '推荐' : '后端匹配',
                  onTap: () => widget.onOpenProduct(product),
                ),
              ),
            ),
            if (_query.isNotEmpty && hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OutlinedButton.icon(
                  onPressed: _loadingMore
                      ? null
                      : () => _runSearch(
                            page: _currentPage + 1,
                            append: true,
                          ),
                  icon: _loadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(
                    _loadingMore
                        ? '加载中...'
                        : '加载更多 (${_results.length}/$_total)',
                  ),
                ),
              ),
            if (_query.isNotEmpty && !hasMore && _results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: Text(
                    '已加载全部结果',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.slate),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PriceFilter {
  const _PriceFilter({
    required this.label,
    this.minPrice,
    this.maxPrice,
  });

  final String label;
  final double? minPrice;
  final double? maxPrice;
}
