import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../widgets/app_widgets.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({
    super.key,
    required this.title,
    required this.products,
    required this.onOpenProduct,
  });

  final String title;
  final List<Product> products;
  final ValueChanged<Product> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '这个分类下暂时还没有商品，先去“我的”里添加商品。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemBuilder: (context, index) => ProductCard(
          product: products[index],
          badge: products[index].category,
          onTap: () => onOpenProduct(products[index]),
        ),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemCount: products.length,
      ),
    );
  }
}
