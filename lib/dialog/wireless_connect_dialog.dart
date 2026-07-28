import 'dart:async';
import 'dart:math';

import 'package:adb_player/dialog/devices_model.dart';
import 'package:adb_player/services/adb_service.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 无线连接对话框 - 支持二维码配对与手动配对/连接
class WirelessConnectDialog extends StatefulWidget {
  const WirelessConnectDialog({Key? key}) : super(key: key);

  @override
  State<WirelessConnectDialog> createState() => _WirelessConnectDialogState();
}

class _WirelessConnectDialogState extends State<WirelessConnectDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// 手动连接：手机显示的整段地址，如 192.168.1.11:34545
  final _addressController = TextEditingController();
  /// 首次配对时填写；已配对过可留空
  final _pairCodeController = TextEditingController();

  String _localIp = '获取中...';
  String _statusMessage = '';
  bool _isLoading = false;
  bool _showFirstPair = false;
  List<AdbMdnsService> _discoveredConnect = [];

  // 二维码配对
  String _qrServiceName = '';
  String _qrPassword = '';
  String _qrContent = '';
  String _qrStatus = '等待手机扫码...';
  bool _qrBusy = false;
  bool _qrSuccess = false;
  bool _qrPollingInFlight = false;
  Timer? _qrPollTimer;
  bool _qrMdnsOk = true;
  /// 开始轮询后累计空发现次数，用于超时提示
  int _qrEmptyPolls = 0;

  static const _qrChars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadLocalIp();
    _pairCodeController.addListener(() => setState(() {}));
    _regenerateQr();
    _startQrPolling();
    _checkMdns();
    _refreshDiscoveredConnect();
  }

  Future<void> _refreshDiscoveredConnect() async {
    final list = await AdbService.instance.listMdnsServices();
    if (!mounted) return;
    final connects = list.where((s) => s.isConnect).toList();
    setState(() {
      _discoveredConnect = connects;
      // 已发现可连设备时，自动填入地址，免去手抄
      if (_addressController.text.trim().isEmpty && connects.isNotEmpty) {
        _addressController.text = connects.first.endpoint;
      }
    });
  }

  Future<void> _checkMdns() async {
    final ok = await AdbService.instance.isMdnsAvailable();
    if (!mounted) return;
    setState(() {
      _qrMdnsOk = ok;
      if (!ok) {
        _qrStatus = '当前 ADB 的 mDNS 不可用，请改用「手动连接」';
        _stopQrPolling();
      }
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      if (!_qrBusy && !_qrSuccess) _startQrPolling();
    } else {
      _stopQrPolling();
      _refreshDiscoveredConnect();
    }
  }

  Future<void> _loadLocalIp() async {
    var ip = await AdbService.getLocalIp();
    if (mounted) {
      setState(() => _localIp = ip);
    }
  }

  bool get _needPair => _pairCodeController.text.trim().isNotEmpty;

  /// 解析 `IP:端口`，返回 (host, port)；失败返回 null
  (String, String)? _parseAddress(String raw) {
    final text = raw.trim();
    final match = RegExp(r'^(\d{1,3}(?:\.\d{1,3}){3}):(\d{1,5})$').firstMatch(text);
    if (match == null) return null;
    final port = int.tryParse(match.group(2)!);
    if (port == null || port < 1 || port > 65535) return null;
    return (match.group(1)!, match.group(2)!);
  }

  void _regenerateQr() {
    final rng = Random.secure();
    final suffix = List.generate(
      10,
      (_) => _qrChars[rng.nextInt(_qrChars.length)],
    ).join();
    _qrServiceName = 'studio-$suffix';
    _qrPassword = List.generate(6, (_) => rng.nextInt(10)).join();
    _qrContent = 'WIFI:T:ADB;S:$_qrServiceName;P:$_qrPassword;;';
    _qrBusy = false;
    _qrSuccess = false;
    _qrEmptyPolls = 0;
    _qrStatus = _qrMdnsOk ? '等待手机扫码...' : '当前 ADB 的 mDNS 不可用，请改用「手动连接」';
  }

  void _refreshQr() {
    _stopQrPolling();
    setState(_regenerateQr);
    _startQrPolling();
  }

  void _startQrPolling() {
    _stopQrPolling();
    if (!_qrMdnsOk) return;
    _qrEmptyPolls = 0;
    _qrPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollQrPairing();
    });
  }

  void _stopQrPolling() {
    _qrPollTimer?.cancel();
    _qrPollTimer = null;
  }

  Future<void> _pollQrPairing() async {
    if (_qrBusy || _qrSuccess || _qrPollingInFlight || !mounted) return;
    if (_tabController.index != 0) return;

    _qrPollingInFlight = true;
    try {
      await _doQrPairingPoll();
    } finally {
      _qrPollingInFlight = false;
    }
  }

  Future<void> _doQrPairingPoll() async {
    final services = await AdbService.instance.listMdnsServices();
    if (!mounted || _qrBusy || _qrSuccess) return;

    AdbMdnsService? pairing;
    for (final s in services) {
      // 部分 mDNS 后端可能带后缀，做兼容匹配
      if (s.isPairing &&
          (s.name == _qrServiceName || s.name.startsWith('$_qrServiceName.'))) {
        pairing = s;
        break;
      }
    }
    if (pairing == null) {
      _qrEmptyPolls++;
      // 约 20s 仍无目标配对服务：给出可操作提示（避免一直停在「等待手机扫码」）
      if (_qrEmptyPolls == 20 || (_qrEmptyPolls > 20 && _qrEmptyPolls % 30 == 0)) {
        final pairingCount = services.where((s) => s.isPairing).length;
        final connectCount = services.where((s) => s.isConnect).length;
        debugPrint(
          'QR 配对仍在等待: 目标=$_qrServiceName, '
          'mdns pairing=$pairingCount connect=$connectCount, '
          '全部=${services.map((s) => '${s.name}/${s.type}@${s.endpoint}').join(', ')}',
        );
        if (!mounted || _qrBusy || _qrSuccess) return;
        setState(() {
          _qrStatus = pairingCount == 0 && connectCount == 0
              ? '未发现任何无线调试服务。请确认手机已打开「使用二维码配对」、与电脑同一 Wi‑Fi，并在「系统设置 → 隐私与安全性 → 本地网络」允许 AdbPlayer'
              : '已发现其他设备服务，但未匹配本二维码（$_qrServiceName）。请重新扫当前二维码，或点刷新生成新码';
        });
      }
      return;
    }
    _qrEmptyPolls = 0;

    final pairingHost = pairing.host;
    final pairingPort = pairing.port;

    _qrBusy = true;
    _stopQrPolling();
    setState(() => _qrStatus = '已发现设备，正在配对...');

    final pairResult = await AdbService.instance.pairDevice(
      pairingHost,
      pairingPort,
      _qrPassword,
    );
    if (!mounted) return;

    if (pairResult != '配对成功') {
      setState(() {
        _qrBusy = false;
        _qrStatus = pairResult;
      });
      _startQrPolling();
      return;
    }

    setState(() => _qrStatus = '配对成功，正在连接...');

    // 配对后等待连接服务出现（优先同 IP）；adb 也可能已自动连接
    AdbMdnsService? connectSvc;
    for (var i = 0; i < 15; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      final devices = await AdbService.instance.getDeviceList();
      final alreadyConnected = devices.any(
        (d) => d.id.startsWith('$pairingHost:'),
      );
      if (alreadyConnected) {
        setState(() {
          _qrBusy = false;
          _qrSuccess = true;
          _qrStatus = '连接成功';
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      final list = await AdbService.instance.listMdnsServices();
      for (final s in list) {
        if (s.isConnect && s.host == pairingHost) {
          connectSvc = s;
          break;
        }
      }
      if (connectSvc != null) break;
      // 回退：任意新出现的 connect 服务
      if (i >= 5) {
        for (final s in list) {
          if (s.isConnect) {
            connectSvc = s;
            break;
          }
        }
        if (connectSvc != null) break;
      }
    }

    if (connectSvc == null) {
      setState(() {
        _qrBusy = false;
        _qrStatus = '配对成功，但未发现连接端口，请到「手动连接」填写 IP 与连接端口';
      });
      return;
    }

    final connectResult = await AdbService.instance.connectDevice(
      connectSvc.host,
      connectSvc.port,
    );
    if (!mounted) return;

    if (connectResult == '连接成功') {
      setState(() {
        _qrBusy = false;
        _qrSuccess = true;
        _qrStatus = '连接成功';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _qrBusy = false;
        _qrStatus = connectResult;
      });
    }
  }

  /// 配对成功后，通过 mDNS 自动发现并连接（无需再填连接端口）
  Future<String> _connectAfterPair(String host) async {
    for (var i = 0; i < 15; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return '已取消';

      final devices = await AdbService.instance.getDeviceList();
      if (devices.any((d) => d.id.startsWith('$host:'))) {
        return '连接成功';
      }

      final list = await AdbService.instance.listMdnsServices();
      AdbMdnsService? connectSvc;
      for (final s in list) {
        if (s.isConnect && s.host == host) {
          connectSvc = s;
          break;
        }
      }
      if (connectSvc == null && i >= 5) {
        for (final s in list) {
          if (s.isConnect) {
            connectSvc = s;
            break;
          }
        }
      }
      if (connectSvc != null) {
        return AdbService.instance.connectDevice(
          connectSvc.host,
          connectSvc.port,
        );
      }
    }
    return '配对成功，但未自动发现连接端口。请到无线调试主页复制「IP地址和端口」再连接一次（配对码留空）';
  }

  Future<void> _doAction() async {
    final parsed = _parseAddress(_addressController.text);
    final pairCode = _pairCodeController.text.trim();

    if (parsed == null) {
      setState(() => _statusMessage = '请填写地址，格式如 192.168.1.11:34545');
      return;
    }
    final (ip, port) = parsed;
    final doPair = pairCode.isNotEmpty;
    if (doPair && !RegExp(r'^\d{6}$').hasMatch(pairCode)) {
      setState(() => _statusMessage = '配对码应为 6 位数字');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = doPair ? '正在配对...' : '正在连接...';
    });

    if (doPair) {
      var pairResult = await AdbService.instance.pairDevice(ip, port, pairCode);
      if (!mounted) return;
      if (pairResult != '配对成功') {
        setState(() {
          _isLoading = false;
          _statusMessage = pairResult;
        });
        return;
      }
      setState(() => _statusMessage = '配对成功，正在自动连接...');
      final connectResult = await _connectAfterPair(ip);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = connectResult;
      });
      if (connectResult == '连接成功') {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context).pop(true);
      }
      return;
    }

    var connectResult = await AdbService.instance.connectDevice(ip, port);
    if (!mounted) return;

    // 连接失败时给出明确指引：多数情况是端口填错，不是必须重新配对
    var message = connectResult;
    final lower = connectResult.toLowerCase();
    if (connectResult != '连接成功') {
      if (lower.contains('refused') || lower.contains('拒绝')) {
        message = '$connectResult\n端口可能已变化，请重新复制无线调试主页的「IP地址和端口」（一般无需再配对）';
      } else if (lower.contains('failed to connect') ||
          lower.contains('unable') ||
          lower.contains('未授权') ||
          lower.contains('unauthorized')) {
        message = '$connectResult\n若始终连不上，再展开下方「首次配对」填配对码';
      }
    }

    setState(() {
      _isLoading = false;
      _statusMessage = message;
    });

    if (connectResult == '连接成功') {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _connectDiscovered(AdbMdnsService svc) async {
    _addressController.text = svc.endpoint;
    _pairCodeController.clear();
    setState(() {
      _showFirstPair = false;
      _isLoading = true;
      _statusMessage = '正在连接 ${svc.endpoint}...';
    });
    final result =
        await AdbService.instance.connectDevice(svc.host, svc.port);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _statusMessage = result == '连接成功'
          ? result
          : '$result\n若失败，多半尚未配对过，请展开「首次配对」';
    });
    if (result == '连接成功') {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _stopQrPolling();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _addressController.dispose();
    _pairCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 480,
          maxWidth: 520,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '无线连接',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '本机IP: $_localIp',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey[600],
                tabs: const [
                  Tab(text: '二维码配对'),
                  Tab(text: '手动连接'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 380,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQrTab(),
                    _buildManualTab(),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '1. 手机打开 设置 > 开发者选项 > 无线调试\n'
              '2. 选择「使用二维码配对设备」\n'
              '3. 扫描下方二维码，等待自动配对并连接\n'
              '需 Android 11+，且手机与电脑在同一局域网',
              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: QrImageView(
                data: _qrContent,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '配对码: $_qrPassword',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          _buildStatusBanner(
            message: _qrStatus,
            loading: _qrBusy || (!_qrSuccess && _qrStatus.contains('等待')),
            success: _qrSuccess || _qrStatus.contains('成功'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _qrBusy ? null : _refreshQr,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('刷新二维码'),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    final needPair = _needPair;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '配对只需一次。之后断开再连，填地址（或点下方发现的设备）即可，不必再填配对码。',
              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
            ),
          ),
          if (_discoveredConnect.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '已发现可连接设备',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _isLoading ? null : _refreshDiscoveredConnect,
                  child: const Text('刷新'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _discoveredConnect.map((s) {
                return ActionChip(
                  avatar: const Icon(Icons.wifi, size: 16),
                  label: Text(s.endpoint),
                  onPressed: _isLoading ? null : () => _connectDiscovered(s),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: '地址',
              hintText: '无线调试主页的 IP地址和端口',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _doAction,
              icon: Icon(
                needPair ? Icons.phonelink_ring : Icons.wifi,
                size: 18,
              ),
              label: Text(needPair ? '配对并连接' : '连接'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _showFirstPair,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                '首次配对才需要（填配对码）',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              onExpansionChanged: (v) => setState(() => _showFirstPair = v),
              children: [
                TextField(
                  controller: _pairCodeController,
                  decoration: const InputDecoration(
                    labelText: '配对码',
                    hintText: '手机「使用配对码配对」里的 6 位数字',
                    helperText: '地址请填配对弹窗里的 IP:配对端口',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
              ],
            ),
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildStatusBanner(
              message: _statusMessage,
              loading: _isLoading,
              success: _statusMessage.contains('成功'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBanner({
    required String message,
    required bool loading,
    required bool success,
  }) {
    final waiting = message.contains('中...') || message.contains('等待');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: success
            ? Colors.green[50]
            : waiting
                ? Colors.blue[50]
                : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (!loading)
            Icon(
              success ? Icons.check_circle : Icons.info,
              size: 16,
              color: success ? Colors.green : (waiting ? Colors.blue : Colors.red),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: success
                    ? Colors.green[700]
                    : waiting
                        ? Colors.blue[700]
                        : Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
