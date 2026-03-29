import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final Product product;
  final bool isFavorite;
  final Future<bool> Function(Product product) onToggleFavorite;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late bool _favorite;
  bool _updatingFavorite = false;

  @override
  void initState() {
    super.initState();
    _favorite = widget.isFavorite;
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _favorite = widget.isFavorite;
    }
  }

  Future<void> _toggleFavorite() async {
    if (_updatingFavorite) return;
    setState(() => _updatingFavorite = true);
    try {
      final result = await widget.onToggleFavorite(widget.product);
      if (!mounted) return;
      setState(() {
        _favorite = result;
        _updatingFavorite = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingFavorite = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final primaryImage = product.imageUrls.isEmpty ? null : product.imageUrls.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品详情'),
        actions: [
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              _favorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [product.color.withValues(alpha: 0.18), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoftBadge(label: product.category, color: product.color),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${product.brand} · ${product.model}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: primaryImage != null &&
                              primaryImage.isNotEmpty &&
                              !primaryImage.contains('oss.example.com')
                          ? Image.network(
                              primaryImage,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                product.icon,
                                color: product.color,
                                size: 38,
                              ),
                            )
                          : Icon(product.icon, color: product.color, size: 38),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  product.summary,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: product.compatibility
                      .map(
                        (item) => SoftBadge(label: item, color: AppTheme.navy),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _InfoBlock(
            title: '规格参数',
            child: Column(
              children: product.specs.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _InfoBlock(
            title: '适用场景',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: product.usageScenes
                  .map((item) => SoftBadge(label: item, color: product.color))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _InfoBlock(
            title: '安全提示',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: product.safetyTips
                  .map(
                    (tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: AppTheme.amber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tip,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _toggleFavorite,
            icon: const Icon(Icons.bookmark_add_rounded),
            label: Text(
              _updatingFavorite ? '提交中...' : (_favorite ? '已收藏' : '收藏商品'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
