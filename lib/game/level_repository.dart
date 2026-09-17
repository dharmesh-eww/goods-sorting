import 'dart:math';

import 'level_data.dart';
import 'sorting_item.dart';

/// Flutter equivalent of the Unity project's LevelData + LevelDataHolder.
///
/// Level definitions stay separate from progression. Each board is generated
/// deterministically and in matching layers, so there is always at least one
/// complete triple available until every item has been cleared.
class LevelRepository {
  LevelRepository._();

  static const int maxLevel = 2500;

  static const _productAssets = <String>[
    'assets/images/products/apple.svg',
    'assets/images/products/milk.svg',
    'assets/images/products/juice.svg',
    'assets/images/products/cookies.svg',
    'assets/images/products/chocolate.svg',
    'assets/images/products/can.svg',
    'assets/images/products/shampoo.svg',
  ];

  static SortingLevel getLevel(int level) {
    if (level < 1 || level > maxLevel) {
      throw ArgumentError.value(level, 'level', 'Must be between 1 and 2500');
    }

    final difficulty = (level - 1) / (maxLevel - 1);
    final random = Random(49157 + level * 7919);
    final shelfCount = _shelfCount(level);
    final maxStackDepth = _stackDepth(level);
    final itemTypes = _itemTypes(level);
    final capacity = shelfCount * maxStackDepth;
    final groups = min(
      (capacity - _emptySlots(level)) ~/ 3,
      _groupCount(level, shelfCount),
    );

    final products = List<int>.generate(
      groups,
      (index) => index % itemTypes,
    )..shuffle(random);

    final shelves = List.generate(shelfCount, (_) => <_Placed>[]);
    final shelfIndices = List<int>.generate(shelfCount, (index) => index);

    // A layer contains one or two complete triples on different shelves.
    // Removing the top layer exposes the next one, which gives every board a
    // deterministic solution while still allowing the shelf layout to vary.
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
          shelves[shelf].add(
            _Placed(
              productId: product,
              layer: layer,
            ),
          );
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
            // Layer + shelf uniquely identifies every authored board item.
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
      difficulty: difficulty,
      itemTypes: itemTypes,
      shelfCount: shelfCount,
      maxStackDepth: maxStackDepth,
      emptySlots: _emptySlots(level),
      complexity: difficulty,
      timerSeconds: _timerSeconds(level),
      items: List.unmodifiable(items),
    );
  }

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

  static int _timerSeconds(int level) {
    // Unity's first level does not start a timer; later level data contains a
    // timer budget. These are the Flutter equivalents of that level data.
    if (level == 1) return 0;
    if (level <= 5) return 60;
    if (level <= 20) return 120;
    if (level <= 75) return 180;
    if (level <= 200) return 240;
    if (level <= 500) return 300;
    return 360;
  }

  static List<String> get productAssets => List.unmodifiable(_productAssets);
}

class _Placed {
  const _Placed({required this.productId, required this.layer});

  final int productId;
  final int layer;
}
