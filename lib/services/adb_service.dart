import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:adb_player/common/app.dart';
import 'package:adb_player/common/key_code.dart';
import 'package:adb_player/dialog/devices_model.dart';
import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:adb_player/entity/app_info.dart';
import 'package:adb_player/entity/app_signature_info.dart';
import 'package:adb_player/entity/list_filter_item.dart';
import 'package:adb_player/entity/monkey_result.dart';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell_run.dart';
import 'package:image/image.dart' as img;

/// ADB 服务类，封装所有 ADB 相关操作
class AdbService {
  static AdbService? _instance;
  static AdbService get instance => _instance ??= AdbService._();
  AdbService._();
  String adbPath = "";
  String currentDeviceId = "";
  String selectedPackage = "";

  /// 防止并发重复下载 ADB
  static Future<String>? _downloadingAdb;

  /// 是否已因「手动断开无线」禁用过 mDNS 自动重连
  bool _wirelessAutoConnectDisabled = false;

  /// 供外部（如 scrcpy）判断：仅手动断开后才应带上禁用自动连接的环境变量
  bool get isWirelessAutoConnectDisabled => _wirelessAutoConnectDisabled;

  /// ADB 进程环境：手动断开后才写入 ADB_MDNS_AUTO_CONNECT=0
  Map<String, String> get _adbEnvironment {
    final env = Map<String, String>.from(Platform.environment);
    if (_wirelessAutoConnectDisabled) {
      env['ADB_MDNS_AUTO_CONNECT'] = '0';
    }
    return env;
  }

  /// 设置 ADB 路径
  Future<void> setAdbPath(String path) async {
    adbPath = path;
    await App().setAdbPath(path);
  }

  /// 获取 ADB 路径
  _getAdbPath() async {
    String adbPath = await App().getAdbPath();
    if (adbPath.isNotEmpty && await File(adbPath).exists()) {
      this.adbPath = adbPath;
      return true;
    }
    return false;
  }


  /// 执行系统命令
  /// 返回 ProcessResult 或 null（如果执行失败）
  /// 异常信息会记录在日志中，调用方需要检查返回值并处理错误
  Future<dynamic> _exec(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    if (Platform.isWindows && executable.toLowerCase().endsWith('.exe')) {
      return _execProcessWithRetry(
        executable,
        arguments,
        environment: environment,
      );
    }
    try {
      var shell = Shell(
        environment: environment,
        includeParentEnvironment: environment == null,
      );
      var result = await shell.runExecutableArguments(executable, arguments);
      return result;
    } catch (e) {
      debugPrint('执行命令异常: $e');
      // 尝试从 ShellException 中提取 ProcessResult
      // ShellException 可能包含 result 属性
      try {
        // 使用动态类型检查来获取 result
        if (e is ShellException) {
          // ShellException 通常有 result 属性
          var exception = e as dynamic;
          if (exception.result != null) {
            return exception.result;
          }
        }
      } catch (_) {
        // 忽略提取错误
      }
      return null;
    }
  }

