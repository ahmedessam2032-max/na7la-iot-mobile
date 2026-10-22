class SocketModel {
  final int id;
  final int socketIndex;
  String name;
  String icon;
  bool isRouter;
  bool isLocked;
  bool isFavorite;
  bool state;
  double currentWatt;
  double currentAmp;
  int currentTempC;
  double rawEnergyKwh;
  bool compressorProtect;
  int compressorDelaySec;
  double? minWattCutoff;
  int cutoffDelaySec;
  double? maxWattLimit;
  int? autoOffDelaySec;
  String powerOnBehavior; // ON / OFF / LAST
  bool hwOverloadFlag;
  bool hwOverheatFlag;

  SocketModel({
    required this.id,
    required this.socketIndex,
    required this.name,
    this.icon = 'power_plug',
    this.isRouter = false,
    this.isLocked = false,
    this.isFavorite = false,
    this.state = false,
    this.currentWatt = 0.0,
    this.currentAmp = 0.0,
    this.currentTempC = 0,
    this.rawEnergyKwh = 0.0,
    this.compressorProtect = false,
    this.compressorDelaySec = 180,
    this.minWattCutoff,
    this.cutoffDelaySec = 600,
    this.maxWattLimit,
    this.autoOffDelaySec,
    this.powerOnBehavior = 'LAST',
    this.hwOverloadFlag = false,
    this.hwOverheatFlag = false,
  });

  double get totalKwh => rawEnergyKwh;

  factory SocketModel.fromJson(Map<String, dynamic> json) {
    final idx = json['socket_index'] ?? json['index'] ?? 1;
    return SocketModel(
      id: json['id'] ?? idx,
      socketIndex: idx,
      name: json['name'] ?? 'مقبس $idx',
      icon: json['icon'] ?? 'power_plug',
      isRouter: json['is_router'] ?? false,
      isLocked: json['is_locked'] ?? json['is_router'] ?? false,
      isFavorite: json['is_favorite'] ?? false,
      state: json['state'] ?? json['on'] ?? json['reported_state'] ?? false,
      currentWatt: (json['current_watt'] ?? json['watt'] as num?)?.toDouble() ?? 0.0,
      currentAmp: (json['current_amp'] ?? json['amp'] as num?)?.toDouble() ?? 0.0,
      currentTempC: json['current_temp_c'] ?? json['temp_c'] ?? 0,
      rawEnergyKwh: (json['raw_energy_kwh'] ?? json['kwh'] as num?)?.toDouble() ?? 0.0,
      compressorProtect: json['compressor_protect'] ?? false,
      compressorDelaySec: json['compressor_delay_sec'] ?? 180,
      minWattCutoff: (json['min_watt_cutoff'] as num?)?.toDouble(),
      cutoffDelaySec: json['cutoff_delay_sec'] ?? 600,
      maxWattLimit: (json['max_watt_limit'] as num?)?.toDouble(),
      autoOffDelaySec: json['auto_off_delay_sec'] as int?,
      powerOnBehavior: json['power_on_behavior'] ?? 'LAST',
      hwOverloadFlag: json['hw_overload_flag'] ?? false,
      hwOverheatFlag: json['hw_overheat_flag'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'socket_index': socketIndex,
      'name': name,
      'icon': icon,
      'is_router': isRouter,
      'is_locked': isLocked,
      'state': state,
      'current_watt': currentWatt,
      'current_amp': currentAmp,
      'current_temp_c': currentTempC,
      'raw_energy_kwh': rawEnergyKwh,
      'compressor_protect': compressorProtect,
      'compressor_delay_sec': compressorDelaySec,
      'min_watt_cutoff': minWattCutoff,
      'cutoff_delay_sec': cutoffDelaySec,
      'max_watt_limit': maxWattLimit,
      'auto_off_delay_sec': autoOffDelaySec,
      'power_on_behavior': powerOnBehavior,
    };
  }
}
