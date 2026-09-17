import 'dart:math' as math;

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

class _GoodsSortingGameScreenState extends State<GoodsSortingGameScreen>
    with TickerProviderStateMixin {
  late SortingLevel level;
  late AnimationController introController;
  late AnimationController floatController;
  final List<SortingItem> tray = [];
  final Set<int> matchedProductIds = {};
  final Set<String> removedItems = {};
  bool busy = false;
  bool paused = false;
  int moves = 0;
  int score = 0;

  @override
  void initState() {
    super.initState();
    _loadLevel();
    introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  void _loadLevel() {
    level = LevelGenerator.generate(widget.levelNumber);
    tray.clear();
    matchedProductIds.clear();
    removedItems.clear();
    moves = 0;
    score = 0;
    busy = false;
    paused = false;
  }

  @override
  void dispose() {
    introController.dispose();
    floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shelves = List.generate(
      level.shelfCount,
      (index) => level.items
          .where((item) => item.shelfIndex == index && !_isRemoved(item))
          .toList(),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE9B0), Color(0xFFFFC95C), Color(0xFFE58138)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _GameHeader(
                level: level,
                score: score,
                onBack: () => Navigator.pop(context),
                onPause: _showPause,
              ),
              _ProgressBar(
                total: level.totalItems,
                remaining: level.totalItems - removedItems.length,
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: introController,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, 20 * (1 - introController.value)),
                    child: Opacity(opacity: introController.value, child: child),
                  ),
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    itemCount: shelves.length,
                    itemBuilder: (context, index) => _Shelf(
                      key: ValueKey('shelf-$index-${level.levelNumber}'),
                      items: shelves[index],
                      shelfNumber: index + 1,
                      maxDepth: level.maxStackDepth,
                      floatAnimation: floatController,
                      onItemTap: _selectItem,
                    ),
                  ),
                ),
              ),
              _Tray(
                items: tray,
                maxSlots: 7,
                onItemTap: _removeFromTray,
              ),
              _GameActions(
                moves: moves,
                onShuffle: _shuffle,
                onReset: _resetLevel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isRemoved(SortingItem item) => removedItems.contains(_itemKey(item));

  String _itemKey(SortingItem item) =>
      '${item.productId}-${item.shelfIndex}-${item.stackIndex}-${level.items.indexOf(item)}';

  void _selectItem(SortingItem item) {
    if (busy || paused || _isRemoved(item)) return;
    if (tray.length >= 7) return;

    setState(() {
      removedItems.add(_itemKey(item));
      tray.add(item);
      moves++;
    });
    _checkMatch(item.productId);
    _checkLose();
  }

  void _removeFromTray(SortingItem item) {
    if (busy || paused) return;
    setState(() => tray.remove(item));
  }

  Future<void> _checkMatch(int productId) async {
    final matches = tray.where((item) => item.productId == productId).toList();
    if (matches.length < 3 || busy) return;

    busy = true;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    setState(() {
      for (final item in matches.take(3)) {
        tray.remove(item);
      }
      matchedProductIds.add(productId);
      score += 30;
    });

    await Future<void>.delayed(const Duration(milliseconds: 180));
    busy = false;
    if (!mounted) return;
    if (removedItems.length >= level.totalItems) {
      _showWin();
    } else {
      setState(() {});
    }
  }

  void _checkLose() {
    if (tray.length >= 7 && !busy) {
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (mounted && tray.length >= 7 && !busy) _showLose();
      });
    }
  }

  void _resetLevel() {
    setState(_loadLevel);
    introController.forward(from: 0);
  }

  void _shuffle() {
    if (busy || paused) return;
    setState(() {
      final generated = LevelGenerator.generate(widget.levelNumber + moves + 1);
      final available = generated.items.take(level.items.length).toList();
      for (var i = 0; i < math.min(level.items.length, available.length); i++) {
        level.items[i];
      }
    });
  }

  void _showPause() {
    setState(() => paused = true);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (sheetContext) => _PauseSheet(
        onResume: () {
          Navigator.pop(sheetContext);
          if (mounted) setState(() => paused = false);
        },
        onRestart: () {
          Navigator.pop(sheetContext);
          if (mounted) _resetLevel();
        },
      ),
    ).whenComplete(() {
      if (mounted) setState(() => paused = false);
    });
  }

  void _showWin() {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResultSheet(
        win: true,
        level: widget.levelNumber,
        score: score,
        onNext: () {
          Navigator.pop(context);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => GoodsSortingGameScreen(
                  levelNumber: widget.levelNumber + 1,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showLose() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResultSheet(
        win: false,
        level: widget.levelNumber,
        score: score,
        onNext: () {
          Navigator.pop(context);
          _resetLevel();
        },
      ),
    );
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({required this.level, required this.score, required this.onBack, required this.onPause});
  final SortingLevel level;
  final int score;
  final VoidCallback onBack;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 5),
      child: Row(
        children: [
          _RoundButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LEVEL ${level.levelNumber}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: Color(0xFF5F3A1D))),
            Text(_difficultyName(level.difficulty), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: Color(0xFF956A40))),
          ])),
          _ScoreChip(score: score),
          const SizedBox(width: 7),
          _RoundButton(icon: Icons.pause_rounded, onTap: onPause),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.total, required this.remaining});
  final int total;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : (1 - remaining / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
      child: Row(children: [
        const Icon(Icons.shopping_basket_rounded, size: 17, color: Color(0xFF9B632E)),
        const SizedBox(width: 7),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: const Color(0x66FFFFFF), valueColor: const AlwaysStoppedAnimation(Color(0xFFF28B16))))),
        const SizedBox(width: 8),
        Text('$remaining', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF633E20))),
      ]),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({super.key, required this.items, required this.shelfNumber, required this.maxDepth, required this.floatAnimation, required this.onItemTap});
  final List<SortingItem> items;
  final int shelfNumber;
  final int maxDepth;
  final Animation<double> floatAnimation;
  final ValueChanged<SortingItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFDF4), Color(0xFFFFE3A6)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x45000000), blurRadius: 9, offset: Offset(0, 6))],
      ),
      child: Row(children: [
        Container(width: 30, alignment: Alignment.center, child: Text('$shelfNumber', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF9A7048)))),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final itemSize = math.min(58.0, math.max(46.0, constraints.maxWidth / math.max(1, math.min(5, items.length)) - 3));
          final columns = math.max(1, (constraints.maxWidth / itemSize).floor());
          return Stack(children: [
            Positioned(left: 0, right: 0, bottom: 5, child: Container(height: 9, decoration: BoxDecoration(color: const Color(0xFFAD6B2E), borderRadius: BorderRadius.circular(7), boxShadow: const [BoxShadow(color: Color(0x35000000), blurRadius: 2, offset: Offset(0, 2))]))),
            ...items.asMap().entries.map((entry) {
              final item = entry.value;
              final column = entry.key % columns;
              final row = entry.key ~/ columns;
              final depth = math.min(item.stackIndex, maxDepth - 1);
              return Positioned(left: column * itemSize, bottom: 10 + depth * 6.0 - row * 3.0, child: AnimatedBuilder(animation: floatAnimation, builder: (_, child) => Transform.translate(offset: Offset(0, math.sin(floatAnimation.value * math.pi) * (1.5 + depth * .2)), child: child), child: _ProductCard(item: item, size: itemSize, onTap: () => onItemTap(item))));
            }),
          ]);
        })),
      ]),
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({required this.item, required this.size, required this.onTap});
  final SortingItem item;
  final double size;
  final VoidCallback onTap;
  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => pressed = true),
      onTapUp: (_) { setState(() => pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => pressed = false),
      child: AnimatedScale(
        scale: pressed ? .86 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Container(
          width: widget.size - 3,
          height: widget.size - 3,
          padding: EdgeInsets.all(widget.size * .105),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFF6E9CD)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFC24A), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x3B000000), blurRadius: 5, offset: Offset(0, 4))],
          ),
          child: SvgPicture.asset(widget.item.asset),
        ),
      ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({required this.items, required this.maxSlots, required this.onItemTap});
  final List<SortingItem> items;
  final int maxSlots;
  final ValueChanged<SortingItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8A4C25), Color(0xFF673619)]),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFFFD37B), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 9, offset: Offset(0, 5))],
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.inventory_2_rounded, size: 17, color: Color(0xFFFFD37B)),
          const SizedBox(width: 6),
          const Expanded(child: Text('MATCH TRAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white))),
          Text('${items.length}/$maxSlots', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFFFE4A8))),
        ]),
        const SizedBox(height: 6),
        SizedBox(height: 54, child: Row(children: List.generate(maxSlots, (index) {
          final item = index < items.length ? items[index] : null;
          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child), child: item == null ? Container(key: ValueKey('empty-$index'), decoration: BoxDecoration(color: const Color(0x30502A12), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x50FFD37B)))) : GestureDetector(key: ValueKey('item-${item.productId}-${index}'), onTap: () => onItemTap(item), child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFC24A), width: 2)), child: SvgPicture.asset(item.asset)))));
        })));
      ]),
    );
  }
}

