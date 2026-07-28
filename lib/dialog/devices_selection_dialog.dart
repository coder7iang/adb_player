import 'package:adb_player/dialog/devices_model.dart';
import 'package:adb_player/dialog/devices_selection_provider.dart';
import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:adb_player/dialog/wireless_connect_dialog.dart';
import 'package:adb_player/services/adb_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设备选择对话框
class DeviceSelectionDialog extends ConsumerStatefulWidget {
  final List<DevicesModel> devices;
  final List<DevicesModel> Function() getCurrentDevices;
  final DevicesModel? currentDevice;
  final Future<void> Function()? refreshCallback;

  const DeviceSelectionDialog({
    Key? key,
    required this.devices,
    required this.getCurrentDevices,
    this.currentDevice,
    this.refreshCallback,
  }) : super(key: key);

  @override
  ConsumerState<DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends ConsumerState<DeviceSelectionDialog> {
  late TextEditingController searchController;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();

    // 先展示缓存列表，再后台静默刷新
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(devicesSelectionProvider.notifier).setDevices(widget.devices);
      if (widget.refreshCallback != null) {
        await widget.refreshCallback!();
        if (!mounted) return;
        ref
            .read(devicesSelectionProvider.notifier)
            .refreshDevices(widget.getCurrentDevices());
      }
    });

    // 监听搜索输入
    searchController.addListener(() {
      ref.read(devicesSelectionProvider.notifier).setSearchText(searchController.text);
    });
  }

  /// 构建高亮文本
  List<TextSpan> _buildHighlightedText(String text, String searchText, TextStyle baseStyle) {
    if (searchText.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    List<TextSpan> spans = [];
    String lowerText = text.toLowerCase();
    String lowerSearchText = searchText.toLowerCase();
    int startIndex = 0;

    while (true) {
      int index = lowerText.indexOf(lowerSearchText, startIndex);
      if (index == -1) {
        // 添加剩余文本
        if (startIndex < text.length) {
          spans.add(TextSpan(
            text: text.substring(startIndex),
            style: baseStyle,
          ));
        }
        break;
      }

      // 添加匹配前的文本
      if (index > startIndex) {
        spans.add(TextSpan(
          text: text.substring(startIndex, index),
          style: baseStyle,
        ));
      }

      // 添加高亮匹配文本
      spans.add(TextSpan(
        text: text.substring(index, index + searchText.length),
        style: baseStyle.copyWith(
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));

      startIndex = index + searchText.length;
    }

    return spans;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(devicesSelectionProvider);
    final notifier = ref.read(devicesSelectionProvider.notifier);
    
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 400,
          maxWidth: MediaQuery.of(context).size.width * 0.8,
          minHeight: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "选择设备",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "搜索设备",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: state.filteredDevicesList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.devices_other,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              state.devicesList.isEmpty 
                                  ? "当前没有连接设备"
                                  : "没有找到相关设备",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            if (state.devicesList.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                "请确保设备已连接并开启USB调试",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.filteredDevicesList.length,
                        itemBuilder: (context, index) {
                          final device = state.filteredDevicesList[index];
                          final isSelected = widget.currentDevice?.id == device.id;
                          
                          return ListTile(
                            leading: Icon(
                              device.isWireless ? Icons.wifi : Icons.usb,
                              color: device.isWireless ? Colors.green : Colors.grey[600],
                              size: 22,
                            ),
                            title: RichText(
                              text: TextSpan(
                                children: _buildHighlightedText(
                                  "${device.brand} ${device.model}",
                                  state.searchText,
                                  TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            subtitle: RichText(
                              text: TextSpan(
                                children: _buildHighlightedText(
                                  device.id,
                                  state.searchText,
                                  TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            trailing: device.isWireless
                                ? IconButton(
                                    icon: const Icon(Icons.link_off, size: 20),
                                    tooltip: '断开无线连接',
                                    color: Colors.red[400],
                                    onPressed: () async {
                                      SmartDialogUtils.showLoading('正在断开...');
                                      String msg = '';
                                      try {
                                        msg = await AdbService.instance
                                            .disconnectDevice(device.id);
                                        if (widget.refreshCallback != null) {
                                          await widget.refreshCallback!();
                                          if (!mounted) return;
                                          final newDevices =
                                              widget.getCurrentDevices();
                                          notifier.refreshDevices(newDevices);
                                        }
                                      } finally {
                                        SmartDialogUtils.hideLoading();
                                      }
                                      if (!mounted) return;
                                      if (msg.contains('失败') ||
                                          msg.contains('异常')) {
                                        SmartDialogUtils.showError(msg);
                                      } else if (msg.isNotEmpty) {
                                        SmartDialogUtils.showSuccess(msg);
                                      }
                                    },
                                  )
                                : null,
                            selected: isSelected,
                            selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                            selectedColor: Colors.blue,
                            onTap: () {
                              Navigator.of(context).pop(device);
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("取消"),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await showDialog<bool>(
                        context: context,
                        builder: (context) => const WirelessConnectDialog(),
                      );
                      if (widget.refreshCallback != null) {
                        await widget.refreshCallback!();
                        if (!mounted) return;
                        final newDevices = widget.getCurrentDevices();
                        notifier.refreshDevices(newDevices);
                      }
                    },
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text("无线连接"),
                  ),
                  if (widget.refreshCallback != null)
                    TextButton(
                      onPressed: () async {
                        await widget.refreshCallback!();
                        if (!mounted) return;
                        final newDevices = widget.getCurrentDevices();
                        notifier.refreshDevices(newDevices);
                      },
                      child: const Text("刷新"),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}