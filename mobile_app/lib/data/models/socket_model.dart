class SocketModel {
  int id;
  int index;
  String name;
  String icon;
  String colorHex;
  int linkGroup;
  bool doorbellMode;
  int doorbellPulseSec;
  bool isPinnedState;
  double? alertWattThreshold;
  int? autoOffDelaySec;
  bool isRouter;
  bool isLocked;
  bool isFavorite;
  bool isOn;
  bool desiredOn;
  String powerOnBehavior;
  double watt;
  double amp;
  int? tempC;
  double kwh;
  double costEgp;
  double maxWattLimit;
  double? minWattCutoff;
  int cutoffDelaySec;
  bool compressorProtect;
  int compressorDelaySec;
  int? masterSocketId;
  double masterTriggerWatt;

  // Aliases for seamless compatibility across screens
  int get socketIndex => index;
  set socketIndex(int v) => index = v;

  bool get state => isOn;
  set state(bool v) => isOn = v;

  double get currentWatt => watt;
  set currentWatt(double v) => watt = v;

  double get currentAmp => amp;
  set currentAmp(double v) => amp = v;

  int get currentTempC => tempC ?? 28;
  set currentTempC(int? v) => tempC = v;

  double get rawEnergyKwh => kwh;
  set rawEnergyKwh(double v) => kwh = v;

  SocketModel({
    required this.id,
    int? index,
    int? socketIndex,
    required this.name,
    this.icon = 'power_plug',
    this.colorHex = '#10B981',
    this.linkGroup = 0,
    this.doorbellMode = false,
    this.doorbellPulseSec = 3,
    this.isPinnedState = false,
    this.alertWattThreshold,
    this.autoOffDelaySec,
    this.isRouter = false,
    this.isLocked = false,
    this.isFavorite = false,
    this.isOn = false,
    this.desiredOn = false,
    this.powerOnBehavior = 'LAST',
    this.watt = 0.0,
    this.amp = 0.0,
    this.tempC,
    this.kwh = 0.0,
    this.costEgp = 0.0,
    this.maxWattLimit = 2500.0,
    this.minWattCutoff,
    this.cutoffDelaySec = 600,
    this.compressorProtect = false,
    this.compressorDelaySec = 180,
    this.masterSocketId,
    this.masterTriggerWatt = 20.0,
  }) : index = index ?? socketIndex ?? 1;

  factory SocketModel.fromJson(Map<String, dynamic> json) {
    return SocketModel(
      id: json['id'] ?? 0,
      index: json['index'] ?? json['socket_index'] ?? 1,
      name: json['name'] ?? json['socket_name'] ?? 'مقبس',
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
      isOn: json['on'] ?? json['state'] ?? false,
      desiredOn: json['desired_on'] ?? (json['on'] ?? json['state'] ?? false),
      powerOnBehavior: json['power_on_behavior'] ?? 'LAST',
      watt: (json['watt'] ?? json['current_watt'] ?? 0.0).toDouble(),
      amp: (json['amp'] ?? json['current_amp'] ?? 0.0).toDouble(),
      tempC: json['temp_c'] ?? json['current_temp_c'],
      kwh: (json['kwh'] ?? json['raw_energy_kwh'] ?? 0.0).toDouble(),
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
