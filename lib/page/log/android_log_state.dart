import 'package:adb_player/widget/pop_up_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 日志页面状态类
class AndroidLogState {
  final String deviceId;
  final String packageName;
  final List<String> logList;
  final List<String> installedApps;
  final String filterContent;
  final String selectedFilterLevel;
  final bool isFilterPackage;
  final bool isCaseSensitive;
  final bool isShowLast;
  final String pid;
  final int findIndex;
  final bool isLoading;
  final String? errorMessage;
  final bool isLogging;
  final String? adbPath;
  
  AndroidLogState({
    required this.deviceId,
    this.packageName = "",
    this.logList = const [],
    this.installedApps = const [],
    this.filterContent = "",
    this.selectedFilterLevel = "*:V",
    this.isFilterPackage = false,
    this.isCaseSensitive = false,
    this.isShowLast = false,
    this.pid = "",
    this.findIndex = -1,
    this.isLoading = false,
    this.errorMessage,
    this.isLogging = false,
    this.adbPath,
  });
  
  /// 创建状态副本，支持部分更新
  AndroidLogState copyWith({
    String? deviceId,
    String? packageName,
    List<String>? logList,
    List<String>? installedApps,
    String? filterContent,
    String? selectedFilterLevel,
    bool? isFilterPackage,
    bool? isCaseSensitive,
    bool? isShowLast,
    String? pid,
    int? findIndex,
    bool? isLoading,
    String? errorMessage,
    bool? isLogging,
    String? adbPath,
  }) {
    return AndroidLogState(
      deviceId: deviceId ?? this.deviceId,
      packageName: packageName ?? this.packageName,
      logList: logList ?? this.logList,
      installedApps: installedApps ?? this.installedApps,
      filterContent: filterContent ?? this.filterContent,
      selectedFilterLevel: selectedFilterLevel ?? this.selectedFilterLevel,
      isFilterPackage: isFilterPackage ?? this.isFilterPackage,
      isCaseSensitive: isCaseSensitive ?? this.isCaseSensitive,
      isShowLast: isShowLast ?? this.isShowLast,
      pid: pid ?? this.pid,
      findIndex: findIndex ?? this.findIndex,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isLogging: isLogging ?? this.isLogging,
      adbPath: adbPath ?? this.adbPath,
    );
  }
  
  /// 获取日志颜色
  Color getLogColor(String log) {
    if (log.contains("E/")) {
      return Colors.red;
    } else if (log.contains("W/")) {
      return Colors.orange;
    } else if (log.contains("I/")) {
      return Colors.green;
    } else if (log.contains("D/")) {
      return Colors.blue;
    } else if (log.contains("V/")) {
      return Colors.grey;
    }
    return Colors.black;
  }
  
  /// 复制日志
  void copyLog(String log) {
    Clipboard.setData(ClipboardData(text: log));
  }
  
  /// 检查状态是否相等
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AndroidLogState &&
        other.deviceId == deviceId &&
        other.packageName == packageName &&
        other.logList == logList &&
        other.installedApps == installedApps &&
        other.filterContent == filterContent &&
        other.selectedFilterLevel == selectedFilterLevel &&
        other.isFilterPackage == isFilterPackage &&
        other.isCaseSensitive == isCaseSensitive &&
        other.isShowLast == isShowLast &&
        other.pid == pid &&
        other.findIndex == findIndex &&
        other.isLoading == isLoading &&
        other.errorMessage == errorMessage &&
        other.isLogging == isLogging &&
        other.adbPath == adbPath;
  }
  
  @override
  int get hashCode => Object.hash(
    deviceId, 
    packageName, 
    logList, 
    installedApps, 
    filterContent, 
    selectedFilterLevel, 
    isFilterPackage, 
    isCaseSensitive, 
    isShowLast, 
    pid, 
    findIndex,
    isLoading, 
    errorMessage, 
    isLogging,
    adbPath
  );
  
  @override
  String toString() {
    return 'AndroidLogState(deviceId: $deviceId, packageName: $packageName, logList: ${logList.length}, installedApps: ${installedApps.length}, filterContent: $filterContent, selectedFilterLevel: $selectedFilterLevel, isFilterPackage: $isFilterPackage, isCaseSensitive: $isCaseSensitive, isShowLast: $isShowLast, pid: $pid, findIndex: $findIndex, isLoading: $isLoading, errorMessage: $errorMessage, isLogging: $isLogging, adbPath: $adbPath)';
  }
}

/// 日志级别筛选类
class FilterLevel extends PopUpMenuItem {
  final String name;
  final String value;
  
  FilterLevel(this.name, this.value) : super(name);
  
  String get itemTitle => name;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterLevel &&
        other.name == name &&
        other.value == value;
  }
  
  @override
  int get hashCode => Object.hash(name, value);
  
  @override
  String toString() => 'FilterLevel(name: $name, value: $value)';
}
