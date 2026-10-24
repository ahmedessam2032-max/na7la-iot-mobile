class SocketModel {
  final int id;
  final int index;
  final String name;
  final String icon;
  final String colorHex;
  final int linkGroup;
  final bool doorbellMode;
  final int doorbellPulseSec;
  final bool isPinnedState;
  final double? alertWattThreshold;
  final int? autoOffDelaySec;
  final bool isRouter;
  final bool isLocked;
  final bool isFavorite;
  final bool isOn;
  final bool desiredOn;
  final String powerOnBehavior;
  final double watt;
  final double amp;
  final int? tempC;
  final double kwh;
  final double costEgp;
  final double maxWattLimit;
  final double? minWattCutoff;
  final int cutoffDelaySec;
  final bool compressorProtect;
  final int compressorDelaySec;
  final int? masterSocketId;
  final double masterTriggerWatt;

  SocketModel({
    required this.id,
    required this.index,
    required this.name,
    required this.icon,
    this.colorHex = '#10B981',
    this.linkGroup = 0,
    this.doorbellMode = false,
    this.doorbellPulseSec = 3,
    this.isPinnedState = false,
    this.alertWattThreshold,
    this.autoOffDelaySec,
    required this.isRouter,
    this.isLocked = false,
    required this.isFavorite,
    required this.isOn,
    required this.desiredOn,
    this.powerOnBehavior = 'LAST',
    required this.watt,
    required this.amp,
    this.tempC,
    required this.kwh,
    required this.costEgp,
    this.maxWattLimit = 2500.0,
    this.minWattCutoff,
    this.cutoffDelaySec = 600,
    this.compressorProtect = false,
    this.compressorDelaySec = 180,
    this.masterSocketId,
    this.masterTriggerWatt = 20.0,
  });

  factory SocketModel.fromJson(Map<String, dynamic> json) {
    return SocketModel(
      id: json['id'] ?? 0,
      index: json['index'] ?? 1,
      name: json['name'] ?? 'مقبس',
      icon: json['icon'] ?? 'power_plug',
      colorHex: json['color_hex'] ?? '#10B981',
      linkGroup: (json['link_group'] as num?)?.toInt() ?? 0,
      doorbellMode: json['doorbell_mode'] == true,
      doorbellPulseSec: (json['doorbell_pulse_sec'] as num?)?.toInt() ?? 3,
      isPinnedState: json['is_pinned_state'] == true,
      alertWattThreshold: (json['alert_watt_threshold'] as num?)?.toDouble(),
      autoOffDelaySec: (json['auto_off_delay_sec'] as num?)?.toInt(),
      isRouter: json['is_router'] ?? false,
      isLocked: json['is_locked'] ?? false,
      isFavorite: json['is_favorite'] ?? false,
      isOn: json['on'] ?? false,
      desiredOn: json['desired_on'] ?? (json['on'] ?? false),
      powerOnBehavior: json['power_on_behavior'] ?? 'LAST',
      watt: (json['watt'] ?? 0.0).toDouble(),
      amp: (json['amp'] ?? 0.0).toDouble(),
      tempC: json['temp_c'],
      kwh: (json['kwh'] ?? 0.0).toDouble(),
      costEgp: (json['cost_egp'] ?? 0.0).toDouble(),
      maxWattLimit: (json['max_watt_limit'] ?? 2500.0).toDouble(),
      minWattCutoff: json['min_watt_cutoff'] != null ? (json['min_watt_cutoff'] as num).toDouble() : null,
      cutoffDelaySec: json['cutoff_delay_sec'] ?? 600,
      compressorProtect: json['compressor_protect'] ?? false,
      compressorDelaySec: json['compressor_delay_sec'] ?? 180,
      masterSocketId: json['master_socket_id'],
      masterTriggerWatt: (json['master_trigger_watt'] ?? 20.0).toDouble(),
    );
  }

  SocketModel copyWith({
    bool? isOn,
    bool? desiredOn,
    bool? isFavorite,
    bool? isRouter,
    bool? isLocked,
    String? name,
    String? icon,
    String? colorHex,
    int? linkGroup,
    bool? doorbellMode,
    int? doorbellPulseSec,
    bool? isPinnedState,
    double? alertWattThreshold,
    int? autoOffDelaySec,
    double? watt,
    double? amp,
    int? tempC,
  }) {
    return SocketModel(
      id: id,
      index: index,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      linkGroup: linkGroup ?? this.linkGroup,
      doorbellMode: doorbellMode ?? this.doorbellMode,
      doorbellPulseSec: doorbellPulseSec ?? this.doorbellPulseSec,
      isPinnedState: isPinnedState ?? this.isPinnedState,
      alertWattThreshold: alertWattThreshold ?? this.alertWattThreshold,
      autoOffDelaySec: autoOffDelaySec ?? this.autoOffDelaySec,
      isRouter: isRouter ?? this.isRouter,
      isLocked: isLocked ?? this.isLocked,
      isFavorite: isFavorite ?? this.isFavorite,
      isOn: isOn ?? this.isOn,
      desiredOn: desiredOn ?? this.desiredOn,
      powerOnBehavior: powerOnBehavior,
      watt: watt ?? this.watt,
      amp: amp ?? this.amp,
      tempC: tempC ?? this.tempC,
      kwh: kwh,
      costEgp: costEgp,
      maxWattLimit: maxWattLimit,
      minWattCutoff: minWattCutoff,
      cutoffDelaySec: cutoffDelaySec,
      compressorProtect: compressorProtect,
      compressorDelaySec: compressorDelaySec,
      masterSocketId: masterSocketId,
      masterTriggerWatt: masterTriggerWatt,
    );
  }
}
