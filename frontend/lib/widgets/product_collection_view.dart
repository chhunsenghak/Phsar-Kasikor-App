import 'package:flutter/material.dart';

/// Shared grid/list layout for a collection of products. Callers supply
/// role-specific card/tile widgets; this only handles the switch between
/// a 2-column grid and a vertical list (plus the empty state).
class ProductCollectionView<T> extends StatelessWidget {
  final bool isGridView;
  final List<T> items;
  final Widget Function(BuildContext context, T item) gridItemBuilder;
  final Widget Function(BuildContext context, T item) listItemBuilder;
  final Widget emptyState;

  const ProductCollectionView({
    super.key,
    required this.isGridView,
    required this.items,
    required this.gridItemBuilder,
    required this.listItemBuilder,
    required this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return emptyState;
    }

    if (isGridView) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => gridItemBuilder(context, items[index]),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => listItemBuilder(context, items[index]),
    );
  }
}
