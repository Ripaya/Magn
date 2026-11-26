/// Core domain constants for Magn — Kinetic Focus Dial.
class AppConstants {
  AppConstants._();

  static const String appName = 'Magn';
  static const String methodChannelName = 'magn.ion/native_timer';
  static const String eventChannelName = 'magn.ion/native_events';

  // Timing constraints
  static const int minFocusMinutes = 1;
  static const int maxFocusMinutes = 180;
  static const int minShortBreakMinutes = 1;
  static const int maxShortBreakMinutes = 30;
  static const int minLongBreakMinutes = 5;
  static const int maxLongBreakMinutes = 60;
  static const int minCyclesBeforeLongBreak = 2;
  static const int maxCyclesBeforeLongBreak = 8;

  // Minimum seconds required to persist a session to history
  static const int minLoggableSeconds = 60;

  // Hold-to-Skip / Stop duration in milliseconds (0.8 seconds per blueprint)
  static const int holdToSkipDurationMs = 800;

  // Quick extension duration on double-tap dial center
  static const int quickExtendMinutes = 5;

  // Endless Flow dial lap duration (60 minutes per full 360° sweep)
  static const int endlessLapSeconds = 3600;

  // Earned break ratio for Endless Flow mode (20% of focus time)
  static const double earnedBreakRatio = 0.20;

  // Pure Analog tap-to-peek fade duration
  static const Duration peekDigitsDuration = Duration(seconds: 3);
}