  /// Windows 下直接启动 exe，并在文件被占用时重试
  Future<ProcessResult?> _execProcessWithRetry(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    int maxAttempts = 6,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await Process.run(
          executable,
          arguments,
          environment: environment,
          includeParentEnvironment: environment == null,
          runInShell: false,
        );
      } on ProcessException catch (e) {
        final message = e.message;
        final locked = message.contains('另一个程序') ||
            message.contains('being used') ||
            message.contains('cannot access');
        if (locked && attempt < maxAttempts - 1) {
          final delayMs = 400 * (attempt + 1);
          debugPrint('可执行文件被占用，${delayMs}ms 后重试: $executable');
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        debugPrint('执行命令异常: $e');
        return null;
      }
    }
    return null;
  }

  /// 等待解压后的可执行文件在 Windows 上可用
  Future<bool> _waitUntilExecutableReady(String path) async {
    final file = File(path);
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await file.exists()) {
        try {
          final handle = await file.open(mode: FileMode.read);
          await handle.close();
          return true;
        } catch (_) {}
      }
      await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }
    return false;
  }

  /// 执行 ADB 命令
  /// 返回 ProcessResult 或 null（如果执行失败）
  /// 如果抛出异常，会尝试从异常中提取 ProcessResult
  Future<ProcessResult?> _execAdb(List<String> arguments) async {
    try {
      var result = await _exec(
        adbPath,
        arguments,
        environment: _adbEnvironment,
      );
      return result;
    } catch (e) {
      debugPrint('执行 ADB 命令异常: $e');
      // 如果 _exec 返回 null，但抛出了异常，尝试从异常中提取 ProcessResult
      // 某些情况下，即使抛出异常，ProcessResult 仍然可用
      try {
        if (e is ShellException) {
          var exception = e as dynamic;
          if (exception.result != null) {
            return exception.result;
          }
        }
      } catch (_) {
        // 忽略提取错误
      }
      return null;
    }
  }

  /// 重启 adb server 并禁用无线 mDNS 自动连接
  /// 仅应在「手动断开无线」时调用；USB 插拔识别不受影响
  Future<void> _ensureWirelessAutoConnectDisabled() async {
    if (_wirelessAutoConnectDisabled || adbPath.isEmpty) return;
    try {
      // 先标记，保证随后 start-server / disconnect 都带上环境变量
      _wirelessAutoConnectDisabled = true;
      await _execAdb(['kill-server']);
      await _execAdb(['start-server']);
      debugPrint('已禁用 ADB 无线自动连接 (ADB_MDNS_AUTO_CONNECT=0)');
    } catch (e) {
      // 失败则回滚标记，避免后续误以为已禁用
      _wirelessAutoConnectDisabled = false;
      debugPrint('禁用无线自动连接失败: $e');
    }
  }

  /// 获取adb路径
  checkAdb() async {
    bool hasAdb = await _getAdbPath();
    if (hasAdb) {
      debugPrint('使用已缓存的 ADB: $adbPath');
      // 启动不再 kill-server，避免拖慢 USB / 已有设备枚举
      return;
    }
    var executable = Platform.isWindows ? "where" : "which";
    var result = await _exec(executable, ['adb']);
    if (result != null && result.exitCode == 0) {
      // where 可能返回多行，只取第一行有效路径
      final lines = result.stdout
          .toString()
          .split(RegExp(r'[\r\n]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      final found = lines.isEmpty ? '' : lines.first;
      if (found.isNotEmpty && await File(found).exists()) {
        adbPath = found;
        await setAdbPath(adbPath);
        debugPrint('使用系统 PATH 中的 ADB: $adbPath');
        return;
      }
    }
    debugPrint('系统 PATH 未找到 adb，开始下载...');
    adbPath = await downloadAdb();
    if (adbPath.isNotEmpty) {
      await setAdbPath(adbPath);
      debugPrint('ADB 下载完成: $adbPath');
    } else {
      debugPrint('ADB 下载失败，请检查网络或在设置页手动配置路径');
    }
  }

  /// 下载 ADB 文件
  Future<String> downloadAdb() async {
    if (_downloadingAdb != null) {
      debugPrint('ADB 正在下载中，等待完成...');
      return _downloadingAdb!;
    }
    _downloadingAdb = _downloadAdbImpl();
    try {
      return await _downloadingAdb!;
    } finally {
      _downloadingAdb = null;
    }
  }

  Future<String> _downloadAdbImpl() async {
    try {
      var directory = await getTemporaryDirectory();
      var downloadPath = directory.path +
          Platform.pathSeparator +
          "platform-tools" +
          Platform.pathSeparator;

      await Directory(downloadPath).create(recursive: true);

      var url = "";
      if (Platform.isMacOS) {
        url =
            "https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/adb/platform-tools-latest-darwin.zip";
      } else if (Platform.isWindows) {
        url =
            "https://coder7iang-1320222289.cos.ap-guangzhou.myqcloud.com/adb/platform-tools-latest-windows.zip";
      } else {
        url =
            "https://dl.google.com/android/repository/platform-tools-latest-linux.zip";
      }

      var filePath = downloadPath + "platform-tools-latest.zip";
      debugPrint('开始下载 ADB: $url');
      var response = await Dio().download(url, filePath);
      debugPrint('ADB 下载响应: ${response.statusCode}');

      if (response.statusCode == 200) {
        String result = await unzipPlatformToolsFile(filePath);
        if (result.isNotEmpty) {
          debugPrint('ADB 解压完成: $result');
        } else {
          debugPrint('ADB 解压失败，未找到 adb.exe');
        }
        return result;
      }

      return "";
    } catch (e) {
      debugPrint('下载ADB失败: $e');
      return "";
    }
  }

  /// 解压 ADB zip 文件
  Future<String> unzipPlatformToolsFile(String unzipFilePath) async {
    try {
      var libraryDirectory = await getApplicationSupportDirectory();
      var savePath = libraryDirectory.path +
          Platform.pathSeparator +
          "adb" +
          Platform.pathSeparator;

      // 确保目录存在
      var directory = Directory(savePath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 尝试使用 archive 包解压
      try {
        var bytes = await File(unzipFilePath).readAsBytes();
        var archive = ZipDecoder().decodeBytes(bytes);
        extractArchiveToDisk(archive, savePath);
      } catch (e) {
        debugPrint('使用 archive 包解压失败，尝试使用系统命令: $e');
        // 如果 archive 包解压失败，尝试使用系统命令
        await _exec("rm", ["-rf", savePath]);
        await _exec("unzip", [unzipFilePath, "-d", savePath]);
        await _exec("rm", ["-rf", unzipFilePath]);
      }

      // 查找 adb 可执行文件
      var adbPath = "";
      if (Platform.isMacOS || Platform.isLinux) {
        adbPath = savePath + "platform-tools" + Platform.pathSeparator + "adb";
      } else if (Platform.isWindows) {
        adbPath =
            savePath + "platform-tools" + Platform.pathSeparator + "adb.exe";
      }

      if (await File(adbPath).exists()) {
        // 设置可执行权限
        if (Platform.isMacOS || Platform.isLinux) {
          await _exec("chmod", ["+x", adbPath]);
        } else if (Platform.isWindows) {
          final ready = await _waitUntilExecutableReady(adbPath);
          if (!ready) {
            debugPrint('ADB 文件尚未就绪: $adbPath');
          }
        }
        return adbPath;
      }

      return "";
    } catch (e) {
      debugPrint('解压ADB文件失败: $e');
      return "";
    }
  }

  /// 获取设备列表
  Future<List<DevicesModel>> getDeviceList() async {
    try {
      var result = await _execAdb(['devices']);
      if (result != null && result.exitCode == 0) {
        final ids = <String>[];
        var stdout = result.stdout.toString().trim();
        if (stdout.isNotEmpty) {
          for (var line in stdout.split('\n')) {
            line = line.trim();
            if (line.isEmpty) continue;
            if (line.contains("List of devices attached")) continue;
            // 仅匹配状态为 device 的行，避免误伤其他状态
            final parts = line.contains('\t')
                ? line.split('\t')
                : line.split(RegExp(r'\s+'));
            if (parts.length >= 2 && parts[1] == 'device') {
              ids.add(parts[0]);
            }
          }
        }
        // 先去重再查 brand/model，避免对重复的 mDNS 通道白跑 getprop
        final uniqueIds = await _dedupeWirelessSerialIds(ids);
        if (uniqueIds.isEmpty) return [];
        return Future.wait(uniqueIds.map((id) async {
          final info = await _getBrandAndModel(id);
          return DevicesModel(info.$1, info.$2, id);
        }));
      }
    } catch (e) {
      debugPrint('获取设备列表失败: $e');
    }
    return [];
  }

  /// 若同一无线设备同时存在 ip:port 与 mDNS 序列号，优先保留 ip:port
  Future<List<String>> _dedupeWirelessSerialIds(List<String> ids) async {
    final ipPortIds = ids
        .where((id) => RegExp(r'^\d+\.\d+\.\d+\.\d+:\d+$').hasMatch(id))
        .toSet();
    if (ipPortIds.isEmpty) return ids;

    final hasMdnsSerial = ids.any(
      (id) => id.contains('_adb-tls-connect._tcp'),
    );
    if (!hasMdnsSerial) return ids;

    final mdns = await listMdnsServices();
    final mdnsNamesToHide = <String>{};
    for (final s in mdns) {
      if (!s.isConnect) continue;
      if (!ipPortIds.contains(s.endpoint)) continue;
      mdnsNamesToHide.add(s.name);
      mdnsNamesToHide.add('${s.name}._adb-tls-connect._tcp');
    }

    // mDNS 列表暂时对不上时：按主机 IP 兜底隐藏同机的 tls-connect 通道
    if (mdnsNamesToHide.isEmpty) {
      final hosts = ipPortIds.map((e) => e.split(':').first).toSet();
      // 能从序列号里抠出的硬件号，用于和 USB 序列对照
      final usbSerials = ids
          .where((id) => !id.contains(':') && !id.contains('_adb-tls'))
          .toSet();

      return ids.where((id) {
        if (!id.contains('_adb-tls-connect._tcp')) return true;
        // 形如 adb-10AF140QX60026M-xxxx._adb-tls-connect._tcp
        final m = RegExp(r'^adb-([^-._]+)').firstMatch(id);
        if (m != null && usbSerials.contains(m.group(1))) {
          return false;
        }
        // 仅一台无线 ip:port 时，隐藏全部 mdns 项（同机双通道的常见情况）
        if (ipPortIds.length == 1) return false;
        // 多台时：若 mdns 服务能提供 host 信息再判；此处无 host 则保留以免误伤
        for (final s in mdns) {
          if (s.isConnect &&
              hosts.contains(s.host) &&
              (id == s.name ||
                  id == '${s.name}._adb-tls-connect._tcp' ||
                  id.startsWith('${s.name}.'))) {
            return false;
          }
        }
        return true;
      }).toList();
    }

    return ids.where((id) {
      if (!id.contains('_adb-tls-connect._tcp')) return true;
      if (mdnsNamesToHide.contains(id)) return false;
      for (final name in mdnsNamesToHide) {
        if (id == name || id.startsWith('$name.')) return false;
      }
      return true;
    }).toList();
  }

  /// 无线配对设备
  /// [host] 设备IP地址，[port] 配对端口，[code] 配对码
  Future<String> pairDevice(String host, String port, String code) async {
    try {
      var result = await _execAdb(['pair', '$host:$port', code]);
      if (result != null) {
        var stdout = result.stdout.toString().trim();
        var stderr = result.stderr.toString().trim();
        if (result.exitCode == 0 && stdout.contains('Successfully paired')) {
          return '配对成功';
        }
        return stderr.isNotEmpty ? stderr : stdout;
      }
      return '配对失败：未知错误';
    } catch (e) {
      return '配对异常: $e';
    }
  }

  /// 列出 mDNS 发现的 ADB 无线服务（配对 / 连接）
  Future<List<AdbMdnsService>> listMdnsServices() async {
    try {
      var result = await _execAdb(['mdns', 'services']);
      if (result == null) return [];
      final stdout = result.stdout.toString();
      final services = <AdbMdnsService>[];
      for (var line in stdout.split('\n')) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('List of')) continue;
        // 格式: name \t type \t ip:port（偶发 IPv6 时 endpoint 可能含多个冒号）
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 3) continue;
        final name = parts[0];
        final type = parts[1];
        final endpoint = parts.sublist(2).join(' ');
        final colon = endpoint.lastIndexOf(':');
        if (colon <= 0) continue;
        final host = endpoint.substring(0, colon);
        final port = endpoint.substring(colon + 1);
        if (host.isEmpty || port.isEmpty) continue;
        // 端口必须是数字，避免误解析
        if (int.tryParse(port) == null) continue;
        services.add(AdbMdnsService(
          name: name,
          type: type,
          host: host,
          port: port,
        ));
      }
      if (services.isEmpty && stdout.trim().isNotEmpty) {
        debugPrint('mdns services 原始输出无解析结果:\n$stdout');
      }
      return services;
    } catch (e) {
      debugPrint('获取 mDNS 服务失败: $e');
      return [];
    }
  }

  /// 检查 mDNS 是否可用
  Future<bool> isMdnsAvailable() async {
    try {
      var result = await _execAdb(['mdns', 'check']);
      if (result == null) return false;
      final out = '${result.stdout}${result.stderr}'.toLowerCase();
      return out.contains('version') || result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 无线连接设备
  /// [host] 设备IP地址，[port] 连接端口
  Future<String> connectDevice(String host, String port) async {
    try {
      // 主动连接不禁用自动重连；未手动断开前，自动连回是允许的
      var result = await _execAdb(['connect', '$host:$port']);
      if (result != null) {
        var stdout = result.stdout.toString().trim();
        var stderr = result.stderr.toString().trim();
        if (result.exitCode == 0 && stdout.contains('connected')) {
          // 清掉同机 mDNS 双通道，避免列表出现两条
          await _disconnectMdnsTwinsOf(host, keepEndpoint: '$host:$port');
          return '连接成功';
        }
        return stderr.isNotEmpty ? stderr : stdout;
      }
      return '连接失败：未知错误';
    } catch (e) {
      return '连接异常: $e';
    }
  }

  /// 断开同主机上的 mDNS 无线通道，保留指定的 ip:port
  Future<void> _disconnectMdnsTwinsOf(
    String host, {
    required String keepEndpoint,
  }) async {
    try {
      final serials = await _listRawConnectedSerials();
      final mdns = await listMdnsServices();
      final wirelessIpCount = serials
          .where((s) => RegExp(r'^\d+\.\d+\.\d+\.\d+:\d+$').hasMatch(s))
          .length;

      for (final id in serials) {
        if (id == keepEndpoint) continue;
        if (!id.contains('_adb-tls-connect._tcp')) continue;

        var sameHost = false;
        for (final s in mdns) {
          if (s.isConnect &&
              s.host == host &&
              (id == s.name ||
                  id == '${s.name}._adb-tls-connect._tcp' ||
                  id.startsWith('${s.name}.'))) {
            sameHost = true;
            break;
          }
        }
        if (!sameHost && wirelessIpCount != 1) continue;
        await _execAdb(['disconnect', id]);
      }
    } catch (e) {
      debugPrint('清理 mDNS 双通道失败: $e');
    }
  }

  /// 断开无线设备
  /// [deviceId] 可为 `ip:port` 或 mDNS 服务名（如 `xxx._adb-tls-connect._tcp`）
  /// 会同时断开同一物理设备上的 ip:port 与 mDNS 双通道；
  /// 手动断开时禁用 mDNS 自动重连，之后不会自动连回（USB 不受影响）
  Future<String> disconnectDevice(String deviceId) async {
    try {
      // 仅手动断开时禁用自动重连（会重启一次 adb server）
      await _ensureWirelessAutoConnectDisabled();
      final targets = await _relatedWirelessSerials(deviceId);
      String lastMsg = '';
      var anyOk = false;

      for (final id in targets) {
        var result = await _execAdb(['disconnect', id]);
        if (result != null) {
          final msg = result.stdout.toString().trim();
          if (msg.isNotEmpty) lastMsg = msg;
          if (result.exitCode == 0) anyOk = true;
        }
      }

      if (anyOk) {
        return lastMsg.isNotEmpty ? lastMsg : '已断开';
      }
      return lastMsg.isNotEmpty ? lastMsg : '断开失败';
    } catch (e) {
      return '断开异常: $e';
    }
  }

  /// 收集与 [deviceId] 对应同一台无线设备的所有 adb 序列号
  Future<Set<String>> _relatedWirelessSerials(String deviceId) async {
    final targets = <String>{deviceId};
    final connected = await _listRawConnectedSerials();
    final mdns = await listMdnsServices();

    String? host;
    String? endpoint;

    final ipPort = RegExp(r'^(\d+\.\d+\.\d+\.\d+):(\d+)$').firstMatch(deviceId);
    if (ipPort != null) {
      host = ipPort.group(1);
      endpoint = deviceId;
    } else {
      for (final s in mdns) {
        if (!s.isConnect) continue;
        if (deviceId == s.name ||
            deviceId == '${s.name}._adb-tls-connect._tcp' ||
            deviceId.startsWith('${s.name}.')) {
          host = s.host;
          endpoint = s.endpoint;
          break;
        }
      }
    }

    if (endpoint != null) {
      targets.add(endpoint);
      for (final s in mdns) {
        if (!s.isConnect) continue;
        if (s.endpoint != endpoint) continue;
        targets.add(s.name);
        targets.add('${s.name}._adb-tls-connect._tcp');
        targets.add(s.endpoint);
      }
    }

    if (host != null) {
      for (final serial in connected) {
        if (serial.startsWith('$host:')) {
          targets.add(serial);
        }
      }
      for (final s in mdns) {
        if (s.isConnect && s.host == host) {
          targets.add(s.name);
          targets.add('${s.name}._adb-tls-connect._tcp');
          targets.add(s.endpoint);
        }
      }
    }

    // 只断开当前确实连着的序列号（外加用户点的那条）
    final result = <String>{deviceId};
    for (final serial in connected) {
      if (targets.contains(serial)) {
        result.add(serial);
        continue;
      }
      for (final t in targets) {
        if (serial == t || serial.startsWith('$t.')) {
          result.add(serial);
        }
      }
    }
    return result;
  }

  /// 原始 adb devices 序列号（不做 UI 去重）
  Future<List<String>> _listRawConnectedSerials() async {
    try {
      var result = await _execAdb(['devices']);
      if (result == null || result.exitCode != 0) return [];
      final serials = <String>[];
      for (var line in result.stdout.toString().split('\n')) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('List of')) continue;
        if (!line.contains('device')) continue;
        var parts = line.split('\t');
        if (parts.length < 2) parts = line.split(' ');
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          serials.add(parts[0]);
        }
      }
      return serials;
    } catch (e) {
      debugPrint('获取原始设备序列号失败: $e');
      return [];
    }
  }

  /// 获取本机局域网 IP 地址
  static Future<String> getLocalIp() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('获取本机IP失败: $e');
    }
    return '未知';
  }

  /// 一次 shell 同时取品牌和型号，减少无线设备上的往返耗时
  Future<(String, String)> _getBrandAndModel(String device) async {
    try {
      var result = await _execAdb([
        '-s',
        device,
        'shell',
        'getprop ro.product.brand; getprop ro.product.model',
      ]);
      if (result != null && result.exitCode == 0) {
        final lines = result.stdout
            .toString()
            .split(RegExp(r'[\r\n]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final brand = lines.isNotEmpty ? lines[0] : device;
        final model = lines.length > 1 ? lines[1] : device;
        return (brand, model);
      }
      return (device, device);
    } catch (e) {
      return (device, device);
    }
  }

  /// 安装 APK 到指定设备
  Future<bool> installApk(String apkPath) async {
    if (apkPath.isEmpty) return false;

    try {
      ProcessResult? result;
      try {
        result = await _execAdb([
          '-s',
          currentDeviceId,
          'install',
          '-t', // 重新安装
          apkPath
        ]);
      } catch (e) {
        // 如果 _execAdb 抛出异常，尝试从异常中提取信息
        debugPrint('执行 ADB 安装命令异常: $e');
        String errorMsg = e.toString();
        // 尝试从异常信息中提取 ADB 错误信息
        if (errorMsg.contains('adb:')) {
          // 提取 adb: 后面的错误信息
          int adbIndex = errorMsg.indexOf('adb:');
          String adbError = errorMsg.substring(adbIndex);
          // 提取第一行关键错误
          List<String> lines = adbError.split('\n');
          if (lines.isNotEmpty) {
            String firstLine = lines[0].trim();
            if (firstLine.startsWith('adb:')) {
              SmartDialogUtils.showError('安装 APK 失败: ${firstLine.substring(4).trim()}');
              return false;
            }
          }
        }
        SmartDialogUtils.showError('安装 APK 失败: $errorMsg');
        return false;
      }
      
      if (result == null) {
        // result 为 null 表示命令执行异常，但无法获取详细错误信息
        SmartDialogUtils.showError('安装 APK 失败: 无法执行 ADB 命令，请检查 ADB 连接和设备状态');
        return false;
      }
      
      if (result.exitCode != 0) {
        // 获取错误信息，优先使用 stderr，其次使用 stdout
        String errorMessage = result.stderr.toString().trim();
        if (errorMessage.isEmpty) {
          errorMessage = result.stdout.toString().trim();
        }
        if (errorMessage.isEmpty) {
          errorMessage = '安装失败，退出码: ${result.exitCode}';
        }
        // 使用错误 toast 显示原始错误信息
        SmartDialogUtils.showError('安装 APK 失败: $errorMessage');
        return false;
      }
      
      return true;
    } catch (e) {
      String errorMsg = e.toString();
      debugPrint('安装 APK 失败: $errorMsg');
      // 使用错误 toast 显示原始错误信息
      SmartDialogUtils.showError('安装 APK 失败: $errorMsg');
      return false;
    }
  }

  /// 卸载应用
  Future<bool> uninstallApp(String packageName) async {
    if (packageName.isEmpty) return false;

    try {
      var result = await _execAdb(['-s', currentDeviceId, 'uninstall', packageName]);

      return result != null && result.exitCode == 0;
    } catch (e) {
      debugPrint('卸载应用失败: $e');
      return false;
    }
  }

  /// 获取已安装应用列表
  Future<List<ListFilterItem>> getInstalledApp() async {
    
    try {
      var isShowSysApp = await App().getIsShowSystemApp();
      var installedApp = await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        'pm',
        'list',
        'packages',
        isShowSysApp ? '' : '-3',
      ]);
      
      if (installedApp == null) {
        return [];
      }
      
      var outLines = installedApp.outLines;
      var packageList = outLines
          .where((e) => e.startsWith('package:'))
          .map((e) => ListFilterItem(e.substring('package:'.length).trim()))
          .where((item) => item.itemTitle.isNotEmpty)
          .toList();
      
      packageList.sort((a, b) => a.itemTitle.compareTo(b.itemTitle));
      
      if (packageList.isNotEmpty) {
        selectedPackage = selectedPackage.isNotEmpty
            ? packageList
                .firstWhere(
                  (element) => element.itemTitle == selectedPackage,
                  orElse: () => packageList.first,
                )
                .itemTitle
            : packageList.first.itemTitle;
        
        return packageList;
      }

    } catch (e) {
      debugPrint('获取已安装应用失败: $e');
    }
    return [];
  }

  /// 输入文本到当前设备
  /// Android `input` 命令把 %s 当作空格转义符，所以把空格替换成 %s
  /// 否则空格会让 `input text` 把字符串分裂成多个参数导致丢字符
  Future<bool> inputText(String text) async {
    if (text.isEmpty) return false;
    try {
      final encoded = text.replaceAll(' ', '%s');
      var result = await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        'input',
        'text',
        encoded,
      ]);
      return result != null && result.exitCode == 0;
    } catch (e) {
      debugPrint('输入文本失败: $e');
      return false;
    }
  }

  /// 截图保存到电脑
  Future<bool> screenshot() async {
    try {
      String? savePath;
      
      // 优先使用设置的保存路径，如果没有设置则让用户选择
      final app = App();
      final setSavePath = await app.getSaveFilePath();
      if (setSavePath.isNotEmpty) {
        savePath = setSavePath;
      } else {
        // 如果没有设置保存路径，让用户选择
        savePath = await getDirectoryPath();
      }
      
      if (savePath == null || savePath.isEmpty) {
        debugPrint('无法获取截图保存路径');
        return false;
      }

      // 在设备上执行截图命令
      var screencapResult = await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        'screencap',
        '-p',
        '/sdcard/screenshot.png',
      ]);

      if (screencapResult == null || screencapResult.exitCode != 0) {
        debugPrint('设备截图失败');
        return false;
      }

      // 生成本地文件名
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String localPath = '$savePath/screenshot_$timestamp.png';

      // 从设备拉取截图文件
      var pullResult = await _execAdb([
        '-s',
        currentDeviceId,
        'pull',
        '/sdcard/screenshot.png',
        localPath,
      ]);

      // 清理设备上的临时文件
      await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        'rm',
        '-rf',
        '/sdcard/screenshot.png',
      ]);

      if (pullResult != null && pullResult.exitCode == 0) {
        // 添加水印
        await _addWatermark(localPath);
        debugPrint('截图保存成功: $localPath');
        return true;
      } else {
        debugPrint('拉取截图文件失败');
        return false;
      }
    } catch (e) {
      debugPrint('截图操作失败: $e');
      return false;
    }
  }

  /// 为截图添加水印
  Future<void> _addWatermark(String imagePath) async {
    try {
      // 读取图片文件
      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        debugPrint('无法解码图片');
        return;
      }

      // 水印文字
      const watermarkText = 'screenshot by AdbPlayer';
      
      // 使用 arial48 字体（高度约48像素）
      final font = img.arial48;
      
      // 距离右边和底部的边距
      const margin = 20;
      
      // 计算文字位置（右下角）
      // arial48 字体，估算每个字符宽度约26像素
      const textWidth = watermarkText.length * 26;
      final textX = image.width - textWidth - margin;
      final textY = image.height - 48 - margin; // 48是字体高度
      
      // 先绘制黑色阴影（偏移2像素）增加可读性
      img.drawString(
        image,
        watermarkText,
        font: font,
        x: textX + 2,
        y: textY + 2,
        color: img.ColorRgba8(0, 0, 0, 200), // 黑色阴影
      );
      
      // 绘制白色文字
      img.drawString(
        image,
        watermarkText,
        font: font,
        x: textX,
        y: textY,
        color: img.ColorRgba8(255, 255, 255, 255), // 白色
      );
      
      // 保存图片
      final modifiedBytes = img.encodePng(image);
      await imageFile.writeAsBytes(modifiedBytes);
      
      debugPrint('水印添加成功');
    } catch (e) {
      debugPrint('添加水印失败: $e');
      // 即使添加水印失败，也不影响截图功能
    }
  }

  // 录屏相关
  Shell? _recordingShell;
  bool _isRecording = false;
  /// 录屏并保存到电脑
  Future<bool> recordScreen() async {
    if (_isRecording) return false;

    try {
      _recordingShell = Shell(
        environment: _adbEnvironment,
        includeParentEnvironment: false,
      );
      _isRecording = true;
      
      // 异步启动录屏命令，不等待结果
      _recordingShell!.runExecutableArguments(adbPath, [
        '-s',
        currentDeviceId,
        'shell',
        'screenrecord',
        '/sdcard/screenrecord.mp4',
      ]).then((_) {
        // 命令正常结束（通常是被停止）
        debugPrint('录屏命令结束');
        _isRecording = false;
      }).catchError((e) {
        // 命令执行异常
        debugPrint('录屏命令执行异常: $e');
        _isRecording = false;
      });

      // 给命令一点启动时间，然后检查是否还在运行
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_isRecording) {
        debugPrint('录屏开始');
        return true;
      } else {
        debugPrint('录屏启动失败');
        return false;
      }
    } catch (e) {
      debugPrint('开始录屏失败: $e');
      _isRecording = false;
      return false;
    }
  }

  /// 停止录屏并保存
  Future<bool> stopRecordAndSave() async {
    if (!_isRecording) return false;

    try {
      // 停止录屏进程
      if (_recordingShell != null) {
        _recordingShell!.kill();
        _recordingShell = null;
      }
      _isRecording = false;

      // 等待一下确保文件写入完成
      await Future.delayed(const Duration(seconds: 1));

      String? savePath;
      
      // 优先使用设置的保存路径，如果没有设置则让用户选择
      final app = App();
      final setSavePath = await app.getSaveFilePath();
      if (setSavePath.isNotEmpty) {
        savePath = setSavePath;
      } else {
        // 如果没有设置保存路径，让用户选择
        savePath = await getDirectoryPath();
      }
      
      if (savePath == null || savePath.isEmpty) {
        debugPrint('无法获取录屏保存路径');
        return false;
      }

      // 生成本地文件名
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String localPath = '$savePath/screenrecord_$timestamp.mp4';

      // 从设备拉取录屏文件
      var pullResult = await _execAdb([
        '-s',
        currentDeviceId,
        'pull',
        '/sdcard/screenrecord.mp4',
        localPath,
      ]);

      // 清理设备上的临时文件
      await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        'rm',
        '/sdcard/screenrecord.mp4',
      ]);

      if (pullResult != null && pullResult.exitCode == 0) {
        debugPrint('录屏保存成功: $localPath');
        return true;
      } else {
        debugPrint('拉取录屏文件失败');
        return false;
      }
    } catch (e) {
      debugPrint('停止录屏失败: $e');
      _isRecording = false;
      return false;
    }
  }

  Shell? _monkeyShell;
  bool _isMonkeyRunning = false;
  bool _monkeyStoppedManually = false;
  bool _monkeyHasError = false;
  String _monkeyPackage = '';
  int _monkeyEventCount = 0;
  DateTime? _monkeyStartedAt;
  String _monkeyLogPath = '';
  IOSink? _monkeyLogSink;
  MonkeyResult? _lastMonkeyResult;

  bool get isMonkeyRunning => _isMonkeyRunning;
  MonkeyResult? get lastMonkeyResult => _lastMonkeyResult;

  /// 启动 Monkey 测试
  /// [eventCount] 事件总数；[throttleMs] 事件之间间隔毫秒数
  /// 返回 true 表示进程已成功启动；stdout/stderr 会写入临时日志文件，结束后可在
  /// [lastMonkeyResult] 获取统计结论。
  Future<bool> startMonkeyTest({
    required int eventCount,
    int throttleMs = 300,
  }) async {
    if (_isMonkeyRunning) return false;
    if (selectedPackage.isEmpty) return false;

    try {
      // 准备临时日志文件，捕获 monkey 输出（含 // CRASH: 等标记）
      final dir = await getTemporaryDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final ts = DateTime.now().millisecondsSinceEpoch;
      _monkeyLogPath =
          '${dir.path}${Platform.pathSeparator}monkey_${selectedPackage}_$ts.log';
      _monkeyLogSink = File(_monkeyLogPath).openWrite();

      _monkeyShell = Shell(
        stdout: _monkeyLogSink,
        stderr: _monkeyLogSink,
        environment: _adbEnvironment,
        includeParentEnvironment: false,
      );
      _isMonkeyRunning = true;
      _monkeyStoppedManually = false;
      _monkeyHasError = false;
      _monkeyPackage = selectedPackage;
      _monkeyEventCount = eventCount;
      _monkeyStartedAt = DateTime.now();
      _lastMonkeyResult = null;

      _monkeyShell!.runExecutableArguments(adbPath, [
        '-s',
        currentDeviceId,
        'shell',
        'monkey',
        '-p',
        selectedPackage,
        '--throttle',
        throttleMs.toString(),
        '--ignore-crashes',
        '--ignore-timeouts',
        '-v',
        eventCount.toString(),
      ]).then((_) {
        debugPrint('Monkey 测试自然结束');
      }).catchError((e) {
        // kill() 也会走这里，靠 _monkeyStoppedManually 区分
        debugPrint('Monkey 命令结束/异常: $e');
        if (!_monkeyStoppedManually) _monkeyHasError = true;
      }).whenComplete(() async {
        await _finalizeMonkey();
      });

      // 等命令初始化一下，确认未立即失败
      await Future.delayed(const Duration(milliseconds: 500));
      return _isMonkeyRunning;
    } catch (e) {
      debugPrint('启动 Monkey 失败: $e');
      _isMonkeyRunning = false;
      try {
        await _monkeyLogSink?.close();
      } catch (_) {}
      _monkeyLogSink = null;
      return false;
    }
  }

  /// 收尾：关闭日志文件、解析输出、构造 MonkeyResult
  Future<void> _finalizeMonkey() async {
    try {
      await _monkeyLogSink?.close();
    } catch (_) {}
    _monkeyLogSink = null;

    final elapsed = _monkeyStartedAt != null
        ? DateTime.now().difference(_monkeyStartedAt!)
        : Duration.zero;

    String output = '';
    try {
      final f = File(_monkeyLogPath);
      if (await f.exists()) {
        output = await f.readAsString();
      }
    } catch (_) {}

    final crashCount = RegExp(r'// CRASH:').allMatches(output).length;
    final anrCount = RegExp(r'// NOT RESPONDING:').allMatches(output).length;

    final status = _monkeyHasError
        ? MonkeyStatus.error
        : _monkeyStoppedManually
            ? MonkeyStatus.stopped
            : MonkeyStatus.completed;

    _lastMonkeyResult = MonkeyResult(
      packageName: _monkeyPackage,
      totalEvents: _monkeyEventCount,
      elapsed: elapsed,
      status: status,
      crashCount: crashCount,
      anrCount: anrCount,
      logPath: _monkeyLogPath,
    );

    _isMonkeyRunning = false;
    _monkeyShell = null;
  }

  /// 停止 Monkey 测试
  /// 先 kill 本地 Shell（关掉 adb 通道），再在设备上 pkill 兜底（避免 monkey 脱离父进程继续跑）
  Future<void> stopMonkeyTest() async {
    if (!_isMonkeyRunning && _monkeyShell == null) return;
    _monkeyStoppedManually = true;
    try {
      _monkeyShell?.kill();
    } catch (_) {}

    try {
      await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        'pkill',
        '-l',
        '9',
        'com.android.commands.monkey',
      ]);
    } catch (e) {
      debugPrint('设备端 pkill monkey 失败: $e');
    }
  }

  /// 把一次 Monkey 测试产物（stdout 日志 + 设备 crash buffer）保存到目录
  /// 成功返回真实保存目录，失败返回空字符串
  Future<String> saveMonkeyArtifacts(
    MonkeyResult result,
    String savePath,
  ) async {
    if (savePath.isEmpty) return '';
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final dirName = 'monkey_${result.packageName}_$ts';
      final outDir = Directory('$savePath${Platform.pathSeparator}$dirName');
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      // 1) Monkey stdout
      if (result.logPath.isNotEmpty) {
        final src = File(result.logPath);
        if (await src.exists()) {
          await src.copy(
            '${outDir.path}${Platform.pathSeparator}monkey_stdout.log',
          );
        }
      }

      // 2) 设备 crash buffer
      final crashLog = await _execAdb([
        '-s',
        currentDeviceId,
        'logcat',
        '-d',
        '-b',
        'crash',
      ]);
      if (crashLog != null && crashLog.exitCode == 0) {
        await File('${outDir.path}${Platform.pathSeparator}logcat_crash.log')
            .writeAsString(crashLog.stdout.toString());
      }

      // 3) 主 buffer 最近输出（按包名过滤需要 pid，简单起见先全量 dump）
      final mainLog = await _execAdb([
        '-s',
        currentDeviceId,
        'logcat',
        '-d',
      ]);
      if (mainLog != null && mainLog.exitCode == 0) {
        await File('${outDir.path}${Platform.pathSeparator}logcat_main.log')
            .writeAsString(mainLog.stdout.toString());
      }

      return outDir.path;
    } catch (e) {
      debugPrint('保存 Monkey 日志失败: $e');
      return '';
    }
  }

  /// 获取前台Activity
  Future<String?> getForegroundActivity() async {
    try {
      var result = await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        'dumpsys',
        'activity',
        '|',
        'grep',
        'ResumedActivity',
      ]);

      if (result != null && result.exitCode == 0) {
        var stdout = result.stdout.toString().trim();

        if (stdout.isNotEmpty) {
          var lines = stdout.split('\n');
          for (var line in lines) {
            line = line.trim();
            // 处理 ResumedActivity 格式
            // 示例: topResumedActivity=ActivityRecord{6c44f05 u0 com.tencent.mm/.ui.LauncherUI t2353 d0}
            // 示例: ResumedActivity: ActivityRecord{6c44f05 u0 com.tencent.mm/.ui.LauncherUI t2353 d0}
            if (line.contains('ResumedActivity') && line.contains('u0 ')) {
              // 使用正则表达式提取包名/Activity名
              // 匹配格式: u0 包名/Activity名 (后面可能有空格和其他内容)
              var match = RegExp(r'u0\s+([^\s]+/[^\s]+)').firstMatch(line);
              if (match != null) {
                var activity = match.group(1)!;
                return activity;
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('获取前台Activity失败: $e');
      return null;
    }
  }

  /// 推送文件到设备
  Future<bool> pushFile(
      String localPath, String remotePath) async {
    if (localPath.isEmpty || remotePath.isEmpty) {
      return false;
    }

    try {
      var result =
          await _execAdb(['-s', currentDeviceId, 'push', localPath, remotePath]);

      return result != null && result.exitCode == 0;
    } catch (e) {
      debugPrint('推送文件失败: $e');
      return false;
    }
  }

  /// 从设备拉取文件
  Future<bool> pullFile(
      String remotePath, String localPath) async {
    if (remotePath.isEmpty || localPath.isEmpty) {
      return false;
    }

    try {
      var result =
          await _execAdb(['-s', currentDeviceId, 'pull', remotePath, localPath]);

      return result != null && result.exitCode == 0;
    } catch (e) {
      debugPrint('拉取文件失败: $e');
      return false;
    }
  }

  /// 测试ADB
  Future<bool> testAdb() async {
    try {
      var result = await _execAdb(['version']);
      return result != null && result.exitCode == 0;
    } catch (e) {
      debugPrint('测试ADB失败: $e');
      return false;
    }
  }

  /// 启动应用
  Future<bool> startApp() async {
    var launchActivity = await _getLaunchActivity();
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'am',
      'start',
      '-n',
      launchActivity,
    ]);
    return result != null && result.exitCode == 0;
  }

  /// 获取启动Activity
  Future<String> _getLaunchActivity() async {
    var launchActivity = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'dumpsys',
      'package',
      selectedPackage,
      '|',
      'grep',
      '-A',
      '1',
      'MAIN',
    ]);
    if (launchActivity == null) return "";
    var outLines = launchActivity.outLines;
    if (outLines.isEmpty) {
      return "";
    } else {
      for (var value in outLines) {
        if (value.contains("$selectedPackage/")) {
          return value.substring(
              value.indexOf("$selectedPackage/"), value.indexOf(" filter"));
        }
      }
      return "";
    }
  }

  /// 停止运行应用
  Future<bool> stopApp() async {
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'am',
      'force-stop',
      selectedPackage,
    ]);
    return result != null && result.exitCode == 0;
  }

  /// 清除数据
  Future<bool> clearAppData() async {
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'pm',
      'clear',
      selectedPackage,
    ]);
    return result != null && result.exitCode == 0;
  }

  /// 重置应用权限
  Future<void> resetAppPermission() async {
    var permissionList = await getAppPermissionList();
    for (var value in permissionList) {
      await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        'pm',
        'revoke',
        selectedPackage,
        value,
      ]);
    }
  }

  /// 获取应用权限列表
  Future<List<String>> getAppPermissionList() async {
    var permission = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'dumpsys',
      'package',
      selectedPackage,
    ]);
    if (permission == null) return [];
    var outLines = permission.outLines;
    List<String> permissionList = [];
    for (var value in outLines) {
      if (value.contains("permission.")) {
        var permissionLine = value.replaceAll(" ", "").split(":");
        if (permissionLine.isEmpty) {
          continue;
        }
        var permission = permissionLine[0];
        permissionList.add(permission);
      }
    }
    return permissionList;
  }

  /// 授予应用权限
  Future<void> grantAppPermission() async {
    var permissionList = await getAppPermissionList();
    for (var value in permissionList) {
      await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        'pm',
        'grant',
        selectedPackage,
        value,
      ]);
    }
  }

  /// 获取应用安装路径
  Future<String> getAppInstallPath() async {
    var installPath = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'pm',
      'path',
      selectedPackage,
    ]);
    if (installPath == null || installPath.outLines.isEmpty) {
      return "";
    } else {
      var path = installPath.outLines.first.replaceAll("package:", "");
      return path;
    }
  }

  /// 获取应用完整信息：版本号、SDK 版本与请求的权限列表
  /// 通过 `adb shell dumpsys package <pkg>` 解析
  Future<AppInfo?> getAppInfo() async {
    if (selectedPackage.isEmpty) return null;
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'dumpsys',
      'package',
      selectedPackage,
    ]);
    if (result == null || result.exitCode != 0) {
      return null;
    }

    String versionName = '';
    String versionCode = '';
    String minSdk = '';
    String targetSdk = '';
    String compileSdk = '';
    final List<String> requested = [];
    final Map<String, bool> grantedMap = {};

    // dumpsys 输出有多个段：requested permissions / install permissions / runtime permissions
    // 通过缩进/段标题判断当前段，避免同一权限被多次收录
    String section = '';
    for (var raw in result.outLines) {
      final line = raw.trimRight();
      final trimmed = line.trim();

      // 解析 SDK / 版本字段
      if (versionName.isEmpty && trimmed.startsWith('versionName=')) {
        versionName = trimmed.substring('versionName='.length).trim();
      }
      // 一行可能同时包含 versionCode/minSdk/targetSdk
      void readKv(String key, void Function(String) setter) {
        final idx = trimmed.indexOf('$key=');
        if (idx < 0) return;
        final start = idx + key.length + 1;
        final rest = trimmed.substring(start);
        final spaceIdx = rest.indexOf(' ');
        setter((spaceIdx >= 0 ? rest.substring(0, spaceIdx) : rest).trim());
      }
      if (versionCode.isEmpty) readKv('versionCode', (v) => versionCode = v);
      if (minSdk.isEmpty) readKv('minSdk', (v) => minSdk = v);
      if (targetSdk.isEmpty) readKv('targetSdk', (v) => targetSdk = v);
      if (compileSdk.isEmpty) readKv('compileSdk', (v) => compileSdk = v);

      // 段切换
      if (trimmed.endsWith('permissions:')) {
        if (trimmed.startsWith('requested permissions')) {
          section = 'requested';
        } else if (trimmed.startsWith('install permissions')) {
          section = 'install';
        } else if (trimmed.startsWith('runtime permissions')) {
          section = 'runtime';
        } else {
          section = '';
        }
        continue;
      }

      if (section.isEmpty) continue;

      // 段内容必须以缩进开头；遇到无缩进非空行说明段结束
      if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
        section = '';
        continue;
      }
      if (!trimmed.contains('permission.') && !trimmed.contains('.permission.')) {
        continue;
      }

      // 行示例：
      //   android.permission.INTERNET
      //   android.permission.INTERNET: granted=true
      final colonIdx = trimmed.indexOf(':');
      final name =
          (colonIdx >= 0 ? trimmed.substring(0, colonIdx) : trimmed).trim();
      if (name.isEmpty) continue;

      if (section == 'requested') {
        if (!requested.contains(name)) requested.add(name);
      } else {
        // install / runtime 段携带 granted=true|false
        final granted = trimmed.contains('granted=true');
        // 任意一段为 true 即视为已授予
        grantedMap[name] = (grantedMap[name] ?? false) || granted;
        if (!requested.contains(name)) requested.add(name);
      }
    }

    final permissions = requested
        .map((p) => AppPermission(name: p, granted: grantedMap[p] ?? false))
        .toList();

    if (versionName.isEmpty &&
        versionCode.isEmpty &&
        minSdk.isEmpty &&
        targetSdk.isEmpty &&
        compileSdk.isEmpty &&
        permissions.isEmpty) {
      return null;
    }

    return AppInfo(
      versionName: versionName,
      versionCode: versionCode,
      minSdk: minSdk,
      targetSdk: targetSdk,
      compileSdk: compileSdk,
      permissions: permissions,
    );
  }

  /// 获取应用 base.apk 路径（split APK 时也能拿到主包）
  Future<String> _getBaseApkPath() async {
    var installPath = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'pm',
      'path',
      selectedPackage,
    ]);
    if (installPath == null || installPath.outLines.isEmpty) {
      return "";
    }
    var paths = installPath.outLines
        .map((e) => e.replaceAll("package:", "").trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (paths.isEmpty) return "";
    final base = paths.firstWhere(
      (e) => e.endsWith("/base.apk"),
      orElse: () => paths.first,
    );
    return base;
  }

  /// 获取应用签名信息
  /// 流程：取 base.apk 路径 → pull 到本地临时目录 → keytool 解析 → 删除临时文件
  /// 依赖：本机已安装 JDK 且 keytool 在 PATH 中
  Future<AppSignatureInfo?> getAppSignature() async {
    if (selectedPackage.isEmpty) return null;
    File? tempApk;
    try {
      final remotePath = await _getBaseApkPath();
      if (remotePath.isEmpty) {
        debugPrint('获取 APK 路径失败');
        return null;
      }

      final dir = await getTemporaryDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final localPath = '${dir.path}${Platform.pathSeparator}'
          '${selectedPackage}_${DateTime.now().millisecondsSinceEpoch}.apk';

      final pullResult = await _execAdb([
        '-s',
        currentDeviceId,
        'pull',
        remotePath,
        localPath,
      ]);
      if (pullResult == null || pullResult.exitCode != 0) {
        debugPrint('拉取 APK 失败: ${pullResult?.stderr}');
        return null;
      }
      tempApk = File(localPath);
      if (!await tempApk.exists()) {
        debugPrint('本地 APK 不存在');
        return null;
      }

      // 优先使用 apksigner（支持 v1/v2/v3 签名方案），失败再回退 keytool（仅 v1）
      final apksignerInfo = await _runApksigner(localPath);
      if (apksignerInfo != null) {
        return apksignerInfo;
      }

      final result = await _exec('keytool', [
        '-printcert',
        '-jarfile',
        localPath,
      ]);
      if (result == null || result.exitCode != 0) {
        debugPrint('keytool 执行失败: ${result?.stderr}');
        return null;
      }

      return _parseKeytoolOutput(result.stdout.toString());
    } catch (e) {
      debugPrint('获取签名信息失败: $e');
      return null;
    } finally {
      try {
        await tempApk?.delete();
      } catch (_) {}
    }
  }

  /// 查找 apksigner 可执行文件路径
  /// 1) PATH 中查找
  /// 2) 从 adbPath 推导（platform-tools 同级的 build-tools/<version>/apksigner）
  Future<String?> _findApksigner() async {
    final isWindows = Platform.isWindows;
    final exeName = isWindows ? 'apksigner.bat' : 'apksigner';

    // 1) PATH
    final whichExe = isWindows ? 'where' : 'which';
    final whichResult = await _exec(whichExe, [exeName]);
    if (whichResult != null && whichResult.exitCode == 0) {
      final stdout = whichResult.stdout.toString().trim();
      if (stdout.isNotEmpty) {
        return stdout.split(RegExp(r'[\r\n]+')).first.trim();
      }
    }

    // 2) 从 adbPath 推导 SDK 根目录
    if (adbPath.isEmpty) return null;
    final adbFile = File(adbPath);
    final platformToolsDir = adbFile.parent;
    final sdkRoot = platformToolsDir.parent;
    final buildToolsDir =
        Directory('${sdkRoot.path}${Platform.pathSeparator}build-tools');
    if (!await buildToolsDir.exists()) return null;

    final versionDirs = await buildToolsDir
        .list()
        .where((e) => e is Directory)
        .cast<Directory>()
        .toList();
    if (versionDirs.isEmpty) return null;
    // 取最新版本（按目录名字典序倒序，对 30.0.3 这种版本号有效）
    versionDirs.sort((a, b) =>
        b.path.split(Platform.pathSeparator).last.compareTo(
            a.path.split(Platform.pathSeparator).last));
    for (final d in versionDirs) {
      final candidate = '${d.path}${Platform.pathSeparator}$exeName';
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    return null;
  }

  /// 调用 apksigner verify --print-certs 解析签名（支持 v1/v2/v3）
  Future<AppSignatureInfo?> _runApksigner(String apkPath) async {
    final apksigner = await _findApksigner();
    if (apksigner == null) {
      debugPrint('未找到 apksigner');
      return null;
    }
    final result =
        await _exec(apksigner, ['verify', '--print-certs', apkPath]);
    if (result == null) return null;
    final stdout = result.stdout.toString();
    // apksigner 在签名方案不全时退出码可能非 0，但输出仍然包含证书信息
    if (stdout.isEmpty) {
      debugPrint('apksigner 无输出: ${result.stderr}');
      return null;
    }
    final info = _parseApksignerOutput(stdout);
    // 只要有任意一个指纹就认为成功
    if (info.md5.isEmpty && info.sha1.isEmpty && info.sha256.isEmpty) {
      return null;
    }
    return info;
  }

  /// 解析 apksigner verify --print-certs 输出
  /// 示例：
  ///   Signer #1 certificate DN: CN=xxx, O=xxx
  ///   Signer #1 certificate SHA-256 digest: aabbcc...
  ///   Signer #1 certificate SHA-1 digest: aabbcc...
  ///   Signer #1 certificate MD5 digest: aabbcc...
  AppSignatureInfo _parseApksignerOutput(String output) {
    String md5 = '';
    String sha1 = '';
    String sha256 = '';
    String subject = '';

    final lines = output.split(RegExp(r'[\r\n]+'));
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      // 只取第一个 Signer 的证书
      if (!line.startsWith('Signer #1 ')) continue;

      if (subject.isEmpty && line.contains('certificate DN:')) {
        final idx = line.indexOf('certificate DN:');
        subject = line.substring(idx + 'certificate DN:'.length).trim();
      } else if (sha256.isEmpty && line.contains('SHA-256 digest:')) {
        final idx = line.indexOf('SHA-256 digest:');
        sha256 = _formatHex(
            line.substring(idx + 'SHA-256 digest:'.length).trim());
      } else if (sha1.isEmpty && line.contains('SHA-1 digest:')) {
        final idx = line.indexOf('SHA-1 digest:');
        sha1 = _formatHex(
            line.substring(idx + 'SHA-1 digest:'.length).trim());
      } else if (md5.isEmpty && line.contains('MD5 digest:')) {
        final idx = line.indexOf('MD5 digest:');
        md5 = _formatHex(
            line.substring(idx + 'MD5 digest:'.length).trim());
      }
    }

    return AppSignatureInfo(
      md5: md5,
      sha1: sha1,
      sha256: sha256,
      subject: subject,
    );
  }

  /// 把 apksigner 输出的连续 hex（如 aabbccdd）格式化为 AA:BB:CC:DD
  String _formatHex(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (clean.isEmpty) return '';
    final buf = StringBuffer();
    for (int i = 0; i < clean.length; i += 2) {
      if (i > 0) buf.write(':');
      buf.write(clean.substring(i, i + 2 > clean.length ? clean.length : i + 2));
    }
    return buf.toString();
  }

  /// 解析 keytool -printcert -jarfile 输出
  AppSignatureInfo _parseKeytoolOutput(String output) {
    String md5 = '';
    String sha1 = '';
    String sha256 = '';
    String subject = '';
    String issuer = '';
    String serial = '';
    String validFrom = '';
    String validTo = '';
    String algorithm = '';

    final lines = output.split(RegExp(r'[\r\n]+'));
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (md5.isEmpty && line.startsWith('MD5:')) {
        md5 = line.substring(4).trim();
      } else if (sha1.isEmpty &&
          (line.startsWith('SHA1:') || line.startsWith('SHA-1:'))) {
        sha1 = line.substring(line.indexOf(':') + 1).trim();
      } else if (sha256.isEmpty &&
          (line.startsWith('SHA256:') || line.startsWith('SHA-256:'))) {
        sha256 = line.substring(line.indexOf(':') + 1).trim();
      } else if (subject.isEmpty && line.startsWith('Owner:')) {
        subject = line.substring(6).trim();
      } else if (issuer.isEmpty && line.startsWith('Issuer:')) {
        issuer = line.substring(7).trim();
      } else if (serial.isEmpty && line.startsWith('Serial number:')) {
        serial = line.substring('Serial number:'.length).trim();
      } else if (line.startsWith('Valid from:')) {
        // Valid from: <date> until: <date>
        final body = line.substring('Valid from:'.length);
        final untilIdx = body.indexOf('until:');
        if (untilIdx >= 0) {
          validFrom = body.substring(0, untilIdx).trim();
          validTo = body.substring(untilIdx + 'until:'.length).trim();
        } else {
          validFrom = body.trim();
        }
      } else if (algorithm.isEmpty &&
          line.startsWith('Signature algorithm name:')) {
        algorithm = line.substring('Signature algorithm name:'.length).trim();
      }
    }

    return AppSignatureInfo(
      md5: md5,
      sha1: sha1,
      sha256: sha256,
      subject: subject,
      issuer: issuer,
      serialNumber: serial,
      validFrom: validFrom,
      validTo: validTo,
      algorithm: algorithm,
    );
  }


  ///查看设备AndroidId
  Future<String> getAndroidId() async {
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'settings',
      'get',
      'secure',
      'android_id',
    ]);

    var outLines = result?.outLines;
    if (outLines == null || outLines.isEmpty) {
      return "";
    } else {
      var androidId = outLines.first;
      return androidId;
    }
  }


  ///  查看设备系统版本
  Future<String> getDeviceVersion() async {
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'getprop',
      'ro.build.version.release'
    ]);
    return result != null && result.exitCode == 0
        ? "Android " + result.stdout
        : '';
    
  }


  /// 查看设备IP地址
  Future<String> getDeviceIpAddress() async {
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'ifconfig',
      '|',
      'grep',
      'Mask',
    ]);
    var outLines = result?.outLines;
    if (outLines == null || outLines.isEmpty) {
      return "";
    } else {
      var ip = "";
      for (var value in outLines) {
        value = value.substring(value.indexOf("addr:"), value.length);
        ip += value.substring(0, value.indexOf(" ")) + "\n";
        debugPrint(value);
      }
      return ip;
    }
  }

  /// 获取设备MAC地址
  Future<String> getDeviceMac() async {
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      "ip addr show wlan0 | grep 'link/ether '| cut -d' ' -f6",
    ]);
    return result != null && result.exitCode == 0 ? result.stdout : "";
  }


  /// 打开手机的 WiFi 设置页面（用于手动配置 WiFi 专属代理）
  Future<bool> openWifiSettings() async {
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'am',
      'start',
      '-a',
      'android.settings.WIFI_SETTINGS',
    ]);
    return result != null && result.exitCode == 0;
  }

  /// 重启手机
  Future<bool> reboot() async {
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'reboot',
    ]);
    return result != null && result.exitCode == 0;
  }

  /// 查看系统属性
  Future<List<String>> getSystemProperty() async {
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'getprop',
    ]);
    var outLines = result?.outLines;
    if (outLines == null || outLines.isEmpty) {
      return [];
    } else {
      var list = outLines.toList();
      list.sort((a, b) => a.compareTo(b));
      return list;
    }
  }

  /// Home键
  Future<void> pressHome() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'keyevent',
      '3',
    ]);
  }

  /// 返回键
  Future<void> pressBack() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'keyevent',
      '4',
    ]);
  }

  /// 菜单键
  Future<void> pressMenu() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'keyevent',
      '82',
    ]);
  }

  /// 增加音量
  Future<void> pressVolumeUp() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'keyevent',
      '24',
    ]);
  }

  /// 减少音量
  Future<void> pressVolumeDown() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'keyevent',
      '25',
    ]);
  }

  /// 静音
  Future<void> pressVolumeMute() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'keyevent',
      '164',
    ]);
  }

  /// 电源键
  Future<void> pressPower() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'keyevent',
      '26',
    ]);
  }

  /// 切换应用
  Future<void> pressSwitchApp() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'keyevent',
      '187',
    ]);
  }

  /// 屏幕点击
  Future<void> pressScreen(String input) async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'tap',
      input.replaceAll(",", " "),
    ]);
  }

  /// 向上滑动
  Future<void> pressSwipeUp() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'swipe',
      '300',
      '1300',
      '300',
      '300',
    ]);
  }

  /// 向下滑动
  Future<void> pressSwipeDown() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'swipe',
      '300',
      '300',
      '300',
      '1300',
    ]);
  }

  /// 向左滑动
  Future<void> pressSwipeLeft() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'swipe',
      '900',
      '300',
      '100',
      '300',
    ]);
  }

  /// 向右滑动
  Future<void> pressSwipeRight() async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'swipe',
      '100',
      '300',
      '900',
      '300',
    ]);
  }

  /// 遥控器按键事件
  Future<void> pressRemoteKey(KeyCode keyCode) async {
    await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      'input',
      'keyevent',
      keyCode.value.toString(),
    ]);
  }


  /// 删除文件
  Future<bool> deleteFile(String path) async {
    var result = await _execAdb([
      "-s",
      currentDeviceId,
      "shell",
      "rm",
      "-rf",
      path
    ]);
    return result != null && result.exitCode == 0;
  }

  /// 获取文件列表
  Future<ProcessResult?> getFileList(String path) async {
    var processResult = await _execAdb([
      "-s",
      currentDeviceId,
      "shell",
      "ls",
      "-lA",
      path
    ]);
    return processResult;
  }

  /// 检查包是否 debuggable（即能否走 run-as）
  Future<bool> isPackageDebuggable(String pkg) async {
    if (pkg.isEmpty) return false;
    var result = await _execAdb([
      "-s",
      currentDeviceId,
      "shell",
      "run-as",
      pkg,
      "echo",
      "ok",
    ]);
    if (result == null) return false;
    final stdout = result.stdout.toString().trim();
    return result.exitCode == 0 && stdout == 'ok';
  }

  /// 以 App 身份获取私有目录的文件列表（run-as）
  Future<ProcessResult?> getFileListAsApp(String pkg, String path) async {
    return await _execAdb([
      "-s",
      currentDeviceId,
      "shell",
      "run-as $pkg ls -lA $path 2>/dev/null",
    ]);
  }

  /// 以 App 身份删除私有目录里的文件/文件夹
  Future<bool> deleteFileAsApp(String pkg, String path) async {
    var result = await _execAdb([
      "-s",
      currentDeviceId,
      "shell",
      "run-as $pkg rm -rf $path",
    ]);
    return result != null && result.exitCode == 0;
  }

  /// 以 App 身份从私有目录拉文件到电脑
  /// 思路：在 shell 上下文执行 `run-as $pkg cat $remote > $sdcardTmp`，
  ///   - cat 走 run-as（app uid 能读私有目录）
  ///   - > 由外层 shell（shell uid）解释，写入 /sdcard
  ///   然后正常 adb pull 临时文件，最后清理
  /// 注：仅支持文件，不支持目录
  Future<bool> pullFileAsApp(
      String pkg, String remotePath, String localPath) async {
    if (remotePath.isEmpty || localPath.isEmpty) return false;
    final tmpName =
        'dp_pull_${DateTime.now().millisecondsSinceEpoch}_${remotePath.split('/').last}';
    final tmpPath = '/sdcard/$tmpName';
    try {
      // 1. run-as cat → /sdcard
      var copyResult = await _execAdb([
        "-s",
        currentDeviceId,
        "shell",
        "run-as $pkg cat $remotePath > $tmpPath",
      ]);
      if (copyResult == null || copyResult.exitCode != 0) {
        debugPrint('run-as cat 失败: ${copyResult?.stderr}');
        return false;
      }

      // 2. adb pull
      var pullResult = await _execAdb([
        "-s",
        currentDeviceId,
        "pull",
        tmpPath,
        localPath,
      ]);
      return pullResult != null && pullResult.exitCode == 0;
    } catch (e) {
      debugPrint('pullFileAsApp 异常: $e');
      return false;
    } finally {
      // 3. 清理临时文件，无论成功与否
      try {
        await _execAdb([
          "-s",
          currentDeviceId,
          "shell",
          "rm",
          "-f",
          tmpPath,
        ]);
      } catch (_) {}
    }
  }

  /// 保存日志到电脑
  Future<bool> saveLog(String savePath, {String? packageName}) async {
    try {
      if (packageName == null || packageName.isEmpty) {
        debugPrint("需要指定包名来获取应用日志");
        return false;
      }
      
      // 获取应用外部存储的files/log目录路径
      String logDirPath = "/storage/emulated/0/Android/data/$packageName/files/log";
      
      // 检查日志目录是否存在
      var checkResult = await _execAdb([
        "-s",
        currentDeviceId,
        "shell",
        "ls",
        logDirPath
      ]);
      
      if (checkResult == null || checkResult.exitCode != 0) {
        debugPrint("应用日志目录不存在: $logDirPath");
        return false;
      }
      
      // 检查日志目录下是否有文件
      var listResult = await _execAdb([
        "-s",
        currentDeviceId,
        "shell",
        "find",
        logDirPath,
        "-type",
        "f"
      ]);
      
      if (listResult == null || listResult.exitCode != 0 || listResult.stdout.trim().isEmpty) {
        debugPrint("日志目录中没有找到文件");
        return false;
      }
      
      // 解析文件列表
      List<String> files = listResult.stdout.trim().split('\n')
          .where((String line) => line.trim().isNotEmpty)
          .toList();
      
      if (files.isEmpty) {
        debugPrint("没有找到文件");
        return false;
      }
      
      debugPrint("找到 ${files.length} 个文件，开始拉取日志目录...");
      
      // 使用adb pull拉取整个日志目录
      var success = await pullFile(logDirPath,savePath);
      
      if (success) {
        debugPrint("日志目录拉取成功");
        return true;
      } else {
        return false;
      }
      
    } catch (e) {
      debugPrint("保存日志失败: $e");
      return false;
    }
  }

  /// 列出当前应用 shared_prefs 目录下的 xml 文件名
  /// 仅 debuggable 应用可通过 run-as 访问私有目录
  Future<List<String>> listSpFiles() async {
    if (selectedPackage.isEmpty) return [];
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      "run-as $selectedPackage ls /data/data/$selectedPackage/shared_prefs/ 2>/dev/null",
    ]);
    if (result == null || result.exitCode != 0) {
      debugPrint('列出 SP 文件失败: ${result?.stderr}');
      return [];
    }
    var lines = result.stdout.toString().trim().split(RegExp(r'[\r\n]+'));
    return lines
        .map((e) => e.trim())
        .where((e) => e.endsWith('.xml'))
        .toList();
  }

  /// 读取指定 SP 文件内容
  Future<String?> readSpFile(String filename) async {
    if (selectedPackage.isEmpty || filename.isEmpty) return null;
    var result = await _execAdb([
      '-s',
      currentDeviceId,
      'shell',
      "run-as $selectedPackage cat /data/data/$selectedPackage/shared_prefs/$filename",
    ]);
    if (result == null || result.exitCode != 0) {
      debugPrint('读取 SP 文件失败: ${result?.stderr}');
      return null;
    }
    return result.stdout.toString();
  }

  /// 写入指定 SP 文件内容
  /// 流程：force-stop 应用 → 推送临时文件到 /sdcard → run-as 覆盖目标文件
  /// force-stop 是为了避免应用进程在退出时把内存里的旧数据再写回，把我们的修改覆盖掉
  Future<bool> writeSpFile(String filename, String xmlContent) async {
    if (selectedPackage.isEmpty || filename.isEmpty) return false;
    File? tempFile;
    try {
      // 1. 先停止应用，避免 SP 内存缓存覆盖我们的写入
      await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        'am',
        'force-stop',
        selectedPackage,
      ]);

      // 2. 写本地临时文件
      var dir = await getTemporaryDirectory();
      tempFile = File('${dir.path}/sp_${DateTime.now().millisecondsSinceEpoch}_$filename');
      await tempFile.writeAsString(xmlContent);

      // 3. push 到设备公共目录
      var remoteTmp = '/sdcard/dp_sp_$filename';
      var pushResult = await _execAdb(
          ['-s', currentDeviceId, 'push', tempFile.path, remoteTmp]);
      if (pushResult == null || pushResult.exitCode != 0) {
        debugPrint('SP 文件 push 失败');
        return false;
      }

      // 4. 覆盖目标：在 run-as 外面读 /sdcard（用 shell uid，能读），
      //    通过管道把内容送给 run-as，run-as 里只负责写入私有目录。
      //    避免 app uid 没有外部存储权限导致的 Permission denied。
      var copyResult = await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        "cat $remoteTmp | run-as $selectedPackage sh -c 'cat > /data/data/$selectedPackage/shared_prefs/$filename'",
      ]);

      // 5. 清理 /sdcard 临时文件（无论成功与否）
      await _execAdb([
        '-s',
        currentDeviceId,
        'shell',
        'rm',
        '-f',
        remoteTmp,
      ]);

      if (copyResult == null || copyResult.exitCode != 0) {
        debugPrint('SP 文件覆盖失败: ${copyResult?.stderr}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('写入 SP 文件异常: $e');
      return false;
    } finally {
      try {
        await tempFile?.delete();
      } catch (_) {}
    }
  }

}
