import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PopUpMenuButton<T extends PopUpMenuItem> extends ConsumerStatefulWidget {
  final PopUpMenuButtonViewModel<T> viewModel;

  final String menuTip;
  final Color? color;

  final Function(T)? onSelected;

  const PopUpMenuButton({
    Key? key,
    required this.viewModel,
    required this.menuTip,
    this.onSelected,
    this.color,
  }) : super(key: key);

  @override
  ConsumerState<PopUpMenuButton<T>> createState() => _PopUpMenuButtonState<T>();
}

class _PopUpMenuButtonState<T extends PopUpMenuItem>
    extends ConsumerState<PopUpMenuButton<T>> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: '',
      offset: const Offset(0, 40),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      padding: EdgeInsets.zero,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      constraints: const BoxConstraints(minWidth: 128),
      child: _menuTitleWidget(context),
      onSelected: (model) {
        setState(() {
          widget.viewModel.selectValue = model;
        });
        widget.onSelected?.call(model);
      },
      itemBuilder: (context) {
        final selected = widget.viewModel.selectValue;
        return widget.viewModel.list.map((element) {
          final isSelected = identical(element, selected) ||
              element.menuItemTitle == selected?.menuItemTitle;
          return PopupMenuItem<T>(
            value: element,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    element.menuItemTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF344054),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _menuTitleWidget(BuildContext context) {
    var text = widget.viewModel.selectValue?.menuItemTitle ?? widget.menuTip;
    return Container(
      height: 33,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(
              minWidth: 60,
            ),
            child: Text(
              text,
              overflow: TextOverflow.fade,
              style: TextStyle(
                fontSize: 13,
                color: widget.color ?? const Color(0xFF666666),
              ),
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: widget.color ?? const Color(0xFF666666),
          ),
        ],
      ),
    );
  }
}

class PopUpMenuItem {
  String menuItemTitle;

  PopUpMenuItem(this.menuItemTitle);
}

class PopUpMenuButtonViewModel<T extends PopUpMenuItem> {
  List<T> list = [];

  T? selectValue;

  PopUpMenuButtonViewModel();

  void setData(List<T> data) {
    list = data;
  }
}
