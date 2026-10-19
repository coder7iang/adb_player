# AdbPlayer

当前版本：**1.2.1**

AdbPlayer 是一款基于 Flutter 的桌面端 Android 设备调试工具，面向开发与测试人员，把日常需要敲命令的 ADB 操作封装成可视化界面。支持 USB 与无线（Wi-Fi）连接，覆盖应用管理、文件管理、日志抓取、投屏、Monkey 测试等常用调试场景。

支持 **macOS / Windows / Linux** 三端桌面运行（预编译安装包目前提供 macOS / Windows）。

## 下载

- **Windows**：[AdbPlayer-win.rar](https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/AdbPlayer/AdbPlayer-win.rar)
- **macOS**：[AdbPlayer-mac.zip](https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/AdbPlayer/AdbPlayer-mac.zip)
- **Linux**：暂无预编译包，请按下方「开发与构建」自行编译

> Windows 版为完整运行包（含 exe 与依赖 DLL），解压后运行 `adb_player.exe` 即可，请勿只复制单个 exe 文件。

### macOS 首次打开提示

由于应用未经 Apple 公证，从网络下载后 macOS 会拦截打开。把 `AdbPlayer.app` 拖到 `/Applications` 后，在终端执行一次以下命令即可正常使用：

```bash
sudo xattr -cr /Applications/AdbPlayer.app
```

之后双击打开即可，无需再每次去「系统设置 → 隐私与安全性」放行。

使用无线调试（二维码配对 / 局域网发现）时，请在「系统设置 → 隐私与安全性 → 本地网络」中允许 AdbPlayer。

## 功能特性

### 设备连接
- USB 连接自动识别已授权设备
- 无线（Wi-Fi）连接：
  - **二维码配对**（Android 11+）：电脑展示二维码，手机「无线调试 → 使用二维码配对」扫码后自动配对并连接
  - **手动连接**：粘贴手机上的 `IP:端口` 即可；首次配对再填 6 位配对码，已配对设备无需重复配对
  - 自动发现局域网可连接设备，一键连接
  - 同机 `ip:port` 与 mDNS 双通道去重，手动断开后不会自动重连（USB 插拔仍可自动识别）
- 多设备切换

### 常用功能
- 安装应用（支持拖拽 APK 安装）
- 截图保存到电脑
- 录屏
- 查看当前 Activity
- 输入文本
- 投屏（基于 scrcpy，统一使用应用内 ADB，避免无线双通道干扰）

### 应用管理
- 启动 / 停止 / 重启应用
- 卸载应用
- 清除数据（可选清除后重启）
- 重置权限 / 授权所有权限
- 查看安装路径、导出 APK
- 查看签名信息、应用信息
- 修改 SharedPreferences（SP）
- 私有目录浏览（通过 `run-as` 访问应用私有文件）
- Monkey 压力测试

### 系统信息与控制
- 查看 AndroidId、系统版本、IP 地址、Mac 地址
- 查看系统属性
- 重启手机

### 按键与屏幕操作
- HOME / 返回 / 菜单 / 电源 / 音量 / 静音 / 切换应用 等按键模拟
- 上下左右滑动、屏幕点击
- 遥控器模式

### 网络调试
- 代理调试（一键设置 / 清除全局代理）

### 其他模块
- 文件管理：浏览设备文件，上传 / 下载
- 日志管理：实时抓取并过滤 logcat 日志，导出到本地
- 开发者手册：常用 ADB 命令速查与说明
- 系统托盘常驻，关闭窗口最小化到托盘
- 设置页可配置 ADB / scrcpy 路径与截图保存目录；未配置时会尝试自动下载平台工具
- 趣味页：吃什么转盘、劳动法 PDF、装忙模式、短视频、去水印（抖音 / 快手视频与图文）等

## 更新说明（1.2.1）

- 新增无线调试二维码配对
- 简化手动无线连接表单（地址 + 可选配对码）
- 修复无线设备断开、列表重复条目、设备选择弹窗卡顿等问题
- 投屏改用应用内 ADB，禁用无线 mDNS 自动重连

## 技术栈

- **Flutter**（Dart SDK `>=3.10.0`，Flutter `>=3.38.0`）
- **状态管理**：flutter_riverpod / riverpod_annotation
- **桌面集成**：window_manager、system_tray、desktop_drop、file_selector
- **核心能力**：process_run（调用 ADB / scrcpy）、dio、archive、webview_flutter、video_player、audioplayers、pdfx、lottie、qr_flutter

## 开发与构建

本项目使用 [FVM](https://fvm.app/) 管理 Flutter 版本（见 `.fvmrc`）。

```bash
# 获取依赖
flutter pub get

# 本地运行（按当前平台）
flutter run -d macos      # 或 windows / linux

# 构建发布产物
flutter build macos
flutter build windows
flutter build linux
```

> 首次使用调试 / 投屏功能时，若本机未配置 `adb` / `scrcpy`，应用会尝试自动下载到本地缓存目录；也可在设置页手动指定路径。

## 项目结构

```
lib/
├── main.dart            # 入口，窗口与系统托盘初始化
├── common/              # 通用工具、键码、全局配置
├── services/            # adb / scrcpy / 视频缓存 / 去水印解析 等
├── page/                # 主要页面
│   ├── main/            #   主框架与左侧导航
│   ├── feature/         #   功能面板（各类调试操作）
│   ├── flie/            #   文件管理
│   ├── log/             #   日志管理
│   ├── handbook/        #   开发者手册
│   ├── setting/         #   设置
│   ├── play/            #   趣味功能（含去水印等）
│   ├── web/ about/
├── dialog/              # 各类对话框（设备选择、无线连接、Monkey、录屏等）
├── entity/              # 数据模型
└── widget/              # 通用组件
```

## 截图

<img width="960" height="720" alt="image" src="https://github.com/user-attachments/assets/dac209f6-cbd6-4776-a284-c1c9a67f4324" />

<img width="960" height="720" alt="image" src="https://github.com/user-attachments/assets/1ecddbf6-3e91-4364-a066-da2253834adf" />

<img width="960" height="720" alt="image" src="https://github.com/user-attachments/assets/f8c42ec3-ba54-47e5-b500-75593576ae82" />
