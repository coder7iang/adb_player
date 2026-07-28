import 'package:adb_player/page/log/android_log_provider.dart';
import 'package:adb_player/page/log/android_log_state.dart';
import 'package:adb_player/widget/pop_up_menu_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AndroidLogPage extends ConsumerStatefulWidget {
  final String deviceId;

  const AndroidLogPage({Key? key, required this.deviceId}) : super(key: key);

  @override
  ConsumerState<AndroidLogPage> createState() => _AndroidLogPageState();
}

class _AndroidLogPageState extends ConsumerState<AndroidLogPage> {
  
  @override
  void initState() {
    super.initState();
    // 初始化日志页面
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(androidLogProvider(widget.deviceId).notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(androidLogProvider(widget.deviceId));
    final logNotifier = ref.read(androidLogProvider(widget.deviceId).notifier);
    
    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          Material(
            color: Colors.transparent,
        child: Column(
          children: [
            // 筛选控制栏
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
              ),
              child: Column(
                children: [
                  // 第一行：筛选、级别、应用
                  Row(
                    children: [
                      _buildLabel("筛选"),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: logNotifier.filterController,
                          onChanged: (value) {
                            logNotifier.setFilterContent(value);
                          },
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            hintText: "输入筛选内容",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                            ),
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildLabel("级别"),
                      const SizedBox(width: 8),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        child: PopUpMenuButton(
                          viewModel: logNotifier.filterLevelViewModel,
                          menuTip: "选择筛选级别",
                          onSelected: (FilterLevel level) {
                            logNotifier.setFilterLevel(level.value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildLabel("应用"),
                      const SizedBox(width: 8),
                      packageNameView(logState, logNotifier),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 第二行：查找
                  Row(
                    children: [
                      _buildLabel("查找"),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final state = ref.watch(androidLogProvider(widget.deviceId));
                            return TextField(
                              controller: logNotifier.findController,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                hintText: "输入查找内容",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                                ),
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
                                isDense: true,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    Icons.text_fields,
                                    size: 18,
                                    color: state.isCaseSensitive 
                                        ? Colors.blue 
                                        : const Color(0xFF999999),
                                  ),
                                  onPressed: () {
                                    logNotifier.setCaseSensitive(!state.isCaseSensitive);
                                  },
                                  tooltip: state.isCaseSensitive ? '区分大小写（已启用）' : '区分大小写',
                                ),
                              ),
                              style: const TextStyle(fontSize: 13),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 上一个按钮（向上箭头）
                      _buildIconButton(
                        icon: Icons.keyboard_arrow_up,
                        tooltip: '上一个',
                        onPressed: () => logNotifier.findPrevious(),
                      ),
                      const SizedBox(width: 4),
                      // 下一个按钮（向下箭头）
                      _buildIconButton(
                        icon: Icons.keyboard_arrow_down,
                        tooltip: '下一个',
                        onPressed: () => logNotifier.findNext(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildLogContentView(logState, logNotifier),
          ],
        ),
      ),
          // 右下角浮动按钮
          Positioned(
            right: 25,
            bottom: 25,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 清除按钮
                FloatingActionButton(
                  heroTag: 'clear',
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF666666),
                  elevation: 3,
                  onPressed: () {
                    logNotifier.clearLog();
                  },
                  tooltip: '清除日志',
                  child: const Icon(Icons.delete_outline, size: 22),
                ),
                const SizedBox(height: 12),
                // 滚到底部 / 跟随最新（选中跟随，取消停止）
                FloatingActionButton(
                  heroTag: 'scroll_bottom',
                  mini: true,
                  backgroundColor: logState.isShowLast
                      ? const Color(0xFF2563EB)
                      : Colors.white,
                  foregroundColor: logState.isShowLast
                      ? Colors.white
                      : const Color(0xFF666666),
                  elevation: 3,
                  onPressed: () {
                    logNotifier.toggleScrollToBottom();
                  },
                  tooltip: logState.isShowLast ? '取消跟随底部' : '跟随滚到底部',
                  child: const Icon(Icons.vertical_align_bottom, size: 22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建可选择的日志文本，带高亮功能
  Widget _buildSelectableLogText(
    String text,
    Color textColor,
    bool isCurrentFind,
    String searchTerm,
    bool caseSensitive,
    String filterContent, // 添加筛选内容参数
  ) {
    // 如果没有搜索词和筛选内容，直接返回普通文本
    if (searchTerm.isEmpty && filterContent.isEmpty) {
      return SelectableText(
        text,
        style: TextStyle(color: textColor, fontSize: 13),
      );
    }

    // 处理高亮 - 支持同时显示查找和筛选高亮
    List<TextSpan> spans = [];
    String textToSearch = caseSensitive ? text : text.toLowerCase();
    
    // 创建高亮标记数组
    List<bool> searchHighlights = List.filled(text.length, false);
    List<bool> filterHighlights = List.filled(text.length, false);
    
    // 标记查找高亮
    if (searchTerm.isNotEmpty) {
      String searchTermToSearch = caseSensitive ? searchTerm : searchTerm.toLowerCase();
      int start = 0;
      while (start < text.length) {
        int index = textToSearch.indexOf(searchTermToSearch, start);
        if (index == -1) break;
        
        for (int i = index; i < index + searchTerm.length; i++) {
          if (i < searchHighlights.length) {
            searchHighlights[i] = true;
          }
        }
        start = index + searchTerm.length;
      }
    }
    
    // 标记筛选高亮
    if (filterContent.isNotEmpty) {
      String filterTermToSearch = caseSensitive ? filterContent : filterContent.toLowerCase();
      int start = 0;
      while (start < text.length) {
        int index = textToSearch.indexOf(filterTermToSearch, start);
        if (index == -1) break;
        
        for (int i = index; i < index + filterContent.length; i++) {
          if (i < filterHighlights.length) {
            filterHighlights[i] = true;
          }
        }
        start = index + filterContent.length;
      }
    }
    
    // 构建文本片段
    int i = 0;
    while (i < text.length) {
      int start = i;
      
      // 找到连续的高亮区域
      while (i < text.length && (searchHighlights[i] || filterHighlights[i])) {
        i++;
      }
      
      if (start < i) {
        // 添加高亮文本
        String highlightText = text.substring(start, i);
        bool isSearchHighlight = searchHighlights[start];
        
        Color backgroundColor;
        if (isCurrentFind && isSearchHighlight) {
          backgroundColor = Colors.red; // 当前查找项
        } else if (isSearchHighlight) {
          backgroundColor = Colors.yellowAccent; // 查找高亮
        } else {
          backgroundColor = Colors.orangeAccent; // 筛选高亮
        }
        
        spans.add(TextSpan(
          text: highlightText,
          style: TextStyle(
            color: isCurrentFind && isSearchHighlight ? Colors.white : textColor,
            backgroundColor: backgroundColor,
            fontWeight: isCurrentFind && isSearchHighlight ? FontWeight.bold : null,
            fontSize: 13,
          ),
        ));
      }
      
      // 添加非高亮文本
      if (i < text.length) {
        int nonHighlightStart = i;
        while (i < text.length && !searchHighlights[i] && !filterHighlights[i]) {
          i++;
        }
        if (nonHighlightStart < i) {
          spans.add(TextSpan(
            text: text.substring(nonHighlightStart, i),
            style: TextStyle(color: textColor, fontSize: 13),
          ));
        }
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  Expanded _buildLogContentView(AndroidLogState logState, AndroidLogNotifier logNotifier) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FlutterListView(
              controller: logNotifier.scrollController,
              delegate: FlutterListViewDelegate(
                (context, index) {
                  var log = logState.logList[index];
                  Color textColor = logState.getLogColor(log);
                  return Listener(
                    onPointerDown: (event) {
                      if (event.kind == PointerDeviceKind.mouse &&
                          event.buttons == kSecondaryMouseButton) {
                        logState.copyLog(log);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 3, horizontal: 15),
                      child: _buildSelectableLogText(
                        log, 
                        textColor, 
                        logState.findIndex == index,
                        logNotifier.findController.text,
                        logState.isCaseSensitive,
                        logState.filterContent, // 传入筛选内容
                      ),
                    ),
                  );
                },
                childCount: logState.logList.length,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建标签
  Widget _buildLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF666666),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 构建图标按钮
  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white.withValues(alpha: 0.3),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  Widget packageNameView(AndroidLogState logState, AndroidLogNotifier logNotifier) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          logNotifier.selectPackageName(context, ref);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white.withValues(alpha: 0.3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(androidLogProvider(widget.deviceId));
                  return Text(
                    state.packageName.isEmpty ? "选择应用" : state.packageName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              // 根据是否选中包名显示不同的图标
              if (logState.packageName.isEmpty)
                const Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: Color(0xFF999999),
                )
              else
                GestureDetector(
                  onTap: () {
                    logNotifier.clearPackageName();
                  },
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0E0E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 10,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