class _GameActions extends StatelessWidget {
  const _GameActions({required this.moves, required this.onShuffle, required this.onReset});
  final int moves;
  final VoidCallback onShuffle;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10), child: Row(children: [
      Expanded(child: _ActionButton(icon: Icons.shuffle_rounded, label: 'SHUFFLE', onTap: onShuffle)),
      const SizedBox(width: 8),
      Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 13), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white, width: 2)), child: Center(child: Text('$moves MOVES', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF633E20)))),
      const SizedBox(width: 8),
      _ActionButton(icon: Icons.refresh_rounded, label: 'RESET', onTap: onReset),
    ]));
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(17), elevation: 3, child: InkWell(borderRadius: BorderRadius.circular(17), onTap: onTap, child: SizedBox(height: 48, width: 92, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18, color: const Color(0xFF7A4A25)), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF633E20)))])));
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.white.withValues(alpha: .94), shape: const CircleBorder(), elevation: 4, child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: const SizedBox(width: 44, height: 44, child: Icon(Icons.circle, color: Colors.transparent)).copyWithIcon(icon)));
}

extension on SizedBox {
  Widget copyWithIcon(IconData icon) => Center(child: Icon(icon, color: const Color(0xFF633E20)));
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.score});
  final int score;
  @override
  Widget build(BuildContext context) => Container(height: 38, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(19), boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 5, offset: Offset(0, 2))]), child: Row(children: [const Icon(Icons.stars_rounded, size: 18, color: Color(0xFFF19A16)), const SizedBox(width: 4), Text('$score', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF633E20)))]));
}

