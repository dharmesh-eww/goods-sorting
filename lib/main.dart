import 'package:flutter/material.dart';

void main() {
  runApp(const GoodsSortingApp());
}

class GoodsSortingApp extends StatelessWidget {
  const GoodsSortingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Goods Sorting',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFB72B)),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
              Color(0xFFFFD47A),
              Color(0xFFF4A64A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const _HomeHeader(),
              Expanded(
                child: Stack(
                  children: [
                    const Positioned.fill(child: _StoreScene()),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 28,
                      child: _LevelCard(
                        onPlay: () {},
                      ),
                    ),
                  ],
                ),
              ),
              const _BottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _RoundButton(
            icon: Icons.person_rounded,
            onTap: () {},
          ),
          const Spacer(),
          const _CurrencyChip(
            icon: Icons.monetization_on_rounded,
            value: '1,250',
          ),
          const SizedBox(width: 8),
          const _CurrencyChip(
            icon: Icons.favorite_rounded,
            value: '5',
          ),
          const SizedBox(width: 8),
          _RoundButton(
            icon: Icons.settings_rounded,
            onTap: () {},
          ),
        ],
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
      color: Colors.white.withValues(alpha: 0.88),
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: const Color(0xFF5B3A20), size: 24),
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 5,
            offset: Offset(0, 2),
            color: Color(0x33000000),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFFA800), size: 22),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5B3A20),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreScene extends StatelessWidget {
  const _StoreScene();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 170),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF4D5), Color(0xFFFFDFA0)],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 3,
                ),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 14,
                    offset: Offset(0, 7),
                    color: Color(0x33000000),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 22,
            left: 26,
            right: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _FeatureBubble(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Daily',
                  onTap: () {},
                ),
                _FeatureBubble(
                  icon: Icons.emoji_events_rounded,
                  label: 'Awards',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const Positioned(
            top: 82,
            child: Text(
              'MY MARKET',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Color(0xFF70451E),
              ),
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            top: 128,
            bottom: 20,
            child: _Shelves(),
          ),
        ],
      ),
    );
  }
}

class _FeatureBubble extends StatelessWidget {
  const _FeatureBubble({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  blurRadius: 7,
                  offset: Offset(0, 3),
                  color: Color(0x30000000),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFFFF9F1C), size: 27),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF70451E),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shelves extends StatelessWidget {
  const _Shelves();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Shelf(items: const [
          _Product('🥫'),
          _Product('🧃'),
          _Product('🍪'),
          _Product('🥛'),
        ]),
        _Shelf(items: const [
          _Product('🍎'),
          _Product('🧴'),
          _Product('🧃'),
          _Product('🍫'),
        ]),
        _Shelf(items: const [
          _Product('🥛'),
          _Product('🍪'),
          _Product('🥫'),
          _Product('🍎'),
        ]),
      ],
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.items});

  final List<_Product> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF9A5A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6D3D20), width: 3),
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            offset: Offset(0, 4),
            color: Color(0x55000000),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items,
      ),
    );
  }
}

class _Product extends StatelessWidget {
  const _Product(this.emoji);

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 55,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [
          BoxShadow(
            blurRadius: 3,
            offset: Offset(0, 2),
            color: Color(0x44000000),
          ),
        ],
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 30)),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 6),
            color: Color(0x44000000),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'LEVEL 1',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Color(0xFF6C431F),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              minHeight: 9,
              value: 0.0,
              backgroundColor: Color(0xFFEBD8BC),
              valueColor: AlwaysStoppedAnimation(Color(0xFFFFB52E)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onPlay,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA914),
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'PLAY',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, -4),
            color: Color(0x30000000),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _NavItem(icon: Icons.home_rounded, label: 'Home', selected: true),
          _NavItem(icon: Icons.map_rounded, label: 'Levels'),
          _NavItem(icon: Icons.card_giftcard_rounded, label: 'Events'),
          _NavItem(icon: Icons.shopping_bag_rounded, label: 'Shop'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFFA914) : const Color(0xFF8A7765);

    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
