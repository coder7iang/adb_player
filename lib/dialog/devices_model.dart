import 'package:adb_player/entity/list_filter_item.dart';

class DevicesModel extends ListFilterItem {
  String brand;
  String model;
  String id;

  DevicesModel(this.brand, this.model, this.id)
      : super(brand + " " + model + " " + id);

  /// 是否为无线连接设备（ip:port 或 mDNS 服务名）
  bool get isWireless =>
      RegExp(r'^\d+\.\d+\.\d+\.\d+:\d+$').hasMatch(id) ||
      id.contains('_adb-tls-connect._tcp') ||
      id.contains('_adb-tls-pairing._tcp');
}

/// ADB mDNS 发现的服务（配对 / 连接）
class AdbMdnsService {
  final String name;
  final String type;
  final String host;
  final String port;

  const AdbMdnsService({
    required this.name,
    required this.type,
    required this.host,
    required this.port,
  });

  bool get isPairing => type.contains('adb-tls-pairing');
  bool get isConnect => type.contains('adb-tls-connect');

  String get endpoint => '$host:$port';
}
