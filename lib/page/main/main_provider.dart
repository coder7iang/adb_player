import 'dart:io';

import 'package:adb_player/common/app.dart';
import 'package:adb_player/dialog/devices_model.dart';
import 'package:adb_player/dialog/devices_selection_dialog.dart';
import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:adb_player/page/main/main_state.dart';
import 'package:adb_player/services/adb_service.dart';
import 'package:adb_player/services/scrcpy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 主页面的 Provider
final mainProvider = StateNotifierProvider<MainNotifier, MainState>(
  (ref) => MainNotifier(),
);

/// 主页面的状态管理器
class MainNotifier extends StateNotifier<MainState> {
  MainNotifier() : super(const MainState());

  bool _initializing = false;
  bool _configuringAdb = false;

  /// 初始化
  Future<void> init() async {
    if (_initializing) {
      return;
    }
    _initializing = true;
    try {
      await checkAdb();
      await checkScrcpy();
      if (state.isAdbAvailable) {
        await getDeviceList();
      }
    } finally {
      _initializing = false;
    }
  }

  /// 检查 Scrcpy 是否可用
  Future<void> checkScrcpy() async {
    await ScrcpyService.instance.getScrcpyPath();
  }

  /// 检查 ADB 是否可用
  Future<void> checkAdb() async {
    await AdbService.instance.checkAdb();
    await syncAdbFromService(refreshDevices: false);
  }

  /// 与 AdbService / 本地缓存同步可用状态
  Future<void> syncAdbFromService({bool refreshDevices = true}) async {
    var adbPath = AdbService.instance.adbPath;
    if (adbPath.isEmpty) {
      adbPath = await App().getAdbPath();
    }
    final available = adbPath.isNotEmpty && await File(adbPath).exists();
    if (available) {
      AdbService.instance.adbPath = adbPath;
    }
    state = state.copyWith(
      adbPath: available ? adbPath : '',
      isAdbAvailable: available,
    );
    if (available && refreshDevices) {
      await getDeviceList();
    }
  }

  /// 重新走 ADB 配置：缓存 → which/where → 下载；仍失败返回 false
  Future<bool> reconfigureAdb() async {
    if (_configuringAdb) return state.isAdbAvailable;
    _configuringAdb = true;
    SmartDialogUtils.showLoading('正在配置 ADB...');
    try {
      // 清空内存路径，强制重新探测（prefs 里有效路径仍会被用上）
      AdbService.instance.adbPath = '';
      await AdbService.instance.checkAdb();
      await syncAdbFromService(refreshDevices: true);
      SmartDialogUtils.hideLoading();
      if (state.isAdbAvailable) {
        SmartDialogUtils.showSuccess('ADB 配置成功');
        return true;
      }
      SmartDialogUtils.showError(
        '未自动找到 ADB，请手动选择可执行文件\n（终端 which / where adb 的路径）',
      );
      return false;
    } catch (e) {
      SmartDialogUtils.hideLoading();
      SmartDialogUtils.showError('配置 ADB 失败: $e');
      return false;
    } finally {
      _configuringAdb = false;
      state = state.copyWith(isLoading: false, loadingText: '');
    }
  }

  /// 手动指定 ADB 路径并立即生效（无需重启）
  Future<bool> applyManualAdbPath(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      SmartDialogUtils.showError('ADB 路径为空');
      return false;
    }
    if (!await File(trimmed).exists()) {
      SmartDialogUtils.showError('文件不存在，请检查路径');
      return false;
    }
    await AdbService.instance.setAdbPath(trimmed);
    await syncAdbFromService(refreshDevices: true);
    if (state.isAdbAvailable) {
      SmartDialogUtils.showSuccess('ADB 配置成功');
      return true;
    }
    SmartDialogUtils.showError('ADB 配置失败');
    return false;
  }

  /// 获取设备列表
  /// [silent] 为 true 时不展示全局 loading（用于弹窗内刷新）
  Future<void> getDeviceList({bool silent = false}) async {
    if (!state.isAdbAvailable) {
      return;
    }
    if (!silent) {
      state = state.copyWith(isLoading: true, loadingText: '获取设备列表中...');
    }
    try {
      var devices = await AdbService.instance.getDeviceList();
      if (devices.isNotEmpty) {
        DevicesModel? keep;
        final prevId = state.selectedDevice?.id;
        if (prevId != null) {
          final idx = devices.indexWhere((d) => d.id == prevId);
          if (idx != -1) keep = devices[idx];
        }
        _applySelectedDevice(
          keep ?? devices.first,
          devicesList: devices,
          isLoading: false,
          loadingText: '',
        );
      } else {
        _applySelectedDevice(
          null,
          devicesList: const [],
          isLoading: false,
          loadingText: '',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        loadingText: '',
        errorMessage: '获取设备列表异常: $e',
      );
    }
  }

  /// 选择设备
  void selectDevice(int index) {
    if (index >= 0 && index < state.devicesList.length) {
      _applySelectedDevice(
        state.devicesList[index],
        selectedIndex: index,
      );
    }
  }

  /// 选择页面
  void selectPage(int index) {
    state = state.copyWith(selectedIndex: index);
  }

  /// 选择设备：先立刻弹窗，再在弹窗内静默刷新，避免点击后卡住
  Future<void> devicesSelect(BuildContext context) async {
    var value = await showDialog<DevicesModel>(
      context: context,
      builder: (context) => DeviceSelectionDialog(
        devices: state.devicesList,
        getCurrentDevices: () => state.devicesList,
        currentDevice: state.selectedDevice,
        refreshCallback: () async {
          await getDeviceList(silent: true);
        },
      ),
    );

    if (value != null) {
      int deviceIndex =
          state.devicesList.indexWhere((device) => device.id == value.id);
      if (deviceIndex != -1) {
        _applySelectedDevice(
          value,
          selectedIndex: 1,
        );
      }
    }
  }

  void _applySelectedDevice(
    DevicesModel? device, {
    List<DevicesModel>? devicesList,
    int? selectedIndex,
    bool? isLoading,
    String? loadingText,
  }) {
    state = state.copyWith(
      devicesList: devicesList,
      selectedDevice: device,
      clearSelectedDevice: device == null,
      selectedIndex: selectedIndex,
      isLoading: isLoading,
      loadingText: loadingText,
    );
    AdbService.instance.currentDeviceId = device?.id ?? '';
  }
}
