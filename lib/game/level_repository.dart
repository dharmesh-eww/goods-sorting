import 'dart:math';

import 'level_data.dart';
import 'sorting_item.dart';

/// Flutter representation of the authored Unity LevelData set.
///
/// The Unity project contains five LevelData assets (internal IDs 0..4).
/// LevelManager selects them with modulo, so Flutter uses the exact same
/// mapping: UI level 1 -> Unity LevelData 0, UI level 2 -> LevelData 1, etc.
/// The board generator keeps that authored five-level progression while
/// expanding it deterministically to the app's 2,500 playable levels.
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
  /// With five LevelData assets, UI levels map 1..5 -> 0..4 and then repeat.
  static int unityDefinitionIndex(int level) {
    if (level < 1 || level > maxLevel) {
      throw ArgumentError.value(level, 'level', 'Must be between 1 and 2500');
    }
    return (level - 1) % unityLevelDefinitionCount;
  }

  static SortingLevel getLevel(int level) {
    final unityIndex = unityDefinitionIndex(level);
    final random = Random(49157 + level * 7919);
    final shelfCount = _shelfCount(level);
    final maxStackDepth = _stackDepth(level);
    final itemTypes = _itemTypes(level);
    final groups = min(
      (shelfCount * maxStackDepth - _emptySlots(level)) ~/ 3,
      _groupCount(level, shelfCount),
    );

    final products = List<int>.generate(
      groups,
      (index) => index % itemTypes,
    )..shuffle(random);

    final shelves = List.generate(shelfCount, (_) => <_Placed>[]);
    final shelfIndices = List<int>.generate(shelfCount, (index) => index);

    var groupIndex = 0;
    var layer = 0;
    while (groupIndex < products.length) {
      final groupsThisLayer = min(
        _groupsPerLayer(shelfCount),
        products.length - groupIndex,
      );
      final available = List<int>.from(shelfIndices)..shuffle(random);

      for (var group = 0; group < groupsThisLayer; group++) {
        final product = products[groupIndex++];
        final base = group * 3;
        final selectedShelves = available.sublist(base, base + 3);

        for (final shelf in selectedShelves) {
          shelves[shelf].add(_Placed(productId: product, layer: layer));
        }
      }
      layer++;
      if (layer > maxStackDepth) {
        throw StateError('Unable to place generated level $level');
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
      emptySlots: _emptySlots(level),
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

  static int _emptySlots(int level) => level <= 50 ? 3 : 2;

  static int _groupCount(int level, int shelfCount) {
    final base = 3 + (level ~/ 90);
    return min(shelfCount + 4, base);
  }

  static int _groupsPerLayer(int shelfCount) => shelfCount >= 6 ? 2 : 1;

  static List<String> get productAssets => List.unmodifiable(_productAssets);
}

class _Placed {
  const _Placed({required this.productId, required this.layer});

  final int productId;
  final int layer;
}
