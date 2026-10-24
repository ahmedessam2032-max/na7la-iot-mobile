import 'socket_model.dart';

class StripModel {
  int id;
  String mac;
  String name;
  String icon;
  String roomCategory;
  bool isClaimed;
  String model;
  String fw;
  String? ip;
  bool isOnline;
  double voltage;
  int? rssi;
  bool childLock;
  double totalWatt;
  double totalAmp;
  double totalKwh;
  double totalCostEgp;
  double minVoltage;
  double maxVoltage;
  bool voltageProtectEnabled;
  bool autoRecoverVoltage;
  String voltageExemptSockets;
  int voltageRecoverDelaySec;
  int voltageBreachCount;
  int disconnectCount;
  String? lastDisconnectAt;
  String? lastSeen;
  String powerReturnState;
  bool biometricControl;
  bool autoSheddingEnabled;
  int maxTempC;
  double maxTotalWatt;
  double maxTotalAmp;
  List<SocketModel> sockets;

  // Aliases for seamless compatibility across screens
  String get macAddress => mac;
  set macAddress(String v) => mac = v;

  String get stripName => name;
  set stripName(String v) => name = v;

  double get currentVoltage => voltage;
  set currentVoltage(double? v) => voltage = v ?? 220.0;

  String get fwVersion => fw;
  set fwVersion(String v) => fw = v;

  String? get ipAddress => ip;
  set ipAddress(String? v) => ip = v;

  StripModel({
    required this.id,
    required this.mac,
    required this.name,
    this.icon = '💻',
    this.roomCategory = 'office',
    this.isClaimed = true,
    required this.model,
    required this.fw,
    this.ip,
    required this.isOnline,
    this.voltage = 220.0,
    this.rssi,
    required this.childLock,
    required this.totalWatt,
    required this.totalAmp,
    required this.totalKwh,
    required this.totalCostEgp,
    this.minVoltage = 185.0,
    this.maxVoltage = 245.0,
    this.voltageProtectEnabled = true,
    this.autoRecoverVoltage = true,
    this.voltageExemptSockets = '2,4',
    this.voltageRecoverDelaySec = 180,
    this.voltageBreachCount = 0,
    this.disconnectCount = 0,
    this.lastDisconnectAt,
    this.lastSeen,
    this.powerReturnState = 'LAST',
    this.biometricControl = false,
    this.autoSheddingEnabled = true,
    this.maxTempC = 65,
    this.maxTotalWatt = 3000.0,
    this.maxTotalAmp = 16.0,
    required this.sockets,
  });

  factory StripModel.fromJson(Map<String, dynamic> json) {
    final prot = json['protection'] as Map<String, dynamic>? ?? {};
    final socksList = (json['sockets'] as List<dynamic>? ?? [])
        .map((e) => SocketModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return StripModel(
      id: json['id'] ?? 0,
      mac: json['mac'] ?? json['mac_address'] ?? '',
      name: json['name'] ?? json['strip_name'] ?? 'مشترك ذكي',
      icon: json['icon'] ?? '💻',
      roomCategory: json['room_category'] ?? 'office',
      isClaimed: json['is_claimed'] ?? true,
      model: json['model'] ?? 'LGU+-TAP-HW002',
      fw: json['fw'] ?? json['fw_version'] ?? '1.0.66',
      ip: json['ip'] ?? json['ip_address'],
      isOnline: json['online'] ?? json['is_online'] ?? false,
      voltage: json['voltage'] != null
          ? (json['voltage'] as num).toDouble()
          : (json['current_voltage'] != null ? (json['current_voltage'] as num).toDouble() : 220.0),
      rssi: json['rssi'] ?? json['wifi_rssi'],
      childLock: json['child_lock'] ?? false,
      totalWatt: (json['total_watt'] ?? 0.0).toDouble(),
      totalAmp: (json['total_amp'] ?? 0.0).toDouble(),
      totalKwh: (json['total_kwh'] ?? 0.0).toDouble(),
      totalCostEgp: (json['total_cost_egp'] ?? 0.0).toDouble(),
      minVoltage: (prot['min_voltage'] ?? 185.0).toDouble(),
      maxVoltage: (prot['max_voltage'] ?? 245.0).toDouble(),
      voltageProtectEnabled: prot['voltage_protect_enabled'] ?? true,
      autoRecoverVoltage: prot['auto_recover_voltage'] ?? true,
      voltageExemptSockets: (prot['voltage_exempt_sockets'] ?? json['voltage_exempt_sockets'] ?? '2,4').toString(),
      voltageRecoverDelaySec: ((prot['voltage_recover_delay_sec'] ?? json['voltage_recover_delay_sec'] ?? 180) as num).toInt(),
      voltageBreachCount: ((json['voltage_breach_count'] ?? 0) as num).toInt(),
      disconnectCount: ((json['disconnect_count'] ?? 0) as num).toInt(),
      lastDisconnectAt: json['last_disconnect_at']?.toString(),
      lastSeen: json['last_seen']?.toString(),
      powerReturnState: (prot['power_return_state'] ?? json['power_return_state'] ?? 'LAST').toString(),
      biometricControl: (prot['biometric_control'] ?? json['biometric_control']) == true,
      autoSheddingEnabled: prot['auto_shedding_enabled'] ?? true,
      maxTempC: prot['max_temp_c'] ?? 65,
      maxTotalWatt: (prot['max_total_watt'] ?? 3000.0).toDouble(),
      maxTotalAmp: (prot['max_total_amp'] ?? 16.0).toDouble(),
      sockets: socksList,
    );
  }
}
