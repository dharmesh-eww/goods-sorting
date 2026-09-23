import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LevelCompleteScreen extends StatefulWidget {
  const LevelCompleteScreen({
    super.key,
    required this.levelNumber,
    required this.score,
    required this.moves,
    required this.earnedCoins,
    required this.onNext,
    required this.onLevels,
  });

  final int levelNumber;
  final int score;
  final int moves;
  final int earnedCoins;
  final VoidCallback onNext;
  final VoidCallback onLevels;

  @override
  State<LevelCompleteScreen> createState() => _LevelCompleteScreenState();
}

class _LevelCompleteScreenState extends State<LevelCompleteScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final AnimationController _celebration = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _entrance.dispose();
    _celebration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF180D08), Color(0xFF5A2E16), Color(0xFFD27B2B)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _celebration,
                builder: (_, __) => CustomPaint(
                  painter: _CelebrationPainter(_celebration.value),
                ),
              ),
            ),
            SafeArea(
              child: AnimatedBuilder(
                animation: _entrance,
                builder: (_, child) {
                  final curve = CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack);
                  return FadeTransition(
                    opacity: _entrance,
                    child: Transform.translate(
                      offset: Offset(0, 28 * (1 - curve.value)),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                  child: Column(
                    children: [
                      const Spacer(),
                      SvgPicture.asset('assets/images/result/party_popper.svg', width: 70, height: 70),
                      const SizedBox(height: 4),
                      _Bounce(
                        controller: _celebration,
                        child: SvgPicture.asset('assets/images/result/trophy.svg', width: 118, height: 118),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'LEVEL COMPLETE!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: .5,
                          shadows: [Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 4))],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Great sorting! The shelf is clean.',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: .82)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: _Star(controller: _celebration, delay: i * .12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ResultCard(
                        level: widget.levelNumber,
                        score: widget.score,
                        moves: widget.moves,
                        earnedCoins: widget.earnedCoins,
                      ),
                      const Spacer(),
                      _PrimaryButton(
                        label: 'NEXT LEVEL',
                        icon: Icons.arrow_forward_rounded,
                        onTap: widget.onNext,
                      ),
                      const SizedBox(height: 9),
                      TextButton(
                        onPressed: widget.onLevels,
                        child: const Text(
                          'LEVEL SELECTION',
                          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFE2B5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bounce extends StatelessWidget {
  const _Bounce({required this.controller, required this.child});

  final Animation<double> controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (_, child) {
        final wave = controller.value * 2 * 3.1415926535;
        final scale = 1 + .035 * (1 + _sine(wave)) / 2;
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

double _sine(double value) {
  var x = value % (2 * 3.1415926535);
  if (x > 3.1415926535) x -= 2 * 3.1415926535;
  final x2 = x * x;
  return x * (1 - x2 / 6 + x2 * x2 / 120);
}

class _Star extends StatelessWidget {
  const _Star({required this.controller, required this.delay});

  final Animation<double> controller;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        var value = (controller.value - delay) % 1;
        if (value < 0) value += 1;
        final pulse = value < .25 ? value / .25 : 1 - ((value - .25) / .75).clamp(0, 1);
        return Transform.scale(
          scale: .86 + .14 * pulse,
          child: SvgPicture.asset('assets/images/result/star.svg', width: 42, height: 42),
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.level,
    required this.score,
    required this.moves,
    required this.earnedCoins,
  });

  final int level;
  final int score;
  final int moves;
  final int earnedCoins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xDDFFF0D0),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5A45B), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 7))],
      ),
      child: Row(
        children: [
          _Stat('LEVEL', '$level'),
          _Stat('SCORE', '$score'),
          _Stat('MOVES', '$moves'),
          _Stat('COINS', '+$earnedCoins'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF98643B))),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF633514)),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: .7)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFA329),
          foregroundColor: Colors.white,
          elevation: 7,
          shadowColor: const Color(0x99000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
            side: const BorderSide(color: Color(0xFFFFD98E)),
          ),
        ),
      ),
    );
  }
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const particles = <Offset>[
      Offset(.08, .12), Offset(.18, .24), Offset(.29, .08), Offset(.42, .19),
      Offset(.58, .09), Offset(.71, .21), Offset(.84, .11), Offset(.93, .27),
      Offset(.12, .52), Offset(.88, .55),
    ];
    const colors = <Color>[
      Color(0xFFFFD45C), Color(0xFFFF8A3D), Color(0xFF78D6FF), Color(0xFFFF6D91),
    ];

    for (var i = 0; i < particles.length; i++) {
      final p = particles[i];
      final fall = (progress + i * .07) % 1;
      final x = p.dx * size.width + (i.isEven ? 10 : -10) * fall;
      final y = (p.dy + .72 * fall) * size.height;
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: .8);
      canvas.drawCircle(Offset(x, y), 2.5 + (i % 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) => oldDelegate.progress != progress;
}
