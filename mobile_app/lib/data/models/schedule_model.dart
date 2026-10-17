class ScheduleModel {
  final int id;
  final int socketId;
  final String scheduleType; // TIMER / CYCLE / AUTO_OFF / CRON
  final int? durationSec;
  final int? cycleOnSec;
  final int? cycleOffSec;
  final int? autoOffDelaySec;
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
    required this.targetState,
    this.isActive = true,
    this.nextRunAt,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] ?? 0,
      socketId: json['socket_id'] ?? 0,
      scheduleType: json['schedule_type'] ?? 'TIMER',
      durationSec: json['duration_sec'],
      cycleOnSec: json['cycle_on_sec'],
      cycleOffSec: json['cycle_off_sec'],
      autoOffDelaySec: json['auto_off_delay_sec'],
      targetState: json['target_state'] ?? false,
      isActive: json['is_active'] ?? true,
      nextRunAt: json['next_run_at'] != null ? DateTime.tryParse(json['next_run_at']) : null,
    );
  }
}
