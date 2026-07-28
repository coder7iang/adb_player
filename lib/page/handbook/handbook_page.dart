import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:adb_player/page/handbook/handbook_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ADB 命令速查 — 搜索 + 全量 ADB 命令列表
class HandbookPage extends StatefulWidget {
  const HandbookPage({Key? key}) : super(key: key);

  @override
  State<HandbookPage> createState() => _HandbookPageState();
}

class _HandbookPageState extends State<HandbookPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HandbookEntry> get _visibleEntries {
    return kHandbookEntries.where((e) => e.matches(_query)).toList();
  }

  /// 列表项：分组标题或命令卡片
  List<_ListItem> get _listItems {
    final entries = _visibleEntries;
    final items = <_ListItem>[];
    String? lastGroup;
    for (final e in entries) {
      if (e.group != lastGroup) {
        items.add(_ListItem.header(e.group));
        lastGroup = e.group;
      }
      items.add(_ListItem.entry(e));
    }
    return items;
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    SmartDialogUtils.showSuccess('已复制');
  }

  @override
  Widget build(BuildContext context) {
    final entries = _visibleEntries;
    final items = _listItems;

    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(entries.length),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          '无匹配命令，试试 pair、logcat、keyevent',
                          style: TextStyle(
                            color: Color(0xFF98A2B3),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final item = items[i];
                          if (item.isHeader) {
                            return _GroupHeader(
                              title: item.header!,
                              isFirst: i == 0,
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _EntryCard(
                              entry: item.entry!,
                              onCopy: _copy,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 22,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ADB 命令速查',
                  style: TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '共 $count 条 ADB 命令，点击即可复制',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 280,
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '搜索命令、关键词…',
                hintStyle: const TextStyle(
                  color: Color(0xFF98A2B3),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: Color(0xFF98A2B3),
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListItem {
  final String? header;
  final HandbookEntry? entry;

  const _ListItem.header(this.header) : entry = null;
  const _ListItem.entry(this.entry) : header = null;

  bool get isHeader => header != null;
}

class _GroupHeader extends StatelessWidget {
  final String title;
  final bool isFirst;

  const _GroupHeader({
    required this.title,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, isFirst ? 4 : 16, 4, 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE4E7EC),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final HandbookEntry entry;
  final Future<void> Function(String) onCopy;

  const _EntryCard({
    required this.entry,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF101828),
                      ),
                    ),
                    if (entry.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => onCopy(entry.command),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('复制'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onCopy(entry.command),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: SelectableText(
                  entry.command,
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontFamilyFallback: ['Consolas', 'monospace'],
                    fontSize: 12,
                    height: 1.45,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
