class SortingItem {
  const SortingItem({
    this.itemId = -1,
    required this.productId,
    required this.asset,
    required this.stackIndex,
    required this.shelfIndex,
  });

  /// Stable identity for repository-created items. A negative value keeps
  /// backwards compatibility with older callers that did not provide an id.
  final int itemId;
  final int productId;
  final String asset;
  final int stackIndex;
  final int shelfIndex;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SortingItem) return false;
    if (itemId >= 0 && other.itemId >= 0) return itemId == other.itemId;
    return false;
  }

  @override
  int get hashCode => itemId >= 0 ? itemId.hashCode : identityHashCode(this);
}
