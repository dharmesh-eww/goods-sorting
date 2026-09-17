import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'game/goods_sorting_game_screen.dart';
import 'game/level_generator.dart';
import 'game/level_progress.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen>
    with TickerProviderStateMixin {
  static const totalLevels = LevelProgress.maxLevel;

  final progress = LevelProgress.instance;
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();
  late final ScrollController _scroll = ScrollController();

  bool loading = true;
  int selected = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await progress.load();
    if (!mounted) return;
    setState(() {
      selected = progress.currentLevel;
      loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  void _jumpToCurrent() {
    if (!_scroll.hasClients) return;
    final current = progress.currentLevel.clamp(1, totalLevels);
    final offset = ((current - 1) * 112.0).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE9A9),
              Color(0xFFFFD278),
              Color(0xFFE69245),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                level: progress.currentLevel,
                completed: progress.completedLevels.length,
                onBack: () => Navigator.pop(context),
                onCurrent: _jumpToCurrent,
              ),
              const SizedBox(height: 4),
              _JourneyHeader(
                current: progress.currentLevel,
                unlocked: progress.highestUnlockedLevel,
                completed: progress.completedLevels.length,
                animation: _intro,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
                  itemCount: totalLevels,
                  itemBuilder: (context, index) {
                    final number = index + 1;
                    final unlocked = progress.isUnlocked(number);
                    final completed = progress.isCompleted(number);
                    final current = progress.isCurrent(number);
                    final level = LevelGenerator.generate(number);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LevelCard(
                        number: number,
                        unlocked: unlocked,
                        completed: completed,
                        current: current,
                        selected: selected == number,
                        difficulty: _difficulty(level.difficulty),
                        itemTypes: level.itemTypes,
                        timerSeconds: level.timerSeconds,
                        onSelect: unlocked
                            ? () => setState(() => selected = number)
                            : null,
                        onPlay: unlocked ? () => _play(number) : null,
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

  Future<void> _play(int levelNumber) async {
    await progress.markLevelOpened(levelNumber);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoodsSortingGameScreen(levelNumber: levelNumber),
      ),
    );
    if (mounted) setState(() {});
  }

  String _difficulty(double value) {
    if (value < .08) return 'EASY';
    if (value < .28) return 'NORMAL';
    if (value < .58) return 'HARD';
    if (value < .82) return 'EXPERT';
    return 'MASTER';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.level,
    required this.completed,
    required this.onBack,
    required this.onCurrent,
  });

  final int level;
  final int completed;
  final VoidCallback onBack;
  final VoidCallback onCurrent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          _RoundButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: _panelDecoration(),
              child: Row(
                children: [
                  const Icon(
                    Icons.map_rounded,
                    color: Color(0xFF74431F),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LEVEL MAP',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: Color(0xFF643A1D),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$completed / $totalLevels',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF936A43),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _RoundButton(icon: Icons.my_location_rounded, onTap: onCurrent),
        ],
      ),
    );
  }
}

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({
    required this.current,
    required this.unlocked,
    required this.completed,
    required this.animation,
  });

  final int current;
  final int unlocked;
  final int completed;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: .96, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFCB50), Color(0xFFF28B11)],
                  ),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 7,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(7),
                child: SvgPicture.asset(
                  'assets/images/products/apple.svg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MARKET JOURNEY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                        color: Color(0xFF9B714B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Level $current is ready',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF633B1E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: unlocked / totalLevels,
                        backgroundColor: const Color(0xFFE2C79F),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFFFA914),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFFFA914),
                    size: 25,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$completed',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF71451F),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.number,
    required this.unlocked,
    required this.completed,
    required this.current,
    required this.selected,
    required this.difficulty,
    required this.itemTypes,
    required this.timerSeconds,
    this.onSelect,
    this.onPlay,
  });

  final int number;
  final bool unlocked;
  final bool completed;
  final bool current;
  final bool selected;
  final String difficulty;
  final int itemTypes;
  final int timerSeconds;
  final VoidCallback? onSelect;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final border = current
        ? const Color(0xFFFF8A00)
        : selected
            ? const Color(0xFFFFB52E)
            : Colors.white.withValues(alpha: .78);

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: unlocked
                ? const [Color(0xFFFFFCF2), Color(0xFFFFE3A7)]
                : const [Color(0xFFE1CDB0), Color(0xFFCDB18C)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: current ? 3 : 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0x45000000),
              blurRadius: current ? 12 : 7,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            _LevelBadge(
              number: number,
              unlocked: unlocked,
              completed: completed,
              current: current,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          current ? 'CURRENT LEVEL' : 'LEVEL $number',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .7,
                            color: Color(0xFF633B1E),
                          ),
                        ),
                      ),
                      _DifficultyPill(
                        label: difficulty,
                        enabled: unlocked,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        size: 15,
                        color: unlocked
                            ? const Color(0xFF9B6C42)
                            : const Color(0xFF8B745B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$itemTypes goods',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF99724D),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Icon(
                        Icons.timer_rounded,
                        size: 15,
                        color: unlocked
                            ? const Color(0xFF9B6C42)
                            : const Color(0xFF8B745B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timerSeconds == 0 ? 'NO TIMER' : '${timerSeconds}s',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF99724D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: completed ? 1 : current ? .08 : 0,
                      backgroundColor: const Color(0xFFD8C09D),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFFFA914),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            _PlayButton(
              enabled: unlocked,
              onTap: onPlay,
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.number,
    required this.unlocked,
    required this.completed,
    required this.current,
  });

  final int number;
  final bool unlocked;
  final bool completed;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 67,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: unlocked
              ? const [Color(0xFFFFCA4D), Color(0xFFF18A11)]
              : const [Color(0xFFB5A088), Color(0xFF8C765D)],
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 5,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            completed
                ? Icons.check_rounded
                : current
                    ? Icons.play_arrow_rounded
                    : unlocked
                        ? Icons.shopping_basket_rounded
                        : Icons.lock_rounded,
            color: Colors.white,
            size: 20,
          ),
          Text(
            '$number',
            style: const TextStyle(
              fontSize: 22,
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

class _DifficultyPill extends StatelessWidget {
  const _DifficultyPill({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xFFFFF2D0)
            : const Color(0xFFD8C2A5),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: enabled
              ? const Color(0xFFFFC45A)
              : const Color(0xFFC1A786),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
          color: enabled
              ? const Color(0xFF9B641D)
              : const Color(0xFF806C57),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? const [Color(0xFFFFC94B), Color(0xFFF28C12)]
                  : const [Color(0xFFB6A089), Color(0xFF8D775E)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D000000),
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            enabled ? Icons.play_arrow_rounded : Icons.lock_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

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
          child: Icon(
            icon,
            color: const Color(0xFF633B1E),
            size: 23,
          ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration() => BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFCF3), Color(0xFFFFE2A7)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x3D000000),
          blurRadius: 9,
          offset: Offset(0, 5),
        ),
      ],
    );
