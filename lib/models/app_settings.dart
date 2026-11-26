enum AppThemePreference {
  system('system', 'System'),
  light('light', 'Light'),
  oledBlack('oled_black', 'OLED Black');

  const AppThemePreference(this.key, this.label);
  final String key;
  final String label;

  static AppThemePreference fromKey(String? key) =>
      AppThemePreference.values.firstWhere(
        (e) => e.key == key,
        orElse: () => AppThemePreference.system,
      );
}

enum DigitalReadoutMode {
  alwaysOn('always_on', 'Always On'),
  tapToPeek('tap_to_peek', 'Tap to Peek'),
  off('off', 'Pure Analog');

  const DigitalReadoutMode(this.key, this.label);
  final String key;
  final String label;

  static DigitalReadoutMode fromKey(String? key) =>
      DigitalReadoutMode.values.firstWhere(
        (e) => e.key == key,
        orElse: () => DigitalReadoutMode.alwaysOn,
      );
}

enum EndlessGhostTarget {
  lastSession('last_session', 'Last Session'),
  personalBest('personal_best', 'Personal Best'),
  dailyAverage('daily_average', 'Daily Average');

  const EndlessGhostTarget(this.key, this.label);
  final String key;
  final String label;

  static EndlessGhostTarget fromKey(String? key) =>
      EndlessGhostTarget.values.firstWhere(
        (e) => e.key == key,
        orElse: () => EndlessGhostTarget.lastSession,
      );
}

enum AmbientSoundType {
  off('off', 'Off'),
  rain('rain', 'Rain'),
  whiteNoise('white_noise', 'White Noise'),
  mechanicalTick('mechanical_tick', 'Mechanical Tick');

  const AmbientSoundType(this.key, this.label);
  final String key;
  final String label;

  static AmbientSoundType fromKey(String? key) =>
      AmbientSoundType.values.firstWhere(
        (e) => e.key == key,
        orElse: () => AmbientSoundType.off,
      );
}

enum CompletionSound {
  softChime('soft_chime', 'Soft Bell'),
  woodenBlock('wooden_block', 'Wood Tap'),
  singingBowl('singing_bowl', 'Singing Bowl'),
  silent('silent', 'Silent');

  const CompletionSound(this.key, this.label);
  final String key;
  final String label;

  static CompletionSound fromKey(String? key) =>
      CompletionSound.values.firstWhere(
        (e) => e.key == key,
        orElse: () => CompletionSound.softChime,
      );
}

enum VibrationPattern {
  gentle('gentle', 'Gentle Pulse'),
  crisp('crisp', 'Crisp Double'),
  longPulse('long_pulse', 'Sustained'),
  off('off', 'Off');

  const VibrationPattern(this.key, this.label);
  final String key;
  final String label;

  static VibrationPattern fromKey(String? key) =>
      VibrationPattern.values.firstWhere(
        (e) => e.key == key,
        orElse: () => VibrationPattern.gentle,
      );
}

enum NotificationStyle {
  standard('standard', 'Live Controls'),
  minimal('minimal', 'Minimal Chronometer'),
  compact('compact', 'Silent Status');

  const NotificationStyle(this.key, this.label);
  final String key;
  final String label;

  static NotificationStyle fromKey(String? key) =>
      NotificationStyle.values.firstWhere(
        (e) => e.key == key,
        orElse: () => NotificationStyle.standard,
      );
}

