import 'socket_model.dart';

class StripModel {
  final int id;
  final String macAddress;
  String stripName;
  String icon;
  String roomCategory;
  String model;
  String fwVersion;
  String? ipAddress;
  int? wifiRssi;
  bool isOnline;
  double? currentVoltage;
  double minVoltage;
  double maxVoltage;
  bool voltageProtectEnabled;
  bool autoRecoverVoltage;
  bool autoSheddingEnabled;
  bool childLock;
  List<SocketModel> sockets;

  StripModel({
    required this.id,
    required this.macAddress,
    required this.stripName,
    this.icon = '💻',
    this.roomCategory = 'office',
    this.model = 'LGU+-TAP-HW002',
    this.fwVersion = '1.0.66',
    this.ipAddress,
    this.wifiRssi,
    this.isOnline = false,
    this.currentVoltage,
    this.minVoltage = 185.0,
    this.maxVoltage = 245.0,
    this.voltageProtectEnabled = true,
    this.autoRecoverVoltage = true,
    this.autoSheddingEnabled = true,
    this.childLock = false,
    required this.sockets,
  });

  double get totalWatt => sockets.fold(0.0, (sum, s) => sum + (s.state ? s.currentWatt : 0.0));
  double get totalAmp => sockets.fold(0.0, (sum, s) => sum + (s.state ? s.currentAmp : 0.0));
  double get totalKwh => sockets.fold(0.0, (sum, s) => sum + s.rawEnergyKwh);

  factory StripModel.fromJson(Map<String, dynamic> json) {
    var rawSockets = json['sockets'] as List? ?? [];
    List<SocketModel> parsedSockets = rawSockets.map((s) => SocketModel.fromJson(s)).toList();

    // Check if protection is nested inside "protection" object
    final prot = json['protection'] as Map<String, dynamic>?;

    return StripModel(
      id: json['id'] ?? 0,
      macAddress: json['mac_address'] ?? json['mac'] ?? '',
      stripName: json['strip_name'] ?? json['name'] ?? 'مشترك ذكي',
      icon: json['icon'] ?? '💻',
      roomCategory: json['room_category'] ?? 'office',
      model: json['model'] ?? 'LGU+-TAP-HW002',
      fwVersion: json['fw_version'] ?? json['fw'] ?? '1.0.66',
      ipAddress: json['ip_address'] ?? json['ip'],
      wifiRssi: json['wifi_rssi'] ?? json['rssi'],
      isOnline: json['is_online'] ?? json['online'] ?? false,
      currentVoltage: (json['current_voltage'] ?? json['voltage'] as num?)?.toDouble(),
      minVoltage: (prot?['min_voltage'] ?? json['min_voltage'] as num?)?.toDouble() ?? 185.0,
      maxVoltage: (prot?['max_voltage'] ?? json['max_voltage'] as num?)?.toDouble() ?? 245.0,
      voltageProtectEnabled: prot?['voltage_protect_enabled'] ?? json['voltage_protect_enabled'] ?? true,
      autoRecoverVoltage: prot?['auto_recover_voltage'] ?? json['auto_recover_voltage'] ?? true,
      autoSheddingEnabled: prot?['auto_shedding_enabled'] ?? json['auto_shedding_enabled'] ?? true,
      childLock: json['child_lock'] ?? false,
      sockets: parsedSockets,
    );
  }
}
