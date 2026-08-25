import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:adb_player/dialog/food_roulette_state.dart';

final foodRouletteProvider = StateNotifierProvider<FoodRouletteNotifier, FoodRouletteState>((ref) {
  return FoodRouletteNotifier();
});

class FoodRouletteNotifier extends StateNotifier<FoodRouletteState> {
  FoodRouletteNotifier() : super(FoodRouletteState()) {
    _loadFoodData();
  }

  /// 加载食物数据
  Future<void> _loadFoodData() async {
    try {
      state = state.copyWith(isLoading: true);
      
      final String jsonString = await rootBundle.loadString('assets/data/food_data.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> foodsJson = jsonData['foods'] ?? [];
      
      final List<FoodItem> foods = foodsJson
          .map((json) => FoodItem.fromJson(json))
          .toList();
      
      state = state.copyWith(
        foods: foods,
        isLoading: false,
      );
      
      debugPrint('加载食物数据成功: ${foods.length} 个食物');
    } catch (e) {
      debugPrint('加载食物数据失败: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// 进入旋转状态（不预抽结果；保留上次结果以便过渡动画）
  void startSpinning() {
    if (state.foods.isEmpty) {
      debugPrint('食物数据为空，无法开始旋转');
      return;
    }
    state = state.copyWith(
      isSpinning: true,
    );
    debugPrint('开始旋转');
  }

  /// 揭晓结果（动画停止时由 dialog 根据落点扇形传入 idx）
  void revealSpin(int idx) {
    if (idx < 0 || idx >= state.foods.length) return;
    final selectedFood = state.foods[idx];
    state = state.copyWith(
      isSpinning: false,
      selectedIndex: idx,
      selectedFood: selectedFood,
    );
    debugPrint('揭晓: ${selectedFood.name} (idx=$idx)');
  }

  /// 重新开始
  void reset() {
    state = state.copyWith(
      isSpinning: false,
      selectedIndex: -1,
      clearSelectedFood: true,
    );
  }

  /// 替换食物列表（自定义）
  void setCustomFoods(List<FoodItem> foods) {
    state = state.copyWith(
      foods: foods,
      isSpinning: false,
      selectedIndex: -1,
      clearSelectedFood: true,
    );
    debugPrint('自定义食物列表: ${foods.length} 项');
  }

  /// 修改标题（空字符串恢复默认）
  void setTitle(String title) {
    final trimmed = title.trim();
    state = state.copyWith(
      title: trimmed.isEmpty ? FoodRouletteState.defaultTitle : trimmed,
    );
  }
}
