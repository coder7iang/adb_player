/// 手册条目：命令可复制
class HandbookEntry {
  final String group;
  final String title;
  final String? description;
  final String command;

  const HandbookEntry({
    required this.group,
    required this.title,
    required this.command,
    this.description,
  });

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return group.toLowerCase().contains(q) ||
        title.toLowerCase().contains(q) ||
        (description?.toLowerCase().contains(q) ?? false) ||
        command.toLowerCase().contains(q);
  }
}

/// ADB 速查（尽量覆盖 host 命令 + 高频 shell）
/// 基于 platform-tools adb help 与常用调试场景整理
const List<HandbookEntry> kHandbookEntries = [
  // ── 全局选项 / 指定设备 ──
  HandbookEntry(
    group: '全局 / 指定设备',
    title: '指定序列号',
    description: '多设备时覆盖 \$ANDROID_SERIAL',
    command: 'adb -s <serial> <command>',
  ),
  HandbookEntry(
    group: '全局 / 指定设备',
    title: '只用 USB 设备',
    command: 'adb -d <command>',
  ),
  HandbookEntry(
    group: '全局 / 指定设备',
    title: '只用 TCP/IP（无线/模拟器）设备',
    command: 'adb -e <command>',
  ),
  HandbookEntry(
    group: '全局 / 指定设备',
    title: '按 transport id 指定设备',
    command: 'adb -t <id> <command>',
  ),
  HandbookEntry(
    group: '全局 / 指定设备',
    title: '指定 ADB server 主机',
    command: 'adb -H <host> <command>',
  ),
  HandbookEntry(
    group: '全局 / 指定设备',
    title: '指定 ADB server 端口',
    command: 'adb -P <port> <command>',
  ),

  // ── 通用 / 服务 ──
  HandbookEntry(
    group: '通用 / 服务',
    title: '查看设备列表',
    command: 'adb devices',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '查看设备列表（详细）',
    command: 'adb devices -l',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: 'ADB 帮助',
    command: 'adb help',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: 'ADB 版本',
    command: 'adb version',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '启动 ADB server',
    command: 'adb start-server',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '结束 ADB server',
    command: 'adb kill-server',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '重启 ADB 服务',
    command: 'adb kill-server && adb start-server',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '强制重连（主机侧）',
    command: 'adb reconnect',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '强制重连（设备侧）',
    command: 'adb reconnect device',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '重置 offline/unauthorized 设备',
    command: 'adb reconnect offline',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '等待设备就绪',
    command: 'adb wait-for-device',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '等待 USB 设备',
    command: 'adb wait-for-usb-device',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '等待进入 recovery',
    command: 'adb wait-for-recovery',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '等待进入 bootloader',
    command: 'adb wait-for-bootloader',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '等待断开连接',
    command: 'adb wait-for-disconnect',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '获取连接状态',
    description: 'offline | bootloader | device',
    command: 'adb get-state',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '获取序列号',
    command: 'adb get-serialno',
  ),
  HandbookEntry(
    group: '通用 / 服务',
    title: '获取设备路径',
    command: 'adb get-devpath',
  ),

  // ── 网络 / 无线 ──
  HandbookEntry(
    group: '网络 / 无线',
    title: 'TCP/IP 连接设备',
    description: '默认端口 5555',
    command: 'adb connect <host>[:<port>]',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '断开 TCP/IP 连接',
    description: '不写地址则断开全部',
    command: 'adb disconnect [<host>[:<port>]]',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '无线配对（Android 11+）',
    command: 'adb pair <host>:<port> [<pairing_code>]',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '切换 adbd 为 TCP 监听',
    description: '常见端口 5555；需先 USB 连上',
    command: 'adb tcpip 5555',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '切换 adbd 回 USB',
    command: 'adb usb',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '检查 mDNS',
    command: 'adb mdns check',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '列出 mDNS 服务',
    command: 'adb mdns services',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '端口转发列表',
    command: 'adb forward --list',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '端口转发（本机→设备）',
    command: 'adb forward tcp:<local> tcp:<remote>',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '端口转发（不重绑）',
    command: 'adb forward --no-rebind tcp:<local> tcp:<remote>',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '转发到 JDWP',
    command: 'adb forward tcp:<local> jdwp:<pid>',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '转发到 abstract socket',
    command: 'adb forward tcp:<local> localabstract:<name>',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '移除指定转发',
    command: 'adb forward --remove tcp:<local>',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '移除全部转发',
    command: 'adb forward --remove-all',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '反向端口列表',
    command: 'adb reverse --list',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '反向端口（设备→本机）',
    description: '设备访问本机服务常用',
    command: 'adb reverse tcp:<remote> tcp:<local>',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '移除指定反向端口',
    command: 'adb reverse --remove tcp:<remote>',
  ),
  HandbookEntry(
    group: '网络 / 无线',
    title: '移除全部反向端口',
    command: 'adb reverse --remove-all',
  ),

  // ── 文件传输 ──
  HandbookEntry(
    group: '文件传输',
    title: '推送文件到设备',
    command: 'adb push <local> <remote>',
  ),
  HandbookEntry(
    group: '文件传输',
    title: '推送（仅同步有变化的）',
    command: 'adb push --sync <local> <remote>',
  ),
  HandbookEntry(
    group: '文件传输',
    title: '推送（禁用压缩）',
    command: 'adb push -Z <local> <remote>',
  ),
  HandbookEntry(
    group: '文件传输',
    title: '从设备拉取文件',
    command: 'adb pull <remote> <local>',
  ),
  HandbookEntry(
    group: '文件传输',
    title: '拉取并保留时间戳/权限',
    command: 'adb pull -a <remote> <local>',
  ),
  HandbookEntry(
    group: '文件传输',
    title: '同步本地编译产物到设备',
    description: '依赖 \$ANDROID_PRODUCT_OUT',
    command: 'adb sync [all|system|vendor|data|...]',
  ),
  HandbookEntry(
    group: '文件传输',
    title: '列出将同步的文件（不真正拷贝）',
    command: 'adb sync -l',
  ),

  // ── Shell ──
  HandbookEntry(
    group: 'Shell',
    title: '进入交互 Shell',
    command: 'adb shell',
  ),
  HandbookEntry(
    group: 'Shell',
    title: '执行单条 Shell 命令',
    command: 'adb shell <command>',
  ),
  HandbookEntry(
    group: 'Shell',
    title: 'Shell 禁用 PTY',
    command: 'adb shell -T <command>',
  ),
  HandbookEntry(
    group: 'Shell',
    title: 'Shell 强制分配 PTY',
    command: 'adb shell -tt <command>',
  ),
  HandbookEntry(
    group: 'Shell',
    title: '模拟器控制台命令',
    command: 'adb emu <command>',
  ),

  // ── 安装 / 卸载 ──
  HandbookEntry(
    group: '安装 / 卸载',
    title: '安装 APK',
    command: 'adb install app.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '覆盖安装',
    command: 'adb install -r app.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '允许测试包安装',
    command: 'adb install -t app.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '允许降级安装',
    description: '仅 debuggable 包',
    command: 'adb install -d app.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '安装并授予全部运行时权限',
    command: 'adb install -r -g app.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '安装为 Instant App',
    command: 'adb install --instant app.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '指定 ABI 安装',
    command: 'adb install --abi armeabi-v7a app.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '流式安装',
    command: 'adb install --streaming app.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '禁用流式安装',
    command: 'adb install --no-streaming app.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: 'Fast Deploy 安装',
    command: 'adb install --fastdeploy app.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '安装 split APKs',
    command: 'adb install-multiple base.apk split1.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '原子安装多包',
    command: 'adb install-multi-package a.apk b.apk',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '卸载应用',
    command: 'adb uninstall <package>',
  ),
  HandbookEntry(
    group: '安装 / 卸载',
    title: '卸载但保留数据',
    command: 'adb uninstall -k <package>',
  ),

  // ── 调试 / 日志 ──
  HandbookEntry(
    group: '调试 / 日志',
    title: '生成 Bugreport',
    command: 'adb bugreport',
  ),
  HandbookEntry(
    group: '调试 / 日志',
    title: 'Bugreport 保存到路径',
    command: 'adb bugreport ./bugreport.zip',
  ),
  HandbookEntry(
    group: '调试 / 日志',
    title: '列出 JDWP 进程',
    command: 'adb jdwp',
  ),
  HandbookEntry(
    group: '调试 / 日志',
    title: 'Logcat 全部输出',
    command: 'adb logcat',
  ),
  HandbookEntry(
    group: '调试 / 日志',
    title: 'Logcat 清空缓冲',
    command: 'adb logcat -c',
  ),
  HandbookEntry(
    group: '调试 / 日志',
    title: 'Logcat 导出到文件',
    command: 'adb logcat -d > log.txt',
  ),
  HandbookEntry(
    group: '调试 / 日志',
    title: 'Logcat 指定格式',
    command: 'adb logcat -v threadtime',
  ),
  HandbookEntry(
    group: '调试 / 日志',
    title: 'Logcat 只看 Error',
    command: 'adb logcat *:E',
  ),
  HandbookEntry(
    group: '调试 / 日志',
    title: 'Logcat 按 TAG 过滤',
    command: 'adb logcat -s MyTag:I *:S',
  ),
  HandbookEntry(
    group: '调试 / 日志',
    title: 'Logcat 按包名（Android 7+）',
    command: 'adb logcat --pid=\$(adb shell pidof -s <package>)',
  ),
  HandbookEntry(
    group: '调试 / 日志',
    title: 'Logcat 缓冲区选择',
    description: 'main/system/crash/events/radio 等',
    command: 'adb logcat -b all',
  ),
  HandbookEntry(
    group: '调试 / 日志',
    title: 'Logcat 最大行数',
    command: 'adb logcat -t 200',
  ),

  // ── 安全 / root / 重启 ──
  HandbookEntry(
    group: '安全 / root / 重启',
    title: '以 root 重启 adbd',
    description: '需 userdebug/eng',
    command: 'adb root',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: '取消 root adbd',
    command: 'adb unroot',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: '重新挂载分区可写',
    command: 'adb remount',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: 'remount 后自动重启',
    command: 'adb remount -R',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: '禁用 dm-verity',
    command: 'adb disable-verity',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: '启用 dm-verity',
    command: 'adb enable-verity',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: '生成 adb 密钥',
    command: 'adb keygen ~/.android/adbkey',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: '重启设备',
    command: 'adb reboot',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: '重启到 bootloader',
    command: 'adb reboot bootloader',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: '重启到 recovery',
    command: 'adb reboot recovery',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: '重启并进入 sideload',
    command: 'adb reboot sideload',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: 'sideload OTA 包',
    command: 'adb sideload update.zip',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: 'USB attach',
    command: 'adb attach',
  ),
  HandbookEntry(
    group: '安全 / root / 重启',
    title: 'USB detach',
    command: 'adb detach',
  ),

  // ── pm 包管理 ──
  HandbookEntry(
    group: 'pm 包管理',
    title: '列出全部包名',
    command: 'adb shell pm list packages',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '仅第三方包',
    command: 'adb shell pm list packages -3',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '仅系统包',
    command: 'adb shell pm list packages -s',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '仅已禁用包',
    command: 'adb shell pm list packages -d',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '仅已启用包',
    command: 'adb shell pm list packages -e',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '包名关键词过滤',
    command: 'adb shell pm list packages <keyword>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '列出包及安装路径',
    command: 'adb shell pm path <package>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '清除应用数据',
    command: 'adb shell pm clear <package>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '授予权限',
    command: 'adb shell pm grant <package> <permission>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '撤销权限',
    command: 'adb shell pm revoke <package> <permission>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '重置全部权限',
    command: 'adb shell pm reset-permissions',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '列出权限组',
    command: 'adb shell pm list permissions -g',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '列出危险权限',
    command: 'adb shell pm list permissions -d -g',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '启用应用',
    command: 'adb shell pm enable <package>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '禁用应用',
    command: 'adb shell pm disable-user --user 0 <package>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '隐藏应用',
    command: 'adb shell pm hide <package>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '取消隐藏应用',
    command: 'adb shell pm unhide <package>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '设置默认 App（示例）',
    command: 'adb shell cmd package set-home-activity <package>/<activity>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: 'dump 包信息',
    command: 'adb shell dumpsys package <package>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: 'cmd package 安装',
    command: 'adb shell cmd package install -r /data/local/tmp/app.apk',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: 'cmd package 卸载',
    command: 'adb shell cmd package uninstall <package>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '编译优化应用',
    command: 'adb shell cmd package compile -m speed -f <package>',
  ),
  HandbookEntry(
    group: 'pm 包管理',
    title: '查看包大小',
    command: 'adb shell dumpsys package <package> | grep -E "codePath|versionName|versionCode"',
  ),

  // ── am Activity Manager ──
  HandbookEntry(
    group: 'am Activity Manager',
    title: '启动 Activity（组件名）',
    command: 'adb shell am start -n <package>/<activity>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '启动 Activity（Action）',
    command: 'adb shell am start -a android.intent.action.VIEW -d <uri>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '启动并等待调试',
    command: 'adb shell am start -D -n <package>/<activity>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '启动并停止旧进程',
    command: 'adb shell am start -S -n <package>/<activity>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '启动带 Extra',
    command: 'adb shell am start -n <package>/<activity> --es key value',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '强制停止应用',
    command: 'adb shell am force-stop <package>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '杀死进程',
    command: 'adb shell am kill <package>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '杀死全部后台',
    command: 'adb shell am kill-all',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '发送广播',
    command: 'adb shell am broadcast -a <action>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '发送带包名广播',
    command: 'adb shell am broadcast -a <action> -n <package>/<receiver>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '启动 Service',
    command: 'adb shell am startservice -n <package>/<service>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '停止 Service',
    command: 'adb shell am stopservice -n <package>/<service>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '查看当前 Activity 栈',
    command: 'adb shell am stack list',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: 'instrument 测试',
    command: 'adb shell am instrument -w <test_package>/<runner>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '显示内存信息',
    command: 'adb shell am dumpheap <package> /data/local/tmp/heap.hprof',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '切换到指定用户',
    command: 'adb shell am switch-user <userId>',
  ),
  HandbookEntry(
    group: 'am Activity Manager',
    title: '获取前台包名（精简）',
    command: 'adb shell dumpsys activity activities | grep -E "mResumedActivity|topResumedActivity"',
  ),

  // ── input ──
  HandbookEntry(
    group: '输入',
    title: '点击坐标',
    command: 'adb shell input tap <x> <y>',
  ),
  HandbookEntry(
    group: '输入',
    title: '长按（swipe 同点）',
    command: 'adb shell input swipe <x> <y> <x> <y> <ms>',
  ),
  HandbookEntry(
    group: '输入',
    title: '滑动',
    command: 'adb shell input swipe <x1> <y1> <x2> <y2> [ms]',
  ),
  HandbookEntry(
    group: '输入',
    title: '输入文本',
    description: '空格用 %s；中文受限',
    command: 'adb shell input text "hello%sworld"',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键事件（keycode）',
    command: 'adb shell input keyevent <keycode>',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：返回',
    command: 'adb shell input keyevent 4',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：Home',
    command: 'adb shell input keyevent 3',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：最近任务',
    command: 'adb shell input keyevent 187',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：电源',
    command: 'adb shell input keyevent 26',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：唤醒',
    command: 'adb shell input keyevent 224',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：睡眠',
    command: 'adb shell input keyevent 223',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：音量+',
    command: 'adb shell input keyevent 24',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：音量-',
    command: 'adb shell input keyevent 25',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：静音',
    command: 'adb shell input keyevent 164',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：菜单',
    command: 'adb shell input keyevent 82',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：回车',
    command: 'adb shell input keyevent 66',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：删除',
    command: 'adb shell input keyevent 67',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：Tab',
    command: 'adb shell input keyevent 61',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：方向上',
    command: 'adb shell input keyevent 19',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：方向下',
    command: 'adb shell input keyevent 20',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：方向左',
    command: 'adb shell input keyevent 21',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：方向右',
    command: 'adb shell input keyevent 22',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：相机',
    command: 'adb shell input keyevent 27',
  ),
  HandbookEntry(
    group: '输入',
    title: '按键：打开通知栏',
    command: 'adb shell input keyevent 83',
  ),
  HandbookEntry(
    group: '输入',
    title: '滚动事件',
    command: 'adb shell input roll <dx> <dy>',
  ),
  HandbookEntry(
    group: '输入',
    title: '发送 motion 事件',
    command: 'adb shell input motionevent DOWN <x> <y>',
  ),

  // ── 截图 / 录屏 ──
  HandbookEntry(
    group: '截图 / 录屏',
    title: '截图到设备',
    command: 'adb shell screencap -p /sdcard/screen.png',
  ),
  HandbookEntry(
    group: '截图 / 录屏',
    title: '截图并拉到本机',
    command:
        'adb shell screencap -p /sdcard/screen.png && adb pull /sdcard/screen.png .',
  ),
  HandbookEntry(
    group: '截图 / 录屏',
    title: '录屏',
    description: 'Ctrl+C 结束；默认最长约 180s',
    command: 'adb shell screenrecord /sdcard/demo.mp4',
  ),
  HandbookEntry(
    group: '截图 / 录屏',
    title: '录屏指定分辨率/码率',
    command:
        'adb shell screenrecord --size 1280x720 --bit-rate 4000000 /sdcard/demo.mp4',
  ),
  HandbookEntry(
    group: '截图 / 录屏',
    title: '录屏限时（秒）',
    command: 'adb shell screenrecord --time-limit 30 /sdcard/demo.mp4',
  ),
  HandbookEntry(
    group: '截图 / 录屏',
    title: '录屏显示触点',
    command: 'adb shell screenrecord --show-touches /sdcard/demo.mp4',
  ),

  // ── getprop / settings ──
  HandbookEntry(
    group: '属性 / 设置',
    title: '获取全部属性',
    command: 'adb shell getprop',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '获取品牌',
    command: 'adb shell getprop ro.product.brand',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '获取型号',
    command: 'adb shell getprop ro.product.model',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '获取设备名',
    command: 'adb shell getprop ro.product.device',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: 'Android 版本',
    command: 'adb shell getprop ro.build.version.release',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: 'SDK 版本',
    command: 'adb shell getprop ro.build.version.sdk',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '安全补丁级别',
    command: 'adb shell getprop ro.build.version.security_patch',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: 'Build ID / Fingerprint',
    command: 'adb shell getprop ro.build.fingerprint',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '序列号',
    command: 'adb shell getprop ro.serialno',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: 'CPU ABI',
    command: 'adb shell getprop ro.product.cpu.abi',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '是否 debuggable',
    command: 'adb shell getprop ro.debuggable',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '设置属性（需权限）',
    command: 'adb shell setprop <key> <value>',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '读取 settings global',
    command: 'adb shell settings get global <key>',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '写入 settings global',
    command: 'adb shell settings put global <key> <value>',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '读取 settings system',
    command: 'adb shell settings get system <key>',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '写入 settings system',
    command: 'adb shell settings put system <key> <value>',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '读取 settings secure',
    command: 'adb shell settings get secure <key>',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '写入 settings secure',
    command: 'adb shell settings put secure <key> <value>',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '关闭窗口动画',
    command: 'adb shell settings put global window_animation_scale 0',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '关闭过渡动画',
    command: 'adb shell settings put global transition_animation_scale 0',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '关闭动画时长缩放',
    command: 'adb shell settings put global animator_duration_scale 0',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '打开指针位置',
    command: 'adb shell settings put system pointer_location 1',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '关闭指针位置',
    command: 'adb shell settings put system pointer_location 0',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '打开显示点按反馈',
    command: 'adb shell settings put system show_touches 1',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '保持屏幕常亮（充电时）',
    command: 'adb shell settings put global stay_on_while_plugged_in 3',
  ),
  HandbookEntry(
    group: '属性 / 设置',
    title: '设置屏幕超时（ms）',
    command: 'adb shell settings put system screen_off_timeout 300000',
  ),

  // ── dumpsys / 系统信息 ──
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: 'dumpsys 列表服务',
    command: 'adb shell service list',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '当前焦点窗口',
    command: 'adb shell dumpsys window | grep -E "mCurrentFocus|mFocusedApp"',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '窗口尺寸/密度',
    command: 'adb shell wm size && adb shell wm density',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '设置分辨率',
    command: 'adb shell wm size 1080x1920',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '重置分辨率',
    command: 'adb shell wm size reset',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '设置密度',
    command: 'adb shell wm density 420',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '重置密度',
    command: 'adb shell wm density reset',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '电池信息',
    command: 'adb shell dumpsys battery',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '模拟未充电',
    command: 'adb shell dumpsys battery unplug',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '设置电量百分比',
    command: 'adb shell dumpsys battery set level 50',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '重置电池模拟',
    command: 'adb shell dumpsys battery reset',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '内存信息',
    command: 'adb shell dumpsys meminfo <package>',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: 'CPU 信息',
    command: 'adb shell dumpsys cpuinfo',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '网络状态',
    command: 'adb shell dumpsys connectivity',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: 'Wi‑Fi 信息',
    command: 'adb shell dumpsys wifi',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '通知信息',
    command: 'adb shell dumpsys notification',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '传感器信息',
    command: 'adb shell dumpsys sensorservice',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '电源管理',
    command: 'adb shell dumpsys power',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: 'Alarm 列表',
    command: 'adb shell dumpsys alarm',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: 'JobScheduler',
    command: 'adb shell dumpsys jobscheduler',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: 'SurfaceFlinger',
    command: 'adb shell dumpsys SurfaceFlinger',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: 'gfxinfo 性能',
    command: 'adb shell dumpsys gfxinfo <package>',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '重置 gfxinfo',
    command: 'adb shell dumpsys gfxinfo <package> reset',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '进程列表',
    command: 'adb shell ps -A',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '查找进程 PID',
    command: 'adb shell pidof <package>',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: 'top 进程',
    command: 'adb shell top -n 1',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '磁盘空间',
    command: 'adb shell df -h',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: '设备 IP',
    command: 'adb shell ip addr show wlan0',
  ),
  HandbookEntry(
    group: 'dumpsys / 系统信息',
    title: 'ping 测试',
    command: 'adb shell ping -c 4 8.8.8.8',
  ),

  // ── ime / 剪贴板 / content ──
  HandbookEntry(
    group: '输入法 / Content',
    title: '列出输入法',
    command: 'adb shell ime list -s',
  ),
  HandbookEntry(
    group: '输入法 / Content',
    title: '设置输入法',
    command: 'adb shell ime set <ime_id>',
  ),
  HandbookEntry(
    group: '输入法 / Content',
    title: '启用输入法',
    command: 'adb shell ime enable <ime_id>',
  ),
  HandbookEntry(
    group: '输入法 / Content',
    title: '写入剪贴板（需支持）',
    command: 'adb shell cmd clipboard set-text "hello"',
  ),
  HandbookEntry(
    group: '输入法 / Content',
    title: 'content query 示例',
    command: 'adb shell content query --uri content://settings/system',
  ),
  HandbookEntry(
    group: '输入法 / Content',
    title: 'content insert 示例',
    command:
        'adb shell content insert --uri content://settings/system --bind name:s:accelerometer_rotation --bind value:i:0',
  ),

  // ── monkey / 测试 ──
  HandbookEntry(
    group: 'Monkey / 测试',
    title: 'Monkey 随机事件',
    command: 'adb shell monkey -p <package> -v 500',
  ),
  HandbookEntry(
    group: 'Monkey / 测试',
    title: 'Monkey 指定种子',
    command: 'adb shell monkey -p <package> -s 12345 -v 500',
  ),
  HandbookEntry(
    group: 'Monkey / 测试',
    title: 'Monkey 节流',
    command: 'adb shell monkey -p <package> --throttle 300 -v 200',
  ),
  HandbookEntry(
    group: 'Monkey / 测试',
    title: 'uiautomator dump',
    command: 'adb shell uiautomator dump /sdcard/window_dump.xml',
  ),
  HandbookEntry(
    group: 'Monkey / 测试',
    title: '拉取 UI dump',
    command:
        'adb shell uiautomator dump /sdcard/window_dump.xml && adb pull /sdcard/window_dump.xml',
  ),

  // ── 权限快捷 / 开发者常用 ──
  HandbookEntry(
    group: '权限 / Intent',
    title: '授予相机权限',
    command: 'adb shell pm grant <package> android.permission.CAMERA',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '授予麦克风权限',
    command: 'adb shell pm grant <package> android.permission.RECORD_AUDIO',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '授予定位权限',
    command:
        'adb shell pm grant <package> android.permission.ACCESS_FINE_LOCATION',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '授予存储读权限',
    command:
        'adb shell pm grant <package> android.permission.READ_EXTERNAL_STORAGE',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '授予通知权限（API 33+）',
    command:
        'adb shell pm grant <package> android.permission.POST_NOTIFICATIONS',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: 'AppOps 允许（示例）',
    command: 'adb shell appops set <package> CAMERA allow',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: 'AppOps 查询',
    command: 'adb shell appops get <package>',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '打开应用详情页',
    command:
        'adb shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:<package>',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '打开开发者选项',
    command: 'adb shell am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '打开无线设置',
    command: 'adb shell am start -a android.settings.WIFI_SETTINGS',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '打开蓝牙设置',
    command: 'adb shell am start -a android.settings.BLUETOOTH_SETTINGS',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '打开日期时间设置',
    command: 'adb shell am start -a android.settings.DATE_SETTINGS',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '拨号 Intent',
    command: 'adb shell am start -a android.intent.action.DIAL -d tel:10086',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '打开网页 Intent',
    command: 'adb shell am start -a android.intent.action.VIEW -d https://www.android.com',
  ),
  HandbookEntry(
    group: '权限 / Intent',
    title: '分享文本 Intent',
    command:
        'adb shell am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT "hello"',
  ),

  // ── 环境变量提示（可复制说明） ──
  HandbookEntry(
    group: '环境变量',
    title: '环境变量 ANDROID_SERIAL',
    description: '默认操作该序列号设备',
    command: 'export ANDROID_SERIAL=<serial>',
  ),
  HandbookEntry(
    group: '环境变量',
    title: '环境变量 ADB_TRACE',
    description: '调试 adb 自身：all,usb,sockets...',
    command: 'export ADB_TRACE=all',
  ),
  HandbookEntry(
    group: '环境变量',
    title: '环境变量 ANDROID_LOG_TAGS',
    command: 'export ANDROID_LOG_TAGS="ActivityManager:I MyApp:D *:S"',
  ),
  HandbookEntry(
    group: '环境变量',
    title: '环境变量 ADB_MDNS_AUTO_CONNECT',
    description: '设为 0 可关闭 mDNS 自动连接',
    command: 'export ADB_MDNS_AUTO_CONNECT=0',
  ),
];
