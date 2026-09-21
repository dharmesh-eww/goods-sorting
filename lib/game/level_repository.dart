import 'dart:math';

import 'level_data.dart';
import 'sorting_item.dart';

/// Deterministic Flutter representation of the authored Unity level system.
///
/// Unity provides five LevelData definitions and selects them with modulo.
/// Flutter preserves that timer mapping while generating the playable board
/// deterministically. Every generated product exists in complete groups of
/// three, and each stack layer is arranged so the currently accessible items
/// can always be resolved as triples.
class LevelRepository {
  LevelRepository._();

  static const int maxLevel = 2500;
  static const int unityLevelDefinitionCount = 5;

  static const _productAssets = <String>[
    'assets/images/products/apple.svg',
    'assets/images/products/milk.svg',
    'assets/images/products/juice.svg',
    'assets/images/products/cookies.svg',
    'assets/images/products/chocolate.svg',
    'assets/images/products/can.svg',
    'assets/images/products/shampoo.svg',
  ];

  /// Unity's LevelManager uses `_levelId % levels.Length`.
  /// UI levels 1..5 therefore map to Unity LevelData 0..4.
  static int unityDefinitionIndex(int level) {
    if (level < 1 || level > maxLevel) {
      throw ArgumentError.value(
        level,
        'level',
        'Must be between 1 and 2500',
      );
    }
    return (level - 1) % unityLevelDefinitionCount;
  }

  static SortingLevel getLevel(int level) {
    final unityIndex = unityDefinitionIndex(level);
    final random = Random(49157 + level * 7919);
    final shelfCount = _shelfCount(level);
    final maxStackDepth = _stackDepth(level);
    final itemTypes = _itemTypes(level);
    final groupsPerLayer = _groupsPerLayer(shelfCount);

    // A group is always exactly three matching products. The number of
    // groups grows with stack depth, giving early levels a compact board
    // while preserving enough layers to make the puzzle progressively deeper.
    final maxGroups = (shelfCount * maxStackDepth) ~/ 3;
    final groupCount = min(
      maxGroups,
      max(3, maxStackDepth * groupsPerLayer),
    );

    final products = List<int>.generate(
      groupCount,
      (index) => (index + level + random.nextInt(itemTypes)) % itemTypes,
    );

    // Avoid adjacent groups using the same product when possible. This keeps
    // the early board visually varied without breaking the triple guarantee.
    products.shuffle(random);
    for (var i = 1; i < products.length; i++) {
      if (products[i] == products[i - 1] && itemTypes > 1) {
        final swap = products.indexWhere(
          (product) => product != products[i - 1],
          i + 1,
        );
        if (swap >= 0) {
          final value = products[i];
          products[i] = products[swap];
          products[swap] = value;
        }
      }
    }

    final shelves = List.generate(shelfCount, (_) => <_Placed>[]);
    final shelfIndices = List<int>.generate(shelfCount, (index) => index);

    var groupIndex = 0;
    for (var layer = 0; groupIndex < products.length; layer++) {
      final groupsThisLayer = min(
        groupsPerLayer,
        products.length - groupIndex,
      );
      final available = List<int>.from(shelfIndices)..shuffle(random);

      for (var group = 0; group < groupsThisLayer; group++) {
        final product = products[groupIndex++];
        final base = group * 3;
        final selectedShelves = available.sublist(base, base + 3);

        for (final shelf in selectedShelves) {
          shelves[shelf].add(
            _Placed(productId: product, layer: layer),
          );
        }
      }
    }

    final items = <SortingItem>[];
    for (var shelfIndex = 0; shelfIndex < shelves.length; shelfIndex++) {
      for (final placed in shelves[shelfIndex]) {
        items.add(
          SortingItem(
            itemId: level * 100000 + placed.layer * 100 + shelfIndex,
            productId: placed.productId,
            asset: _productAssets[placed.productId],
            stackIndex: placed.layer,
            shelfIndex: shelfIndex,
          ),
        );
      }
    }

    items.sort((a, b) {
      final shelf = a.shelfIndex.compareTo(b.shelfIndex);
      if (shelf != 0) return shelf;
      return a.stackIndex.compareTo(b.stackIndex);
    });

    return SortingLevel(
      levelNumber: level,
      difficulty: (level - 1) / (maxLevel - 1),
      itemTypes: itemTypes,
      shelfCount: shelfCount,
      maxStackDepth: maxStackDepth,
      emptySlots: maxGroups - groupCount,
      complexity: (level - 1) / (maxLevel - 1),
      timerSeconds: _unityTimers[unityIndex],
      items: List.unmodifiable(items),
    );
  }

  // Exact timers from Unity LevelData 0..4:
  // 0 = 60s, 1 = 300s, 2 = 315s, 3 = 330s, 4 = 360s.
  static const _unityTimers = <int>[60, 300, 315, 330, 360];

  static int _itemTypes(int level) {
    if (level <= 10) return 3;
    if (level <= 50) return 4;
    if (level <= 150) return 5;
    if (level <= 350) return 6;
    return 7;
  }

  static int _shelfCount(int level) {
    if (level <= 5) return 3;
    if (level <= 20) return 4;
    if (level <= 75) return 5;
    if (level <= 200) return 6;
    if (level <= 500) return 7;
    return 8;
  }

  static int _stackDepth(int level) {
    if (level <= 5) return 4;
    if (level <= 20) return 5;
    if (level <= 75) return 6;
    if (level <= 200) return 7;
    if (level <= 500) return 8;
    return 9;
  }

  static int _groupsPerLayer(int shelfCount) => shelfCount >= 6 ? 2 : 1;

  static List<String> get productAssets => List.unmodifiable(_productAssets);
}

class _Placed {
  const _Placed({required this.productId, required this.layer});

  final int productId;
  final int layer;
}
