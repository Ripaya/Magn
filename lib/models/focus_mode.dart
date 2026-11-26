/// The three core focus modes supported by the Kinetic Dial.
enum FocusMode {
  pomodoro('pomodoro', 'POMODORO', 'Structured focus & rest cycles'),
  focus('focus', 'FOCUS', 'Single uninterrupted target session'),
  endless('endless', 'ENDLESS', 'Open-ended flow with earned break');

  const FocusMode(this.storageKey, this.displayLabel, this.subtitle);

  final String storageKey;
  final String displayLabel;
  final String subtitle;

  FocusMode get next {
    final values = FocusMode.values;
    return values[(index + 1) % values.length];
  }

  static FocusMode fromKey(String key) {
    return FocusMode.values.firstWhere(
      (m) => m.storageKey == key,
      orElse: () => FocusMode.pomodoro,
    );
  }
}

/// Active phase within Pomodoro (or earned break after Endless Flow).
enum SessionPhase {
  focus('FOCUS'),
  shortBreak('SHORT BREAK'),
  longBreak('LONG BREAK'),
  earnedBreak('EARNED BREAK');

  const SessionPhase(this.label);

  final String label;

  bool get isBreak => this != SessionPhase.focus;
}

/// Deterministic five-state timer machine.
enum TimerStatus {
  idle,
  running,
  paused,
  phaseTransition,
  completed,
}
