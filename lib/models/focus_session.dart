import 'focus_mode.dart';

class FocusSession {
  const FocusSession({
    required this.id,
    required this.mode,
    this.labelId,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.plannedSec,
    required this.actualSec,
    required this.completed,
    this.notes = '',
  });

  final String id;
  final FocusMode mode;
  final String? labelId;
  final int startedAtMs;
  final int endedAtMs;
  final int plannedSec;
  final int actualSec;
  final bool completed;
  final String notes;

  DateTime get startedAt => DateTime.fromMillisecondsSinceEpoch(startedAtMs);
  DateTime get endedAt => DateTime.fromMillisecondsSinceEpoch(endedAtMs);

  FocusSession copyWith({
    String? id,
    FocusMode? mode,
    String? labelId,
    bool clearLabel = false,
    int? startedAtMs,
    int? endedAtMs,
    int? plannedSec,
    int? actualSec,
    bool? completed,
    String? notes,
  }) {
    return FocusSession(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      labelId: clearLabel ? null : (labelId ?? this.labelId),
      startedAtMs: startedAtMs ?? this.startedAtMs,
      endedAtMs: endedAtMs ?? this.endedAtMs,
      plannedSec: plannedSec ?? this.plannedSec,
      actualSec: actualSec ?? this.actualSec,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'mode': mode.storageKey,
      'label_id': labelId,
      'started_at': startedAtMs,
      'ended_at': endedAtMs,
      'planned_sec': plannedSec,
      'actual_sec': actualSec,
      'completed': completed ? 1 : 0,
      'notes': notes,
    };
  }

  factory FocusSession.fromDbMap(Map<String, Object?> map) {
    return FocusSession(
      id: map['id'] as String,
      mode: FocusMode.fromKey(map['mode'] as String),
      labelId: map['label_id'] as String?,
      startedAtMs: map['started_at'] as int,
      endedAtMs: map['ended_at'] as int,
      plannedSec: map['planned_sec'] as int,
      actualSec: map['actual_sec'] as int,
      completed: (map['completed'] as int? ?? 1) == 1,
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.storageKey,
        'label_id': labelId,
        'started_at': startedAtMs,
        'ended_at': endedAtMs,
        'planned_sec': plannedSec,
        'actual_sec': actualSec,
        'completed': completed,
        'notes': notes,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        id: json['id'] as String,
        mode: FocusMode.fromKey(json['mode'] as String? ?? 'focus'),
        labelId: json['label_id'] as String?,
        startedAtMs: (json['started_at'] as num).toInt(),
        endedAtMs: (json['ended_at'] as num).toInt(),
        plannedSec: (json['planned_sec'] as num).toInt(),
        actualSec: (json['actual_sec'] as num).toInt(),
        completed: json['completed'] as bool? ?? true,
        notes: json['notes'] as String? ?? '',
      );
}
