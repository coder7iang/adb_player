import 'package:adb_player/common/app.dart';
import 'package:adb_player/dialog/devices_model.dart';
import 'package:adb_player/dialog/devices_selection_dialog.dart';
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
    final adbPath = AdbService.instance.adbPath.isNotEmpty
        ? AdbService.instance.adbPath
        : await App().getAdbPath();
    state = state.copyWith(
      adbPath: adbPath,
      isAdbAvailable: adbPath.isNotEmpty,
    );
  }

  /// 获取设备列表
  /// [silent] 为 true 时不展示全局 loading（用于弹窗内刷新）
  Future<void> getDeviceList({bool silent = false}) async {
    if (!state.isAdbAvailable) {
      return;
    }
    if (!silent) {
      state = state.copyWith(isLoading: true, loadingText: "获取设备列表中...");
    }
    try {
      var devices = await AdbService.instance.getDeviceList();
      if (devices.isNotEmpty) {
        // 若已选中的设备仍在列表中（按 id 匹配），保留原选择，避免刷新后回跳到第一台
        DevicesModel? keep;
        final prevId = state.selectedDevice?.id;
        if (prevId != null) {
          final idx = devices.indexWhere((d) => d.id == prevId);
          if (idx != -1) keep = devices[idx];
        }
        // 只更新设备，不改 selectedIndex，避免手册等页面被踢回快捷功能
        _applySelectedDevice(
          keep ?? devices.first,
          devicesList: devices,
          isLoading: false,
          loadingText: "",
        );
      } else {
        _applySelectedDevice(
          null,
          devicesList: const [],
          isLoading: false,
          loadingText: "",
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        loadingText: "",
        errorMessage: "获取设备列表异常: $e",
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
          selectedIndex: 1, // 选择设备后自动切换到功能页面
        );
      }
    }
  }

  /// 统一更新选中设备：同步 state 与 AdbService.currentDeviceId，
  /// 避免两者不一致导致 ADB 命令仍作用在旧设备上
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
    AdbService.instance.currentDeviceId = device?.id ?? "";
  }
}