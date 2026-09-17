class SortingItem {
  const SortingItem({
    required this.itemId,
    required this.productId,
    required this.asset,
    required this.stackIndex,
    required this.shelfIndex,
  });

  final int itemId;
  final int productId;
  final String asset;
  final int stackIndex;
  final int shelfIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortingItem && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;
}