class AppSettings {
  const AppSettings({
    // Timing & Cycles
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.cyclesBeforeLongBreak = 4,
    this.autoStartBreaks = false,
    this.autoStartFocus = false,
    this.strictMode = false,
    this.doubleTapExtendEnabled = true,
    this.rimDragStepMinutes = 5,

    // Tier 1 Core Toggles
    this.autoDndEnabled = false,
    this.keepScreenOn = true,
    this.ambientSound = AmbientSoundType.off,

    // Dial & Visuals
    this.themePreference = AppThemePreference.system,
    this.digitalReadoutMode = DigitalReadoutMode.alwaysOn,
    this.endlessGhostTarget = EndlessGhostTarget.lastSession,
    this.hapticRimTicks = true,

    // Alerts & Notifications
    this.completionSound = CompletionSound.softChime,
    this.vibrationPattern = VibrationPattern.gentle,
    this.screenFlashAlert = false,
    this.notificationStyle = NotificationStyle.standard,

    // Active Label
    this.selectedLabelId = 'label_general',
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int cyclesBeforeLongBreak;
  final bool autoStartBreaks;
  final bool autoStartFocus;
  final bool strictMode;
  final bool doubleTapExtendEnabled;
  final int rimDragStepMinutes;

  final bool autoDndEnabled;
  final bool keepScreenOn;
  final AmbientSoundType ambientSound;

  final AppThemePreference themePreference;
  final DigitalReadoutMode digitalReadoutMode;
  final EndlessGhostTarget endlessGhostTarget;
  final bool hapticRimTicks;

  final CompletionSound completionSound;
  final VibrationPattern vibrationPattern;
  final bool screenFlashAlert;
  final NotificationStyle notificationStyle;

  final String selectedLabelId;

  AppSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? cyclesBeforeLongBreak,
    bool? autoStartBreaks,
    bool? autoStartFocus,
    bool? strictMode,
    bool? doubleTapExtendEnabled,
    int? rimDragStepMinutes,
    bool? autoDndEnabled,
    bool? keepScreenOn,
    AmbientSoundType? ambientSound,
    AppThemePreference? themePreference,
    DigitalReadoutMode? digitalReadoutMode,
    EndlessGhostTarget? endlessGhostTarget,
    bool? hapticRimTicks,
    CompletionSound? completionSound,
    VibrationPattern? vibrationPattern,
    bool? screenFlashAlert,
    NotificationStyle? notificationStyle,
    String? selectedLabelId,
  }) {
    return AppSettings(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      cyclesBeforeLongBreak:
          cyclesBeforeLongBreak ?? this.cyclesBeforeLongBreak,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      autoStartFocus: autoStartFocus ?? this.autoStartFocus,
      strictMode: strictMode ?? this.strictMode,
      doubleTapExtendEnabled:
          doubleTapExtendEnabled ?? this.doubleTapExtendEnabled,
      rimDragStepMinutes: rimDragStepMinutes ?? this.rimDragStepMinutes,
      autoDndEnabled: autoDndEnabled ?? this.autoDndEnabled,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      ambientSound: ambientSound ?? this.ambientSound,
      themePreference: themePreference ?? this.themePreference,
      digitalReadoutMode: digitalReadoutMode ?? this.digitalReadoutMode,
      endlessGhostTarget: endlessGhostTarget ?? this.endlessGhostTarget,
      hapticRimTicks: hapticRimTicks ?? this.hapticRimTicks,
      completionSound: completionSound ?? this.completionSound,
      vibrationPattern: vibrationPattern ?? this.vibrationPattern,
      screenFlashAlert: screenFlashAlert ?? this.screenFlashAlert,
      notificationStyle: notificationStyle ?? this.notificationStyle,
      selectedLabelId: selectedLabelId ?? this.selectedLabelId,
    );
  }

  Map<String, String> toKeyValueMap() => {
        'focusMinutes': focusMinutes.toString(),
        'shortBreakMinutes': shortBreakMinutes.toString(),
        'longBreakMinutes': longBreakMinutes.toString(),
        'cyclesBeforeLongBreak': cyclesBeforeLongBreak.toString(),
        'autoStartBreaks': autoStartBreaks.toString(),
        'autoStartFocus': autoStartFocus.toString(),
        'strictMode': strictMode.toString(),
        'doubleTapExtendEnabled': doubleTapExtendEnabled.toString(),
        'rimDragStepMinutes': rimDragStepMinutes.toString(),
        'autoDndEnabled': autoDndEnabled.toString(),
        'keepScreenOn': keepScreenOn.toString(),
        'ambientSound': ambientSound.key,
        'themePreference': themePreference.key,
        'digitalReadoutMode': digitalReadoutMode.key,
        'endlessGhostTarget': endlessGhostTarget.key,
        'hapticRimTicks': hapticRimTicks.toString(),
        'completionSound': completionSound.key,
        'vibrationPattern': vibrationPattern.key,
        'screenFlashAlert': screenFlashAlert.toString(),
        'notificationStyle': notificationStyle.key,
        'selectedLabelId': selectedLabelId,
      };

  factory AppSettings.fromKeyValueMap(Map<String, String> map) {
    int parseInt(String key, int fallback) =>
        int.tryParse(map[key] ?? '') ?? fallback;
    bool parseBool(String key, bool fallback) =>
        map[key] == null ? fallback : map[key] == 'true';

    return AppSettings(
      focusMinutes: parseInt('focusMinutes', 25),
      shortBreakMinutes: parseInt('shortBreakMinutes', 5),
      longBreakMinutes: parseInt('longBreakMinutes', 15),
      cyclesBeforeLongBreak: parseInt('cyclesBeforeLongBreak', 4),
      autoStartBreaks: parseBool('autoStartBreaks', false),
      autoStartFocus: parseBool('autoStartFocus', false),
      strictMode: parseBool('strictMode', false),
      doubleTapExtendEnabled: parseBool('doubleTapExtendEnabled', true),
      rimDragStepMinutes: parseInt('rimDragStepMinutes', 5),
      autoDndEnabled: parseBool('autoDndEnabled', false),
      keepScreenOn: parseBool('keepScreenOn', true),
      ambientSound: AmbientSoundType.fromKey(map['ambientSound']),
      themePreference: AppThemePreference.fromKey(map['themePreference']),
      digitalReadoutMode:
          DigitalReadoutMode.fromKey(map['digitalReadoutMode']),
      endlessGhostTarget:
          EndlessGhostTarget.fromKey(map['endlessGhostTarget']),
      hapticRimTicks: parseBool('hapticRimTicks', true),
      completionSound: CompletionSound.fromKey(map['completionSound']),
      vibrationPattern: VibrationPattern.fromKey(map['vibrationPattern']),
      screenFlashAlert: parseBool('screenFlashAlert', false),
      notificationStyle: NotificationStyle.fromKey(map['notificationStyle']),
      selectedLabelId: map['selectedLabelId'] ?? 'label_general',
    );
  }
}
