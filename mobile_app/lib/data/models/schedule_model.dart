class ScheduleModel {
  final int id;
  final int socketId;
  final int socketIndex;
  final String socketName;
  final String scheduleType; // TIMER / CYCLE / AUTO_OFF / CRON
  final int? durationSec;
  final int? cycleOnSec;
  final int? cycleOffSec;
  final int? autoOffDelaySec;
  final String? cronExpression;
  final bool targetState;
  final bool holdState;
  final bool isActive;
  final DateTime? nextRunAt;

  ScheduleModel({
    required this.id,
    required this.socketId,
    this.socketIndex = 1,
    this.socketName = 'مقبس',
    required this.scheduleType,
    this.durationSec,
    this.cycleOnSec,
    this.cycleOffSec,
    this.autoOffDelaySec,
    this.cronExpression,
    required this.targetState,
    this.holdState = false,
    this.isActive = true,
    this.nextRunAt,
  });

  ScheduleModel copyWith({
    int? id,
    int? socketId,
    int? socketIndex,
    String? socketName,
    String? scheduleType,
    int? durationSec,
    int? cycleOnSec,
    int? cycleOffSec,
    int? autoOffDelaySec,
    String? cronExpression,
    bool? targetState,
    bool? holdState,
    bool? isActive,
    DateTime? nextRunAt,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      socketId: socketId ?? this.socketId,
      socketIndex: socketIndex ?? this.socketIndex,
      socketName: socketName ?? this.socketName,
      scheduleType: scheduleType ?? this.scheduleType,
      durationSec: durationSec ?? this.durationSec,
      cycleOnSec: cycleOnSec ?? this.cycleOnSec,
      cycleOffSec: cycleOffSec ?? this.cycleOffSec,
      autoOffDelaySec: autoOffDelaySec ?? this.autoOffDelaySec,
      cronExpression: cronExpression ?? this.cronExpression,
      targetState: targetState ?? this.targetState,
      holdState: holdState ?? this.holdState,
      isActive: isActive ?? this.isActive,
      nextRunAt: nextRunAt ?? this.nextRunAt,
    );
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] ?? 0,
      socketId: json['socket_id'] ?? 0,
      socketIndex: json['socket_index'] ?? 1,
      socketName: json['socket_name'] ?? 'مقبس',
      scheduleType: json['schedule_type'] ?? 'TIMER',
      durationSec: json['duration_sec'],
      cycleOnSec: json['cycle_on_sec'],
      cycleOffSec: json['cycle_off_sec'],
      autoOffDelaySec: json['auto_off_delay_sec'],
      cronExpression: json['cron_expr'] ?? json['cron_expression'] ?? json['cron'],
      targetState: json['target_state'] ?? false,
      holdState: json['hold_state'] == true,
      isActive: json['is_active'] ?? true,
      nextRunAt: json['next_run_at'] != null ? DateTime.tryParse(json['next_run_at'].toString()) : null,
    );
  }
}
