import 'package:adb_player/common/app.dart';
import 'package:adb_player/page/setting/setting_state.dart';
import 'package:adb_player/services/adb_service.dart';
import 'package:adb_player/services/scrcpy_service.dart';
import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ADB 设置页面的 Provider
final settingProvider =
    StateNotifierProvider<SettingNotifier, SettingState>(
  (ref) => SettingNotifier(),
);

/// ADB 设置页面的状态管理器
class SettingNotifier extends StateNotifier<SettingState> {
  SettingNotifier() : super(const SettingState());

  /// 设置 ADB 路径
  void setAdbPath(String path) {
    AdbService.instance.setAdbPath(path);
    state = state.copyWith(adbPath: path);
  }

  /// 测试 ADB 连接
  void testAdb() async {
    if (state.adbPath.isEmpty) {
      SmartDialogUtils.showError("请先选择或输入ADB路径");
    }
    try {
      bool result = await AdbService.instance.testAdb();
      if (result) {
        SmartDialogUtils.showSuccess("ADB配置成功");
      } else {
        SmartDialogUtils.showError("ADB配置失败");
      }
    } catch (e) {
      SmartDialogUtils.showError("ADB配置失败: $e");
    }
  }

  /// 设置 Scrcpy 路径
  Future<void> setScrcpyPath(String path) async {
    await ScrcpyService.instance.setScrcpyPath(path);
    state = state.copyWith(scrcpyPath: path);
  }

  bool hasScrcpy() {
    return state.scrcpyPath.isNotEmpty;
  }

  checkScrcpy() async {
    await ScrcpyService.instance.checkScrcpy();
    state = state.copyWith(scrcpyPath: ScrcpyService.instance.scrcpyPath);
  }

  testScrcpy() async {
    if (state.scrcpyPath.isEmpty) {
      SmartDialogUtils.showError("请先选择或输入Scrcpy路径");
    }
    try {
      bool result = await ScrcpyService.instance.testScrcpy();
      if (result) {
        SmartDialogUtils.showSuccess("Scrcpy配置成功");
      }
    } catch (e) {
      SmartDialogUtils.showError("Scrcpy配置失败: $e");
    }
  }

  /// 设置保存文件路径
  void setSaveFilePath(String path) {
    state = state.copyWith(saveFilePath: path);
    // 同时保存到SharedPreferences
    App().setSaveFilePath(path);
  }

  /// 检查是否已设置保存文件路径
  bool hasSaveFilePath() {
    return state.saveFilePath.isNotEmpty;
  }

  /// 设置应用背景路径
  void setAppBackgroundPath(String path) {
    state = state.copyWith(appBackgroundPath: path);
    // 同时保存到SharedPreferences
    App().setAppBackgroundPath(path);
  }

  /// 检查是否已设置应用背景路径
  bool hasAppBackgroundPath() {
    return state.appBackgroundPath.isNotEmpty;
  }

  /// 设置背景适配模式
  void setAppBackgroundFit(String fit) {
    state = state.copyWith(appBackgroundFit: fit);
    App().setAppBackgroundFit(fit);
  }

  /// 设置背景遮罩透明度
  void setAppBackgroundOpacity(double value) {
    state = state.copyWith(appBackgroundOpacity: value);
    App().setAppBackgroundOpacity(value);
  }

  /// 设置背景模糊
  void setAppBackgroundBlur(double value) {
    state = state.copyWith(appBackgroundBlur: value);
    App().setAppBackgroundBlur(value);
  }

  /// 设置右下角小图显示宽度
  void setAppBackgroundCornerWidth(double value) {
    state = state.copyWith(appBackgroundCornerWidth: value);
    App().setAppBackgroundCornerWidth(value);
  }
}
