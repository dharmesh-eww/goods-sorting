import 'package:shared_preferences/shared_preferences.dart';

class GameCurrency {
  GameCurrency._();

  static final GameCurrency instance = GameCurrency._();

  static const _coinsKey = 'goods_sorting_coins';
  static const defaultCoins = 250;

  int coins = defaultCoins;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    coins = prefs.getInt(_coinsKey) ?? defaultCoins;
    if (coins < 0) coins = 0;
  }

  Future<bool> spend(int amount) async {
    if (amount <= 0) return true;
    if (coins < amount) return false;
    coins -= amount;
    await _save();
    return true;
  }

  Future<void> add(int amount) async {
    if (amount <= 0) return;
    coins += amount;
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_coinsKey, coins);
  }
}
