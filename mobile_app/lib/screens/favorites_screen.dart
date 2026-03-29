import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../widgets/app_widgets.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.favorites,
    required this.onOpenProduct,
  });

  final List<Product> favorites;
  final ValueChanged<Product> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的收藏')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '你还没有收藏商品，先去商品详情页点一次收藏。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemBuilder: (context, index) => ProductCard(
          product: favorites[index],
          badge: '已收藏',
          onTap: () => onOpenProduct(favorites[index]),
        ),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemCount: favorites.length,
      ),
    );
  }
}
