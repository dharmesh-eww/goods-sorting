import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'game/goods_sorting_game_screen.dart';
import 'game/level_generator.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  int selected = 1;
  static const totalLevels = 2500;
  static const highestUnlockedLevel = 3;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE8A8),
              Color(0xFFFFCD6E),
              Color(0xFFE78C3D),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(onBack: () => Navigator.pop(context)),
              _Journey(controller: controller),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  itemCount: totalLevels,
                  itemBuilder: (context, index) {
                    final levelNumber = index + 1;
                    final level = LevelGenerator.generate(levelNumber);
                    final unlocked = levelNumber <= highestUnlockedLevel;
                    final animation = CurvedAnimation(
                      parent: controller,
                      curve: Interval(
                        (index * .07).clamp(0.0, .5),
                        ((index * .07) + .45).clamp(.45, 1.0),
                        curve: Curves.easeOutBack,
                      ),
                    );

                    return AnimatedBuilder(
                      animation: animation,
                      builder: (_, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - animation.value)),
                          child: Opacity(
                            opacity: animation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: _LevelTile(
                          number: levelNumber,
                          unlocked: unlocked,
                          selected: selected == levelNumber,
                          difficulty: _difficultyName(level.difficulty),
                          progress: levelNumber <= 3
                              ? const [0.92, 0.68, 0.42][levelNumber - 1]
                              : 0,
                          stars: levelNumber <= 3 ? 4 - levelNumber : 0,
                          onTap: unlocked
                              ? () => setState(() => selected = levelNumber)
                              : null,
                          onPlay: unlocked
                              ? () => _play(context, levelNumber)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _play(BuildContext context, int levelNumber) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoodsSortingGameScreen(levelNumber: levelNumber),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 7),
      child: Row(
        children: [
          _CircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'LEVELS',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Color(0xFF623D1F),
              ),
            ),
          ),
          _Resource(asset: 'assets/images/products/apple.svg', value: '1,250'),
          const SizedBox(width: 7),
          _Resource(icon: Icons.favorite_rounded, value: '5'),
        ],
      ),
    );
  }
}

class _Journey extends StatelessWidget {
  const _Journey({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext c) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        return Transform.scale(
          scale: .95 + .05 * controller.value,
          child: Opacity(opacity: controller.value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 3, 18, 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBF0), Color(0xFFFFE1A1)],
          ),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 11,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 55,
              height: 55,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB52E),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: SvgPicture.asset('assets/images/products/apple.svg'),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MARKET JOURNEY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Color(0xFF97704B),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '2,500 levels • Easy to Master',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF633E20),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFFFA914),
              size: 27,
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.number,
    required this.unlocked,
    required this.selected,
    required this.difficulty,
    required this.progress,
    required this.stars,
    this.onTap,
    this.onPlay,
  });

  final int number;
  final bool unlocked;
  final bool selected;
  final String difficulty;
  final double progress;
  final int stars;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext c) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: unlocked
                ? const [Color(0xFFFFFCF2), Color(0xFFFFE4AB)]
                : const [Color(0xFFE5D0B0), Color(0xFFD1B38B)],
          ),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: selected
                ? const Color(0xFFFFA914)
                : Colors.white.withValues(alpha: .75),
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x50000000),
              blurRadius: selected ? 13 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _Badge(number: number, unlocked: unlocked),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$difficulty • Level $number',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: unlocked
                                ? const Color(0xFF633E20)
                                : const Color(0xFF806B54),
                          ),
                        ),
                      ),
                      unlocked
                          ? _Stars(count: stars)
                          : const Icon(
                              Icons.lock_rounded,
                              color: Color(0xFF8D765D),
                              size: 20,
                            ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: progress,
                      backgroundColor: const Color(0xFFD8C09D),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFFFA914),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    unlocked
                        ? '${(progress * 100).round()}% complete'
                        : 'Complete previous level',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF98724C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            _Play(enabled: unlocked, onTap: onPlay),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.number, required this.unlocked});

  final int number;
  final bool unlocked;

  @override
  Widget build(BuildContext c) {
    return Container(
      width: 62,
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: unlocked
              ? const [Color(0xFFFFCA4C), Color(0xFFF18A11)]
              : const [Color(0xFFB8A38A), Color(0xFF8D775E)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x50000000),
            blurRadius: 5,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            unlocked
                ? Icons.shopping_basket_rounded
                : Icons.lock_rounded,
            color: Colors.white,
            size: 21,
          ),
          Text(
            '$number',
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Play extends StatefulWidget {
  const _Play({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  State<_Play> createState() => _PlayState();
}

class _PlayState extends State<_Play> {
  bool down = false;

  @override
  Widget build(BuildContext c) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => down = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => down = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: widget.enabled
          ? () => setState(() => down = false)
          : null,
      child: AnimatedScale(
        scale: down ? .9 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.enabled
                  ? const [Color(0xFFFFC94B), Color(0xFFF28C12)]
                  : const [Color(0xFFB9A48B), Color(0xFF8F795F)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            widget.enabled
                ? Icons.play_arrow_rounded
                : Icons.lock_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.count});

  final int count;

  @override
  Widget build(BuildContext c) {
    return Row(
      children: List.generate(
        3,
        (i) => Icon(
          i < count ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 18,
          color: i < count
              ? const Color(0xFFFFB21B)
              : const Color(0xFFB89B78),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext c) {
    return Material(
      color: Colors.white.withValues(alpha: .92),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 45,
          height: 45,
          child: Icon(icon, color: const Color(0xFF633E20), size: 24),
        ),
      ),
    );
  }
}

class _Resource extends StatelessWidget {
  const _Resource({this.asset, this.icon, required this.value});

  final String? asset;
  final IconData? icon;
  final String value;

  @override
  Widget build(BuildContext c) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (asset != null)
            SizedBox(
              width: 24,
              height: 24,
              child: SvgPicture.asset(asset!),
            )
          else
            Icon(icon, size: 19, color: const Color(0xFFF05D62)),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
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
