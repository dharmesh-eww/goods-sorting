class SortingItem {
  const SortingItem({
    required this.productId,
    required this.asset,
    required this.stackIndex,
    required this.shelfIndex,
  });

  final int productId;
  final String asset;
  final int stackIndex;
  final int shelfIndex;
}
