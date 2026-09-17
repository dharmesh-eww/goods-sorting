import 'dart:math';

import 'level_data.dart';
import 'sorting_item.dart';

/// Flutter equivalent of the Unity project's LevelData + LevelDataHolder.
///
/// The Unity project stores a finite set of authored LevelData assets and the
/// LevelManager selects one from the holder. Here the same separation is kept
/// in code: the repository owns the level definition and the game screen only
/// consumes it. The generated board is deterministic and is constructed from
/// a valid reverse-play sequence, so every returned level has a guaranteed
/// solution.
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

    final productIds = List<int>.generate(groups, (index) => index % itemTypes);
    productIds.shuffle(random);

    // Build a valid play order. Each product occurs once in each round, which
    // keeps matches spread across the board instead of placing AAA together.
    final playOrder = <int>[];
    for (var round = 0; round < 3; round++) {
      for (var group = 0; group < productIds.length; group++) {
        final product = productIds[group];
        final rotated = (product + round + level + group) % itemTypes;
        playOrder.add(rotated);
      }
    }

    final shelves = List.generate(shelfCount, (_) => <_Placed>[]);
    final shelfOrder = List<int>.generate(shelfCount, (index) => index);

    for (var index = 0; index < playOrder.length; index++) {
      shelfOrder.shuffle(random);
      var placed = false;

      for (var offset = 0; offset < shelfOrder.length; offset++) {
        final shelf = shelfOrder[(offset + index) % shelfOrder.length];
        if (shelves[shelf].length < maxStackDepth) {
          shelves[shelf].add(
            _Placed(itemId: index, productId: playOrder[index]),
          );
          placed = true;
          break;
        }
      }

      if (!placed) {
        throw StateError('Unable to place generated level $level');
      }
    }

    final items = <SortingItem>[];
    for (var shelfIndex = 0; shelfIndex < shelves.length; shelfIndex++) {
      final shelf = shelves[shelfIndex];
      for (var orderIndex = 0; orderIndex < shelf.length; orderIndex++) {
        final placed = shelf[orderIndex];
        items.add(
          SortingItem(
            itemId: level * 100000 + placed.itemId,
            productId: placed.productId,
            asset: _productAssets[placed.productId],
            // The first item in the valid play sequence must be on top.
            stackIndex: shelf.length - orderIndex - 1,
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

  static int _timerSeconds(int level) {
    // Mirrors the Unity project's authored timer progression: level 1 has no
    // timer, then later boards receive progressively larger time budgets.
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
  const _Placed({required this.itemId, required this.productId});

  final int itemId;
  final int productId;
}
