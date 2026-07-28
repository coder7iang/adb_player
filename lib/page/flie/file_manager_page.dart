import 'package:adb_player/dialog/package_list_provider.dart';
import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:adb_player/page/flie/file_manager_provider.dart';
import 'package:adb_player/page/flie/file_model.dart';
import 'package:adb_player/services/adb_service.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

class FileManagerPage extends ConsumerStatefulWidget {
  final String deviceId;

  const FileManagerPage(this.deviceId, {Key? key}) : super(key: key);

  @override
  ConsumerState<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends ConsumerState<FileManagerPage> {
  @override
  void initState() {
    super.initState();
    // 初始化文件管理页面
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fileManagerProvider(widget.deviceId).notifier).init();
    });
  }

  /// 选择 App 包并进入私有目录浏览模式
  /// 流程：拉应用列表 → 选包 → 校验 debuggable → enterAppPrivateMode
  Future<void> _pickAppPrivateDir() async {
    SmartDialogUtils.showLoading('加载应用列表...');
    final packages = await AdbService.instance.getInstalledApp();
    SmartDialogUtils.hideLoading();
    if (packages.isEmpty) {
      SmartDialogUtils.showError('未获取到应用列表');
      return;
    }

    final selected = await SmartDialogUtils.showPackageListDialog(
      packages,
      null,
      () async {
        final pkgs = await AdbService.instance.getInstalledApp();
        ref.read(packageListProvider.notifier).setData(pkgs);
      },
    );

    final pkgName = selected?.itemTitle ?? '';
    if (pkgName.isEmpty) return;

    SmartDialogUtils.showLoading('检查应用...');
    final ok = await AdbService.instance.isPackageDebuggable(pkgName);
    SmartDialogUtils.hideLoading();
    if (!ok) {
      SmartDialogUtils.showError('"$pkgName" 不是 debuggable 包\n仅 debug 构建可走 run-as 浏览私有目录');
      return;
    }

    ref
        .read(fileManagerProvider(widget.deviceId).notifier)
        .enterAppPrivateMode(pkgName);
  }

  @override
  Widget build(BuildContext context) {
    final fileManagerNotifier = ref.read(fileManagerProvider(widget.deviceId).notifier);
    
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(fileManagerProvider(widget.deviceId));
              var title = state.currentPath.substring(
                  state.currentPath
                          .lastIndexOf("/", state.currentPath.lastIndexOf("/") - 1) +
                      1,
                  state.currentPath.lastIndexOf("/"));
              final inRunAs = state.runAsPackage != null;
              return AppBar(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                centerTitle: false,
                titleSpacing:
                    state.currentPath == state.rootPath ? 16 : 0,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (inRunAs) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline,
                                size: 12, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 4),
                            Text(
                              '私有目录 · ${state.runAsPackage}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6D28D9)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                leading: state.currentPath == state.rootPath
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.black38),
                        onPressed: () {
                          fileManagerNotifier.backFolder();
                        },
                      ),
                actions: <Widget>[
                  if (inRunAs)
                    TextButton.icon(
                      onPressed: () =>
                          fileManagerNotifier.exitAppPrivateMode(),
                      icon: const Icon(Icons.exit_to_app,
                          size: 14, color: Color(0xFF6D28D9)),
                      label: const Text(
                        '退出私有目录',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF6D28D9)),
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: _pickAppPrivateDir,
                      icon: const Icon(Icons.folder_special_outlined,
                          size: 14, color: Color(0xFF7C3AED)),
                      label: const Text(
                        '私有目录',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF7C3AED)),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.black38),
                    onPressed: () {
                      fileManagerNotifier.refresh();
                    },
                  ),
                ],
              );
            },
          ),
          Expanded(
            child: DropTarget(
              onDragDone: (data) {
                fileManagerNotifier.onDragDone(data, -1);
              },
              child: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(fileManagerProvider(widget.deviceId));
                  if (state.files.isEmpty) {
                    return Container(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            "images/ic_empty_file.svg",
                            width: 500,
                            height: 500,
                          ),
                          const Text(
                            "暂无文件",
                            style: TextStyle(
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: state.files.length,
                    itemBuilder: (context, index) {
                      return itemView(state.files[index], index, fileManagerNotifier);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 文件行副标题：修改时间 · 大小（文件夹只显示时间）
  Widget? _buildSubtitle(FileModel model) {
    final parts = <String>[];
    if (model.modifiedTime.isNotEmpty) parts.add(model.modifiedTime);
    if (model.sizeText.isNotEmpty) parts.add(model.sizeText);
    if (parts.isEmpty) return null;
    return Text(
      parts.join('  ·  '),
      style: const TextStyle(fontSize: 12, color: Colors.black45),
    );
  }

  Widget itemView(FileModel model, int index, FileManagerNotifier notifier) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: model.isSelect
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Listener(
        onPointerDown: (event) {
          notifier.onPointerDown(context, event, index);
        },
        child: ListTile(
          tileColor: model.isSelect ? Theme.of(context).hoverColor : null,
          hoverColor: Colors.transparent,
          leading: model.icon == null
              ? null
              : Icon(
                  model.icon,
                  color: model.type == FileManagerNotifier.typeFolder
                      ? Colors.blue
                      : Colors.grey,
                ),
          title: Text(model.name),
          subtitle: _buildSubtitle(model),
          onTap: () {
            notifier.openFolder(model);
          },
        ),
      ),
    );
  }
}
