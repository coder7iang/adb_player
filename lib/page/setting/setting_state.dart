/// ADB 设置页面状态类
class SettingState {
  final String adbPath;
  final String scrcpyPath;
  final String saveFilePath;
  final String appBackgroundPath;
  /// cover / repeat / contain / center
  final String appBackgroundFit;
  /// 遮罩透明度 0~1
  final double appBackgroundOpacity;
  /// 模糊 sigma 0~30
  final double appBackgroundBlur;

  const SettingState({
    this.adbPath = "",
    this.scrcpyPath = "",
    this.saveFilePath = "",
    this.appBackgroundPath = "",
    this.appBackgroundFit = "cover",
    this.appBackgroundOpacity = 0.28,
    this.appBackgroundBlur = 0,
  });

  SettingState copyWith({
    String? adbPath,
    String? scrcpyPath,
    String? saveFilePath,
    String? appBackgroundPath,
    String? appBackgroundFit,
    double? appBackgroundOpacity,
    double? appBackgroundBlur,
  }) {
    return SettingState(
      adbPath: adbPath ?? this.adbPath,
      scrcpyPath: scrcpyPath ?? this.scrcpyPath,
      saveFilePath: saveFilePath ?? this.saveFilePath,
      appBackgroundPath: appBackgroundPath ?? this.appBackgroundPath,
      appBackgroundFit: appBackgroundFit ?? this.appBackgroundFit,
      appBackgroundOpacity:
          appBackgroundOpacity ?? this.appBackgroundOpacity,
      appBackgroundBlur: appBackgroundBlur ?? this.appBackgroundBlur,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettingState &&
        other.adbPath == adbPath &&
        other.scrcpyPath == scrcpyPath &&
        other.saveFilePath == saveFilePath &&
        other.appBackgroundPath == appBackgroundPath &&
        other.appBackgroundFit == appBackgroundFit &&
        other.appBackgroundOpacity == appBackgroundOpacity &&
        other.appBackgroundBlur == appBackgroundBlur;
  }

  @override
  int get hashCode => Object.hash(
        adbPath,
        scrcpyPath,
        saveFilePath,
        appBackgroundPath,
        appBackgroundFit,
        appBackgroundOpacity,
        appBackgroundBlur,
      );

  @override
  String toString() {
    return 'SettingState(adbPath: $adbPath, scrcpyPath: $scrcpyPath, saveFilePath: $saveFilePath, appBackgroundPath: $appBackgroundPath, appBackgroundFit: $appBackgroundFit, appBackgroundOpacity: $appBackgroundOpacity, appBackgroundBlur: $appBackgroundBlur)';
  }
}
