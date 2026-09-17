import 'dart:math';

import 'level_data.dart';
import 'sorting_item.dart';

class LevelGenerator {
  static const products = <String>[
    'assets/images/products/apple.svg',
    'assets/images/products/milk.svg',
    'assets/images/products/juice.svg',
    'assets/images/products/cookies.svg',
    'assets/images/products/chocolate.svg',
    'assets/images/products/can.svg',
    'assets/images/products/shampoo.svg',
  ];

  static SortingLevel generate(int level) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'Must be >= 1');

    final progress = ((level - 1) / 2499.0).clamp(0.0, 1.0);
    final difficulty = _smooth(progress);
    final random = Random(level * 7919 + 104729);
    final itemTypes = _itemTypes(level);
    final shelfCount = _shelfCount(level);
    final maxStackDepth = _stackDepth(level);
    final emptySlots = _emptySlots(level);
    final complexity = _complexity(level, difficulty);
    final totalSlots = shelfCount * 3;
    final usableSlots = max(3, totalSlots - emptySlots);
    final groups = max(1, usableSlots ~/ 3);
    final items = <SortingItem>[];

    // Each product is created in a complete triple. The shuffle and shelf
    // distribution make the triples progressively harder to discover.
    for (var group = 0; group < groups; group++) {
      final productId = _productForGroup(
        group,
        itemTypes,
        random,
        complexity,
      );
      for (var copy = 0; copy < 3; copy++) {
        items.add(
          SortingItem(
            productId: productId,
            asset: products[productId],
            stackIndex: 0,
            shelfIndex: group % shelfCount,
          ),
        );
      }
    }

    _shuffleWithComplexity(items, random, complexity);

    final distributed = <SortingItem>[];
    final stackCounts = List<int>.filled(shelfCount, 0);
    for (final item in items) {
      var shelf = random.nextInt(shelfCount);
      if (complexity > .45 && random.nextDouble() < complexity) {
        shelf = (shelf + random.nextInt(shelfCount)) % shelfCount;
      }
      final stackIndex = stackCounts[shelf] % maxStackDepth;
      stackCounts[shelf]++;
      distributed.add(
        SortingItem(
          productId: item.productId,
          asset: item.asset,
          stackIndex: stackIndex,
          shelfIndex: shelf,
        ),
      );
    }

    return SortingLevel(
      levelNumber: level,
      difficulty: progress,
      itemTypes: itemTypes,
      shelfCount: shelfCount,
      maxStackDepth: maxStackDepth,
      emptySlots: emptySlots,
      complexity: complexity,
      items: List.unmodifiable(distributed),
    );
  }

  static double _smooth(double value) => value * value * (3 - 2 * value);

  static int _itemTypes(int level) {
    // The repository currently contains seven distinct product assets.
    // New product assets can be added later and this progression can then
    // continue beyond seven without changing the generation architecture.
    if (level <= 10) return 3;
    if (level <= 40) return 4;
    if (level <= 100) return 5;
    if (level <= 200) return 6;
    return 7;
  }

  static int _shelfCount(int level) {
    if (level <= 30) return 2;
    if (level <= 100) return 3;
    if (level <= 250) return 4;
    if (level <= 450) return 5;
    if (level <= 700) return 6;
    if (level <= 950) return 7;
    if (level <= 1200) return 8;
    if (level <= 1500) return 9;
    if (level <= 1800) return 10;
    if (level <= 2100) return 11;
    if (level <= 2350) return 12;
    return 13;
  }

  static int _stackDepth(int level) {
    if (level <= 20) return 1;
    if (level <= 75) return 2;
    if (level <= 200) return 3;
    if (level <= 400) return 4;
    if (level <= 650) return 5;
    if (level <= 900) return 6;
    if (level <= 1200) return 7;
    if (level <= 1500) return 8;
    if (level <= 1800) return 9;
    if (level <= 2100) return 10;
    if (level <= 2350) return 11;
    return 12;
  }

  static int _emptySlots(int level) {
    if (level <= 100) return 4;
    if (level <= 400) return 3;
    if (level <= 1400) return 2;
    if (level <= 1800) return 1 + (level % 4 == 0 ? 1 : 0);
    return 1;
  }

  static double _complexity(int level, double curved) {
    final wave = sin(level * .37) * .035 + sin(level * .11) * .02;
    return (curved + wave).clamp(0.0, 1.0);
  }

  static int _productForGroup(
    int group,
    int itemTypes,
    Random random,
    double complexity,
  ) {
    if (complexity < .18) return group % itemTypes;
    final base = group % itemTypes;
    final offset = complexity < .45
        ? random.nextInt(itemTypes)
        : (random.nextInt(itemTypes) + group * 2) % itemTypes;
    return (base + offset) % itemTypes;
  }

  static void _shuffleWithComplexity(
    List<SortingItem> items,
    Random random,
    double complexity,
  ) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = items[i];
      items[i] = items[j];
      items[j] = temp;
    }

    if (complexity > .35) {
      for (var i = items.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        final temp = items[i];
        items[i] = items[j];
        items[j] = temp;
      }
    }
  }
}
