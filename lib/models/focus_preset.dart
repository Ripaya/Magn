import 'focus_mode.dart';

class FocusPreset {
  const FocusPreset({
    required this.id,
    required this.name,
    required this.mode,
    required this.focusSec,
    required this.shortBreakSec,
    required this.longBreakSec,
    required this.cyclesBeforeLongBreak,
    required this.autoStartBreak,
    required this.autoStartFocus,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final FocusMode mode;
  final int focusSec;
  final int shortBreakSec;
  final int longBreakSec;
  final int cyclesBeforeLongBreak;
  final bool autoStartBreak;
  final bool autoStartFocus;
  final bool isBuiltIn;

  String get subtitle {
    if (mode == FocusMode.endless) {
      return 'Count-Up Flow';
    }
    if (mode == FocusMode.focus) {
      return '${focusSec ~/ 60}m Focus';
    }
    return '${focusSec ~/ 60}m / ${shortBreakSec ~/ 60}m';
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'name': name,
      'mode': mode.storageKey,
      'focus_sec': focusSec,
      'short_break_sec': shortBreakSec,
      'long_break_sec': longBreakSec,
      'cycles_before_long_break': cyclesBeforeLongBreak,
      'auto_start_break': autoStartBreak ? 1 : 0,
      'auto_start_focus': autoStartFocus ? 1 : 0,
      'is_built_in': isBuiltIn ? 1 : 0,
    };
  }

  factory FocusPreset.fromDbMap(Map<String, Object?> map) {
    return FocusPreset(
      id: map['id'] as String,
      name: map['name'] as String,
      mode: FocusMode.fromKey(map['mode'] as String),
      focusSec: map['focus_sec'] as int,
      shortBreakSec: map['short_break_sec'] as int,
      longBreakSec: map['long_break_sec'] as int,
      cyclesBeforeLongBreak: map['cycles_before_long_break'] as int,
      autoStartBreak: (map['auto_start_break'] as int? ?? 0) == 1,
      autoStartFocus: (map['auto_start_focus'] as int? ?? 0) == 1,
      isBuiltIn: (map['is_built_in'] as int? ?? 0) == 1,
    );
  }

  static const List<FocusPreset> defaults = [
    FocusPreset(
      id: 'preset_classic_25_5',
      name: 'Classic 25/5',
      mode: FocusMode.pomodoro,
      focusSec: 25 * 60,
      shortBreakSec: 5 * 60,
      longBreakSec: 15 * 60,
      cyclesBeforeLongBreak: 4,
      autoStartBreak: false,
      autoStartFocus: false,
      isBuiltIn: true,
    ),
    FocusPreset(
      id: 'preset_deep_50_10',
      name: 'Deep 50/10',
      mode: FocusMode.pomodoro,
      focusSec: 50 * 60,
      shortBreakSec: 10 * 60,
      longBreakSec: 25 * 60,
      cyclesBeforeLongBreak: 3,
      autoStartBreak: false,
      autoStartFocus: false,
      isBuiltIn: true,
    ),
    FocusPreset(
      id: 'preset_sprint_15_3',
      name: 'Sprint 15/3',
      mode: FocusMode.pomodoro,
      focusSec: 15 * 60,
      shortBreakSec: 3 * 60,
      longBreakSec: 10 * 60,
      cyclesBeforeLongBreak: 4,
      autoStartBreak: true,
      autoStartFocus: false,
      isBuiltIn: true,
    ),
    FocusPreset(
      id: 'preset_flow_countup',
      name: 'Flow Count-Up',
      mode: FocusMode.endless,
      focusSec: 60 * 60,
      shortBreakSec: 5 * 60,
      longBreakSec: 15 * 60,
      cyclesBeforeLongBreak: 4,
      autoStartBreak: false,
      autoStartFocus: false,
      isBuiltIn: true,
    ),
  ];
}
