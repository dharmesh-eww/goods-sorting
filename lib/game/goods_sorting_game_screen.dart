import 'package:flutter/material.dart';

import 'unity_style_game_screen.dart';

/// Public game-screen API kept compatible with the existing navigation code.
/// The implementation now lives in the Unity-inspired screen.
class GoodsSortingGameScreen extends StatelessWidget {
  const GoodsSortingGameScreen({super.key, required this.levelNumber});

  final int levelNumber;

  @override
  Widget build(BuildContext context) {
    return UnityStyleGameScreen(levelNumber: levelNumber);
  }
}