class _PauseSheet extends StatelessWidget {
  const _PauseSheet({required this.onResume, required this.onRestart});
  final VoidCallback onResume;
  final VoidCallback onRestart;
  @override
  Widget build(BuildContext context) => _SheetShell(icon: Icons.pause_rounded, title: 'GAME PAUSED', subtitle: 'Take a breath and continue when ready.', children: [
    _LargeSheetButton(label: 'CONTINUE', icon: Icons.play_arrow_rounded, onTap: onResume),
    const SizedBox(height: 10),
    _LargeSheetButton(label: 'RESTART LEVEL', icon: Icons.refresh_rounded, onTap: onRestart, secondary: true),
  ]);
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.win, required this.level, required this.score, required this.onNext});
  final bool win;
  final int level;
  final int score;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => _SheetShell(icon: win ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded, title: win ? 'LEVEL COMPLETE!' : 'TRY AGAIN', subtitle: win ? 'Level $level sorted perfectly.' : 'Your tray is full. Make a new attempt.', children: [
    if (win) Text('$score POINTS', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFE28A14))),
    if (win) const SizedBox(height: 10),
    _LargeSheetButton(label: win ? 'NEXT LEVEL' : 'TRY AGAIN', icon: win ? Icons.arrow_forward_rounded : Icons.refresh_rounded, onTap: onNext),
  ]);
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.icon, required this.title, required this.subtitle, required this.children});
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 25), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFFCF2), Color(0xFFFFD983)], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: BorderRadius.vertical(top: Radius.circular(30))), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFB88854), borderRadius: BorderRadius.circular(5))), const SizedBox(height: 15), Container(width: 58, height: 58, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFFFC94D), Color(0xFFF28B13)]), border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Color(0x35000000), blurRadius: 7, offset: Offset(0, 4))]), child: Icon(icon, color: Colors.white, size: 30)), const SizedBox(height: 10), Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF633E20))), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8B6949))), const SizedBox(height: 18), ...children]));
}

class _LargeSheetButton extends StatelessWidget {
  const _LargeSheetButton({required this.label, required this.icon, required this.onTap, this.secondary = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool secondary;
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 54, child: Material(color: secondary ? Colors.white.withValues(alpha: .9) : null, borderRadius: BorderRadius.circular(18), child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Ink(decoration: BoxDecoration(gradient: secondary ? null : const LinearGradient(colors: [Color(0xFFFFC94B), Color(0xFFF28B12)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white, width: 2)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: secondary ? const Color(0xFF633E20) : Colors.white), const SizedBox(width: 7), Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: secondary ? const Color(0xFF633E20) : Colors.white))]))));
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
