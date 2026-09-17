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

    // Every group is exactly three products. Keep the number of groups below
    // the physical shelf capacity so every generated board is valid.
    final capacity = shelfCount * maxStackDepth;
    final maxGroups = max(1, (capacity - emptySlots).clamp(3, capacity) ~/ 3);
    final targetGroups = max(2, min(maxGroups, shelfCount + level ~/ 180));

    final shelves = List.generate(shelfCount, (_) => <int>[]);

    for (var group = 0; group < targetGroups; group++) {
      final productId = _productForGroup(group, itemTypes, random, complexity);
      final copies = List<int>.filled(3, productId);

      // Spread a triple across different shelves when the level is easy and
      // increasingly cluster it on deeper shelves as difficulty rises.
      for (var copy = 0; copy < copies.length; copy++) {
        final candidates = List<int>.generate(shelfCount, (index) => index)
          ..shuffle(random);
        candidates.sort((a, b) => shelves[a].length.compareTo(shelves[b].length));

        var shelf = candidates.first;
        if (complexity > .35 && random.nextDouble() < complexity) {
          final window = min(candidates.length, max(1, 2 + (complexity * shelfCount).floor()));
          shelf = candidates[random.nextInt(window)];
        }

        shelves[shelf].add(productId);
      }
    }

    // Harder boards get more irregular ordering inside each stack.
    if (complexity > .25) {
      for (final stack in shelves) {
        for (var i = stack.length - 1; i > 0; i--) {
          final j = random.nextInt(i + 1);
          final value = stack[i];
          stack[i] = stack[j];
          stack[j] = value;
        }
      }
    }

    final items = <SortingItem>[];
    for (var shelfIndex = 0; shelfIndex < shelves.length; shelfIndex++) {
      final stack = shelves[shelfIndex];
      for (var stackIndex = 0; stackIndex < stack.length; stackIndex++) {
        final productId = stack[stackIndex];
        items.add(
          SortingItem(
            productId: productId,
            asset: products[productId],
            stackIndex: stackIndex,
            shelfIndex: shelfIndex,
          ),
        );
      }
    }

    return SortingLevel(
      levelNumber: level,
      difficulty: progress,
      itemTypes: itemTypes,
      shelfCount: shelfCount,
      maxStackDepth: maxStackDepth,
      emptySlots: emptySlots,
      complexity: complexity,
      items: List.unmodifiable(items),
    );
  }

  static double _smooth(double value) => value * value * (3 - 2 * value);

  static int _itemTypes(int level) {
    if (level <= 10) return 3;
    if (level <= 40) return 4;
    if (level <= 100) return 5;
    if (level <= 200) return 6;
    return 7;
  }

  static int _shelfCount(int level) {
    if (level <= 30) return 3;
    if (level <= 100) return 4;
    if (level <= 250) return 5;
    if (level <= 450) return 6;
    if (level <= 700) return 7;
    if (level <= 950) return 8;
    if (level <= 1200) return 9;
    if (level <= 1500) return 10;
    if (level <= 1800) return 11;
    if (level <= 2100) return 12;
    if (level <= 2350) return 13;
    return 14;
  }

  static int _stackDepth(int level) {
    if (level <= 20) return 3;
    if (level <= 75) return 4;
    if (level <= 200) return 5;
    if (level <= 400) return 6;
    if (level <= 650) return 7;
    if (level <= 900) return 8;
    if (level <= 1200) return 9;
    if (level <= 1500) return 10;
    if (level <= 1800) return 11;
    if (level <= 2100) return 12;
    if (level <= 2350) return 13;
    return 14;
  }

  static int _emptySlots(int level) {
    if (level <= 100) return 2;
    if (level <= 400) return 2;
    if (level <= 1400) return 1;
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
}
