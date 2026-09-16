import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

enum ResultDialogType { success, error, info }

class ResultDialog extends StatelessWidget {
  final String? title;
  final String? content;
  final ResultDialogType type;

  const ResultDialog({
    Key? key,
    this.title,
    this.content,
    this.type = ResultDialogType.info,
  }) : super(key: key);

  Color get _accent {
    switch (type) {
      case ResultDialogType.success:
        return const Color(0xFF2BB673);
      case ResultDialogType.error:
        return const Color(0xFFE04F5F);
      case ResultDialogType.info:
        return const Color(0xFF5B6CFF);
    }
  }

  Color get _softBg {
    switch (type) {
      case ResultDialogType.success:
        return const Color(0xFFEAF8F1);
      case ResultDialogType.error:
        return const Color(0xFFFDECEE);
      case ResultDialogType.info:
        return const Color(0xFFEEF0FF);
    }
  }

  IconData get _icon {
    switch (type) {
      case ResultDialogType.success:
        return Icons.check_circle_rounded;
      case ResultDialogType.error:
        return Icons.error_rounded;
      case ResultDialogType.info:
        return Icons.info_rounded;
    }
  }

  String get _defaultTitle {
    switch (type) {
      case ResultDialogType.success:
        return '操作成功';
      case ResultDialogType.error:
        return '操作失败';
      case ResultDialogType.info:
        return '提示';
    }
  }

  /// 从原始 ADB 文案提炼可读说明
  String? get _friendlyHint {
    final raw = (content ?? '').toLowerCase();
    if (raw.isEmpty) return null;
    if (raw.contains('install_failed_aborted') ||
        raw.contains('user rejected permissions')) {
      return '手机端拒绝了安装权限，请在设备上点「允许」或检查安装未知应用权限后重试。';
    }
    if (raw.contains('install_failed_update_incompatible') ||
        raw.contains('signatures do not match')) {
      return '签名不一致，无法覆盖安装。请先卸载旧版本，或换同签名包。';
    }
    if (raw.contains('install_failed_version_downgrade')) {
      return '版本号低于已安装版本，无法降级安装。可先卸载旧版再装。';
    }
    if (raw.contains('install_failed_insufficient_storage')) {
      return '设备存储空间不足，请清理后再试。';
    }
    if (raw.contains('device offline') || raw.contains('no devices')) {
      return '设备未连接或已离线，请检查 USB / 无线调试。';
    }
    if (raw.contains('install_parse_failed') || raw.contains('not a valid apk')) {
      return 'APK 文件无效或已损坏，请重新编译后再安装。';
    }
    if (raw.contains('install_failed_older_sdk')) {
      return '设备系统版本过低，不支持该应用要求的最低 SDK。';
    }
    return null;
  }

  Future<void> _copyDetail() async {
    final text = content?.trim() ?? '';
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final hint = _friendlyHint;
    final detail = (content ?? '').trim();
    final showDetail = detail.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 72, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Material(
          color: Colors.white,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _softBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: _accent, size: 32),
                ),
                const SizedBox(height: 14),
                Text(
                  title?.trim().isNotEmpty == true ? title! : _defaultTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2430),
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Color(0xFF5C6473),
                    ),
                  ),
                ] else if (showDetail && type != ResultDialogType.error) ...[
                  const SizedBox(height: 10),
                  SelectableText(
                    detail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Color(0xFF5C6473),
                    ),
                  ),
                ],
                if (showDetail &&
                    (type == ResultDialogType.error || hint != null)) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 140),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE6E8EE)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        detail,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF6B7280),
                          fontFamily: 'Menlo',
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (showDetail &&
                    (type == ResultDialogType.error ||
                        type == ResultDialogType.info))
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await _copyDetail();
                            SmartDialog.showToast('已复制');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4B5563),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            type == ResultDialogType.error ? '复制详情' : '复制',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => SmartDialog.dismiss(result: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('确定'),
                        ),
                      ),
                    ],
                  )
                else
                  Center(
                    child: SizedBox(
                      width: 128,
                      child: FilledButton(
                        onPressed: () => SmartDialog.dismiss(result: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('确定'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
