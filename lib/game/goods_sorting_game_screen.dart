import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'level_data.dart';
import 'level_generator.dart';
import 'sorting_item.dart';

class GoodsSortingGameScreen extends StatefulWidget {
  const GoodsSortingGameScreen({super.key, required this.levelNumber});

  final int levelNumber;

  @override
  State<GoodsSortingGameScreen> createState() => _GoodsSortingGameScreenState();
}

class _GoodsSortingGameScreenState extends State<GoodsSortingGameScreen> {
  late SortingLevel level;
  final selected = <int>[];

  @override
  void initState() {
    super.initState();
    level = LevelGenerator.generate(widget.levelNumber);
  }

  @override
  Widget build(BuildContext context) {
    final shelves = List.generate(
      level.shelfCount,
      (index) => level.items.where((item) => item.shelfIndex == index).toList(),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE8A8), Color(0xFFFFCD6E), Color(0xFFE78C3D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _GameHeader(level: level, onBack: () => Navigator.pop(context)),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: shelves.length,
                  itemBuilder: (context, index) => _Shelf(
                    items: shelves[index],
                    shelfNumber: index + 1,
                    onItemTap: _selectItem,
                  ),
                ),
              ),
              _GameFooter(
                emptySlots: level.emptySlots,
                selectedCount: selected.length,
                onReset: () => setState(() => selected.clear()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectItem(int productId) {
    setState(() {
      if (selected.contains(productId)) {
        selected.remove(productId);
      } else {
        selected.add(productId);
      }
    });
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({required this.level, required this.onBack});

  final SortingLevel level;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _CircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEVEL ${level.levelNumber}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Color(0xFF633E20),
                  ),
                ),
                Text(
                  _difficultyName(level.difficulty),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF97704B),
                  ),
                ),
              ],
            ),
          ),
          _Chip(icon: Icons.favorite_rounded, text: '5'),
          const SizedBox(width: 6),
          _Chip(icon: Icons.lightbulb_rounded, text: '3'),
        ],
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.items,
    required this.shelfNumber,
    required this.onItemTap,
  });

  final List<SortingItem> items;
  final int shelfNumber;
  final ValueChanged<int> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF9E9), Color(0xFFFFE5AD)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45000000),
            blurRadius: 8,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$shelfNumber',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF9A7048),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = 58.0;
                final columns = max(
                  1,
                  (constraints.maxWidth / itemWidth).floor(),
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 5,
                      child: Container(
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB87532),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    ...items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final column = index % columns;
                      return Positioned(
                        left: column * itemWidth,
                        bottom: 12 + item.stackIndex * 7.0,
                        child: GestureDetector(
                          onTap: () => onItemTap(item.productId),
                          child: Container(
                            width: 54,
                            height: 54,
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xFFFFC24A),
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x30000000),
                                  blurRadius: 5,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: SvgPicture.asset(item.asset),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GameFooter extends StatelessWidget {
  const _GameFooter({
    required this.emptySlots,
    required this.selectedCount,
    required this.onReset,
  });

  final int emptySlots;
  final int selectedCount;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 15),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: Color(0xFFF19A16)),
                  const SizedBox(width: 8),
                  Text(
                    '$selectedCount selected',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF633E20),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$emptySlots empty',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF97704B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          _CircleButton(icon: Icons.refresh_rounded, onTap: onReset),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .94),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 45,
          height: 45,
          child: Icon(icon, color: const Color(0xFF633E20)),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFFF19A16)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF633E20),
            ),
          ),
        ],
      ),
    );
  }
}

String _difficultyName(double value) {
  if (value < .04) return 'VERY EASY';
  if (value < .15) return 'EASY';
  if (value < .30) return 'NORMAL';
  if (value < .48) return 'MEDIUM';
  if (value < .65) return 'HARD';
  if (value < .80) return 'ADVANCED';
  if (value < .92) return 'EXPERT';
  return 'MASTER';
}

int max(int a, int b) => a > b ? a : b;
