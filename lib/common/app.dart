import 'package:shared_preferences/shared_preferences.dart';

class App {
  static final App _app = App._();

  App._();

  factory App() => _app;

  static const String adbFilePathKey = "adbFilePathKey";
  static const String isShowSystemApp = 'isShowSystemApp';
  static const String scrcpyFilePathKey = "scrcpyFilePathKey";
  static const String saveFilePathKey = "saveFilePathKey";
  static const String appBackgroundKey = "appBackgroundKey";
  static const String appBackgroundFitKey = "appBackgroundFitKey";
  static const String appBackgroundOpacityKey = "appBackgroundOpacityKey";
  static const String appBackgroundBlurKey = "appBackgroundBlurKey";

  String _adbPath = "";

  String _scrcpyPath = "";

  String _appBackgroundPath = "";
  String _appBackgroundFit = "cover";
  double _appBackgroundOpacity = 0.28;
  double _appBackgroundBlur = 0;

  /// 保存ADB路径
  Future<void> setAdbPath(String path) async {
    _adbPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(adbFilePathKey, path);
  }

  /// 获取ADB缓存路径
  Future<String> getAdbPath() async {
    if (_adbPath.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _adbPath = prefs.getString(adbFilePathKey) ?? "";
    }
    return _adbPath;
  }

  /// 获取Scrcpy路径
  Future<String> getScrcpyPath() async {
    if (_scrcpyPath.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _scrcpyPath = prefs.getString(scrcpyFilePathKey) ?? "";
    }
    return _scrcpyPath;
  }

  /// 保存Scrcpy路径
  Future<void> setScrcpyPath(String path) async {
    _scrcpyPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(scrcpyFilePathKey, path);
  }

  /// 获取是否显示系统应用
  Future<bool> getIsShowSystemApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(isShowSystemApp) ?? false;
  }

  /// 保存是否显示系统应用
  Future<void> setIsShowSystemApp(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(isShowSystemApp, value);
  }

  /// 获取保存路径
  Future<String> getSaveFilePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(saveFilePathKey) ?? "";
  }

  /// 保存保存路径
  Future<void> setSaveFilePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(saveFilePathKey, path);
  }

  /// 获取应用背景路径
  Future<String> getAppBackgroundPath() async {
    if (_appBackgroundPath.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _appBackgroundPath = prefs.getString(appBackgroundKey) ?? "";
    }
    return _appBackgroundPath;
  }

  /// 保存应用背景路径
  Future<void> setAppBackgroundPath(String path) async {
    _appBackgroundPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appBackgroundKey, path);
  }

  /// 获取背景适配模式：cover / repeat / contain / center
  Future<String> getAppBackgroundFit() async {
    final prefs = await SharedPreferences.getInstance();
    var fit = prefs.getString(appBackgroundFitKey) ?? "cover";
    const valid = {'cover', 'repeat', 'contain', 'center'};
    if (!valid.contains(fit)) {
      fit = 'cover';
    }
    _appBackgroundFit = fit;
    return _appBackgroundFit;
  }

  /// 保存背景适配模式
  Future<void> setAppBackgroundFit(String fit) async {
    _appBackgroundFit = fit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appBackgroundFitKey, fit);
  }

  /// 背景遮罩透明度 0~1（越大越白、背景越淡）
  Future<double> getAppBackgroundOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    _appBackgroundOpacity =
        prefs.getDouble(appBackgroundOpacityKey) ?? 0.28;
    return _appBackgroundOpacity.clamp(0.0, 1.0);
  }

  Future<void> setAppBackgroundOpacity(double value) async {
    _appBackgroundOpacity = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(appBackgroundOpacityKey, _appBackgroundOpacity);
  }

  /// 背景模糊强度 0~30（sigma）
  Future<double> getAppBackgroundBlur() async {
    final prefs = await SharedPreferences.getInstance();
    _appBackgroundBlur = prefs.getDouble(appBackgroundBlurKey) ?? 0;
    return _appBackgroundBlur.clamp(0.0, 30.0);
  }

  Future<void> setAppBackgroundBlur(double value) async {
    _appBackgroundBlur = value.clamp(0.0, 30.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(appBackgroundBlurKey, _appBackgroundBlur);
  }
}
