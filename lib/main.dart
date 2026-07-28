import 'dart:io';

import 'package:adb_player/page/main/main_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

/// 全局托盘实例
final SystemTray _systemTray = SystemTray();
final Menu _trayMenu = Menu();

Future<void> _initSystemTray() async {
  // 仅在桌面端初始化托盘
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }

  // Windows 托盘图标需要 ico，其他桌面平台继续使用 png。
  final String iconPath = Platform.isWindows
      ? 'images/app_icon.ico'
          : 'images/app_icon.png';

  await _systemTray.initSystemTray(
    title: '',
    iconPath: iconPath,
    toolTip: 'AdbPlayer',
    // 仅 macOS：作为模板图渲染，跟随系统主题变黑/白。
    isTemplate: Platform.isMacOS,
  );

  await _trayMenu.buildFrom([
    MenuItemLabel(
      label: '显示窗口',
      onClicked: (menuItem) async {
        await windowManager.show();
        await windowManager.focus();
      },
    ),
    MenuItemLabel(
      label: '退出',
      onClicked: (menuItem) async {
        // 通过托盘菜单真正退出应用
        exit(0);
      },
    ),
  ]);

  await _systemTray.setContextMenu(_trayMenu);

  // 点击托盘图标的行为
  _systemTray.registerSystemTrayEventHandler((eventName) async {
    if (eventName == kSystemTrayEventClick) {
      // 左键单击显示窗口
      await windowManager.show();
      await windowManager.focus();
    } else if (eventName == kSystemTrayEventRightClick) {
      // 右键弹出菜单
      await _systemTray.popUpContextMenu();
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面端初始化窗口管理和托盘
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(960, 720),
      center: true,
      backgroundColor: Colors.transparent,
      title: 'AdbPlayer',
      titleBarStyle: TitleBarStyle.hidden,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      // 启动后正常显示窗口
      await windowManager.show();
      await windowManager.focus();
      // 阻止点击关闭按钮直接退出（交给 onWindowClose 处理，改为缩到托盘）
      await windowManager.setPreventClose(true);
    });

    _initSystemTray().catchError((Object error, StackTrace stackTrace) {
      debugPrint('初始化系统托盘失败: $error');
    });
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    // 仅在桌面端监听窗口事件
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }

    final bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      // 用户点击关闭按钮时，只隐藏到托盘，不真正退出
      await windowManager.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdbPlayer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      // 桌面端默认会把方向键当成「切换按钮焦点」，与摸鱼彩蛋冲突且干扰鼠标操作
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.arrowUp): DoNothingIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown): DoNothingIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): DoNothingIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): DoNothingIntent(),
      },
      home: const MainPage(),
      // 配置 SmartDialog
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
    );
  }
}
