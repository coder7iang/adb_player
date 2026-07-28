import 'package:adb_player/common/app.dart';
import 'package:adb_player/page/setting/setting_provider.dart';
import 'package:adb_player/page/setting/setting_state.dart';
import 'package:adb_player/services/adb_service.dart';
import 'package:adb_player/services/scrcpy_service.dart';
import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  late TextEditingController adbController;
  late TextEditingController scrcpyController;
  late TextEditingController saveFileController;
  late TextEditingController appBackgroundController;

  @override
  void initState() {
    super.initState();
    adbController = TextEditingController();
    scrcpyController = TextEditingController();
    saveFileController = TextEditingController();
    appBackgroundController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final adbPath = AdbService.instance.adbPath;
      if (adbPath.isNotEmpty) {
        final adbSettingNotifier = ref.read(settingProvider.notifier);
        adbSettingNotifier.setAdbPath(adbPath);
      }
      final scrcpyPath = ScrcpyService.instance.scrcpyPath;
      if (scrcpyPath.isNotEmpty) {
        final adbSettingNotifier = ref.read(settingProvider.notifier);
        await adbSettingNotifier.setScrcpyPath(scrcpyPath);
      }

      final app = App();
      final saveFilePath = await app.getSaveFilePath();
      if (saveFilePath.isNotEmpty) {
        final settingNotifier = ref.read(settingProvider.notifier);
        settingNotifier.setSaveFilePath(saveFilePath);
      }

      final appBackgroundPath = await app.getAppBackgroundPath();
      if (appBackgroundPath.isNotEmpty) {
        final settingNotifier = ref.read(settingProvider.notifier);
        settingNotifier.setAppBackgroundPath(appBackgroundPath);
      }
      final appBackgroundFit = await app.getAppBackgroundFit();
      ref.read(settingProvider.notifier).setAppBackgroundFit(appBackgroundFit);
      final opacity = await app.getAppBackgroundOpacity();
      ref.read(settingProvider.notifier).setAppBackgroundOpacity(opacity);
      final blur = await app.getAppBackgroundBlur();
      ref.read(settingProvider.notifier).setAppBackgroundBlur(blur);
    });
  }

  @override
  void dispose() {
    adbController.dispose();
    scrcpyController.dispose();
    saveFileController.dispose();
    appBackgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingState = ref.watch(settingProvider);
    adbController.text = settingState.adbPath;
    scrcpyController.text = settingState.scrcpyPath;
    saveFileController.text = settingState.saveFilePath;
    appBackgroundController.text = settingState.appBackgroundPath;
    final settingNotifier = ref.read(settingProvider.notifier);

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
      ),
      child: Container(
        color: Colors.transparent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingCard(
                icon: Icons.adb,
                iconColor: const Color(0xFF10B981),
                iconBg: const Color(0xFFECFDF5),
                title: 'ADB 路径',
                description: 'Android Debug Bridge 可执行文件路径',
                controller: adbController,
                hintText: '请输入或选择 ADB 路径',
                onChanged: settingNotifier.setAdbPath,
                onFileSelect: () async {
                  const typeGroup = XTypeGroup(label: 'adb', extensions: []);
                  final file =
                      await openFile(acceptedTypeGroups: [typeGroup]);
                  if (file?.path != null) {
                    settingNotifier.setAdbPath(file!.path);
                  }
                },
                actionLabel: '测试',
                onAction: settingNotifier.testAdb,
              ),
              const SizedBox(height: 12),
              _buildSettingCard(
                icon: Icons.cast,
                iconColor: const Color(0xFF8B5CF6),
                iconBg: const Color(0xFFF5F3FF),
                title: 'Scrcpy 路径',
                description: '用于投屏的 scrcpy 可执行文件',
                controller: scrcpyController,
                hintText: '请输入或选择 Scrcpy 路径',
                onChanged: (value) async {
                  await settingNotifier.setScrcpyPath(value);
                },
                onFileSelect: () async {
                  const typeGroup =
                      XTypeGroup(label: 'scrcpy', extensions: []);
                  final file =
                      await openFile(acceptedTypeGroups: [typeGroup]);
                  if (file?.path != null) {
                    await settingNotifier.setScrcpyPath(file!.path);
                  }
                },
                actionLabel: settingNotifier.hasScrcpy() ? '测试' : '配置',
                onAction: () {
                  if (settingNotifier.hasScrcpy()) {
                    settingNotifier.testScrcpy();
                  } else {
                    settingNotifier.checkScrcpy();
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildSettingCard(
                icon: Icons.folder_outlined,
                iconColor: const Color(0xFFF59E0B),
                iconBg: const Color(0xFFFEF3C7),
                title: '保存文件位置',
                description: '截图、录屏、日志默认存到这里',
                controller: saveFileController,
                hintText: '请选择保存目录',
                onChanged: settingNotifier.setSaveFilePath,
                onFileSelect: () async {
                  final directory = await getDirectoryPath();
                  if (directory != null) {
                    settingNotifier.setSaveFilePath(directory);
                  }
                },
                actionLabel: '清除',
                onAction: settingNotifier.hasSaveFilePath()
                    ? () {
                        settingNotifier.setSaveFilePath('');
                        SmartDialogUtils.showSuccess('已清除保存路径');
                      }
                    : null,
                actionDanger: true,
              ),
              const SizedBox(height: 12),
              _buildSettingCard(
                icon: Icons.image_outlined,
                iconColor: const Color(0xFFEC4899),
                iconBg: const Color(0xFFFDF2F8),
                title: '应用背景',
                description: '主界面背景图片或视频',
                controller: appBackgroundController,
                hintText: '请选择背景图片或视频',
                onChanged: settingNotifier.setAppBackgroundPath,
                onFileSelect: () async {
                  const typeGroup = XTypeGroup(
                    label: '图片/视频',
                    extensions: [
                      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
                      'mp4', 'mov', 'avi', 'mkv', 'webm',
                    ],
                  );
                  final file =
                      await openFile(acceptedTypeGroups: [typeGroup]);
                  if (file?.path != null) {
                    settingNotifier.setAppBackgroundPath(file!.path);
                  }
                },
                actionLabel: '清除',
                onAction: settingNotifier.hasAppBackgroundPath()
                    ? () {
                        settingNotifier.setAppBackgroundPath('');
                        SmartDialogUtils.showSuccess('已清除应用背景');
                      }
                    : null,
                actionDanger: true,
                footer: settingNotifier.hasAppBackgroundPath()
                    ? _buildBackgroundOptions(settingState, settingNotifier)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundOptions(
    SettingState settingState,
    SettingNotifier settingNotifier,
  ) {
    const fitOptions = <(String, String, String)>[
      ('cover', 'cover', '铺满窗口，多余裁剪'),
      ('repeat', 'repeat', '平铺重复'),
      ('contain', 'contain', '完整显示，可能留边'),
      ('center', 'center', '原尺寸居中'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '适配模式',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF344054),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label, tip) in fitOptions)
              _buildOptionChip(
                label: label,
                tip: tip,
                selected: settingState.appBackgroundFit == value,
                onSelected: () => settingNotifier.setAppBackgroundFit(value),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          '透明度 & 模糊度',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF344054),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _buildSliderRow(
                label: '透明度',
                value: settingState.appBackgroundOpacity,
                display:
                    '${(settingState.appBackgroundOpacity * 100).round()}%',
                onChanged: settingNotifier.setAppBackgroundOpacity,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSliderRow(
                label: '模糊度',
                value: settingState.appBackgroundBlur / 30,
                display: settingState.appBackgroundBlur <= 0
                    ? '关'
                    : settingState.appBackgroundBlur.toStringAsFixed(0),
                onChanged: (v) =>
                    settingNotifier.setAppBackgroundBlur(v * 30),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF667085),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: const Color(0xFFA5B4FC),
              inactiveTrackColor: const Color(0xFFE4E7EC),
              thumbColor: const Color(0xFF818CF8),
              overlayColor: const Color(0xFF818CF8).withValues(alpha: 0.16),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF344054),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionChip({
    required String label,
    required String tip,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return Tooltip(
      message: tip,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: const Color(0xFFFCE7F3),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? const Color(0xFF9D174D) : const Color(0xFF344054),
        ),
        side: BorderSide(
          color: selected ? const Color(0xFFF9A8D4) : const Color(0xFFE4E7EC),
        ),
        backgroundColor: Colors.white,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String description,
    required TextEditingController controller,
    required String hintText,
    required Function(String) onChanged,
    required VoidCallback onFileSelect,
    required String actionLabel,
    VoidCallback? onAction,
    bool actionDanger = false,
    Widget? footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAECF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF98A2B3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hintText,
                    hintStyle: const TextStyle(
                        fontSize: 13, color: Color(0xFFB8BFCC)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFEAECF0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFEAECF0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF3B82F6)),
                    ),
                    suffixIcon: IconButton(
                      onPressed: onFileSelect,
                      icon: const Icon(Icons.folder_open,
                          size: 16, color: Color(0xFF6B7280)),
                      tooltip: '选择文件',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 36,
                child: actionDanger
                    ? OutlinedButton(
                        onPressed: onAction,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(actionLabel,
                            style: const TextStyle(fontSize: 13)),
                      )
                    : ElevatedButton(
                        onPressed: onAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(actionLabel,
                            style: const TextStyle(fontSize: 13)),
                      ),
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEAECF0)),
            const SizedBox(height: 12),
            footer,
          ],
        ],
      ),
    );
  }
}
