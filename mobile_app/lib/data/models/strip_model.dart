import 'socket_model.dart';

class StripModel {
  final int id;
  final String mac;
  final String name;
  final String icon;
  final String roomCategory;
  final bool isClaimed;
  final String model;
  final String fw;
  final String? ip;
  final bool isOnline;
  final double? voltage;
  final int? rssi;
  final bool childLock;
  final double totalWatt;
  final double totalAmp;
  final double totalKwh;
  final double totalCostEgp;
  final double minVoltage;
  final double maxVoltage;
  final bool voltageProtectEnabled;
  final bool autoRecoverVoltage;
  final String voltageExemptSockets;
  final int voltageRecoverDelaySec;
  final int voltageBreachCount;
  final int disconnectCount;
  final String? lastDisconnectAt;
  final String? lastSeen;
  final String powerReturnState;
  final bool biometricControl;
  final bool autoSheddingEnabled;
  final int maxTempC;
  final double maxTotalWatt;
  final double maxTotalAmp;
  final List<SocketModel> sockets;

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
    this.voltage,
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
      mac: json['mac'] ?? '',
      name: json['name'] ?? 'مشترك ذكي',
      icon: json['icon'] ?? '💻',
      roomCategory: json['room_category'] ?? 'office',
      isClaimed: json['is_claimed'] ?? true,
      model: json['model'] ?? 'LGU+-TAP-HW002',
      fw: json['fw'] ?? '1.0.66',
      ip: json['ip'],
      isOnline: json['online'] ?? false,
      voltage: json['voltage'] != null ? (json['voltage'] as num).toDouble() : null,
      rssi: json['rssi'],
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
