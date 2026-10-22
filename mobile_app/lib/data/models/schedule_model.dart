class ScheduleModel {
  final int id;
  final int socketId;
  final String scheduleType; // TIMER / CYCLE / AUTO_OFF / CRON
  final int? durationSec;
  final int? cycleOnSec;
  final int? cycleOffSec;
  final int? autoOffDelaySec;
  final String? cronExpression;
  final bool targetState;
  final bool isActive;
  final DateTime? nextRunAt;

  ScheduleModel({
    required this.id,
    required this.socketId,
    required this.scheduleType,
    this.durationSec,
    this.cycleOnSec,
    this.cycleOffSec,
    this.autoOffDelaySec,
    this.cronExpression,
    required this.targetState,
    this.isActive = true,
    this.nextRunAt,
  });

  ScheduleModel copyWith({
    int? id,
    int? socketId,
    String? scheduleType,
    int? durationSec,
    int? cycleOnSec,
    int? cycleOffSec,
    int? autoOffDelaySec,
    String? cronExpression,
    bool? targetState,
    bool? isActive,
    DateTime? nextRunAt,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      socketId: socketId ?? this.socketId,
      scheduleType: scheduleType ?? this.scheduleType,
      durationSec: durationSec ?? this.durationSec,
      cycleOnSec: cycleOnSec ?? this.cycleOnSec,
      cycleOffSec: cycleOffSec ?? this.cycleOffSec,
      autoOffDelaySec: autoOffDelaySec ?? this.autoOffDelaySec,
      cronExpression: cronExpression ?? this.cronExpression,
      targetState: targetState ?? this.targetState,
      isActive: isActive ?? this.isActive,
      nextRunAt: nextRunAt ?? this.nextRunAt,
    );
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] ?? 0,
      socketId: json['socket_id'] ?? 0,
      scheduleType: json['schedule_type'] ?? 'TIMER',
      durationSec: json['duration_sec'],
      cycleOnSec: json['cycle_on_sec'],
      cycleOffSec: json['cycle_off_sec'],
      autoOffDelaySec: json['auto_off_delay_sec'],
      cronExpression: json['cron_expression'] ?? json['cron'],
      targetState: json['target_state'] ?? false,
      isActive: json['is_active'] ?? true,
      nextRunAt: json['next_run_at'] != null ? DateTime.tryParse(json['next_run_at']) : null,
    );
  }
}
