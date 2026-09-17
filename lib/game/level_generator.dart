import 'dart:math';

import 'level_data.dart';
import 'sorting_item.dart';
import 'level_progress.dart';

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

    // The game transitions directly from a completed level to the next level.
    // Sync the previous level here so the persisted progress is already updated
    // when the player reaches the next board.
    _syncProgressForNextLevel(level);

    final progress = ((level - 1) / 2499.0).clamp(0.0, 1.0);
    final difficulty = _smooth(progress);
    final random = Random(104729 + level * 7919);
    final itemTypes = _itemTypes(level);
    final shelfCount = _shelfCount(level);
    final maxStackDepth = _stackDepth(level);
    final emptySlots = _emptySlots(level);
    final complexity = _complexity(level, difficulty);
    final capacity = shelfCount * maxStackDepth;
    final maxGroups = max(1, ((capacity - emptySlots) ~/ 3));
    final minGroups = min(2 + (level % 3), maxGroups);
    final extraGroups = maxGroups > minGroups
        ? random.nextInt(maxGroups - minGroups + 1)
        : 0;
    final targetGroups = min(maxGroups, minGroups + extraGroups);
    final shelves = List.generate(shelfCount, (_) => <int>[]);

    for (var group = 0; group < targetGroups; group++) {
      final productId =
          _productForGroup(group, itemTypes, random, complexity, level);
      for (var copy = 0; copy < 3; copy++) {
        final candidates = List<int>.generate(shelfCount, (i) => i);
        candidates.shuffle(random);
        candidates.sort(
          (a, b) => shelves[a].length.compareTo(shelves[b].length),
        );
        final spread = max(
          1,
          min(candidates.length, 2 + (complexity * shelfCount).floor()),
        );
        final shelf = candidates[random.nextInt(spread)];
        shelves[shelf].add(productId);
      }
    }

    for (final stack in shelves) {
      for (var i = stack.length - 1; i > 0; i--) {
        if (complexity > .12 || random.nextBool()) {
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

  static void _syncProgressForNextLevel(int level) {
    final progress = LevelProgress.instance;
    if (level == progress.highestUnlockedLevel + 1 &&
        level <= LevelProgress.maxLevel) {
      // Fire-and-forget persistence is intentional here because level
      // generation is synchronous and must not block the first frame.
      progress.markCompleted(level - 1);
    }
  }

  static double _smooth(double value) => value * value * (3 - 2 * value);

  static int _itemTypes(int level) {
    if (level <= 8) return 3;
    if (level <= 35) return 4;
    if (level <= 100) return 5;
    if (level <= 200) return 6;
    return 7;
  }

  static int _shelfCount(int level) {
    if (level <= 5) return 2;
    if (level <= 20) return 3;
    if (level <= 60) return 4;
    if (level <= 150) return 5;
    if (level <= 300) return 6;
    if (level <= 550) return 7;
    if (level <= 850) return 8;
    if (level <= 1150) return 9;
    if (level <= 1450) return 10;
    if (level <= 1750) return 11;
    if (level <= 2050) return 12;
    if (level <= 2350) return 13;
    return 14;
  }

  static int _stackDepth(int level) {
    if (level <= 5) return 3;
    if (level <= 20) return 4;
    if (level <= 60) return 5;
    if (level <= 150) return 6;
    if (level <= 300) return 7;
    if (level <= 550) return 8;
    if (level <= 850) return 9;
    if (level <= 1150) return 10;
    if (level <= 1450) return 11;
    if (level <= 1750) return 12;
    if (level <= 2050) return 13;
    return 14;
  }

  static int _emptySlots(int level) => level <= 100 ? 2 : 1;

  static double _complexity(int level, double curved) =>
      (curved + sin(level * .37) * .035 + sin(level * .11) * .02)
          .clamp(0.0, 1.0);

  static int _productForGroup(
    int group,
    int itemTypes,
    Random random,
    double complexity,
    int level,
  ) {
    // Mix the deterministic level seed into early boards too. This prevents
    // levels 1-10 from looking like copies of the same board.
    final base = (group + level * 3) % itemTypes;
    final offset = complexity < .18
        ? random.nextInt(itemTypes)
        : (random.nextInt(itemTypes) + group * 2) % itemTypes;
    return (base + offset) % itemTypes;
  }
}
