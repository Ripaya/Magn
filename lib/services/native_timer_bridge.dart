import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../models/app_settings.dart';

/// Native Android bridge using MethodChannel + EventChannel for:
/// 1. `specialUse` Foreground Service with live chronometer & inline Pause/Skip actions
/// 2. `AlarmManager.setExactAndAllowWhileIdle()` for Doze-safe phase completion chimes
/// 3. Android 15+ `AutomaticZenRule` Focus Mode DND (with API 24-34 fallback)
/// 4. Native haptic/vibration patterns and completion chime playback
class NativeTimerBridge {
  NativeTimerBridge()
      : _methodChannel = const MethodChannel(AppConstants.methodChannelName),
        _eventChannel = const EventChannel(AppConstants.eventChannelName);

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<String>? _nativeActions;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// Emits action names tapped directly in the ongoing notification shade:
  /// `'pause'`, `'resume'`, `'skip'`, `'alarm_fired'`.
  Stream<String> get nativeActions {
    if (!_isAndroid) {
      return const Stream<String>.empty();
    }
    _nativeActions ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event.toString())
        .handleError((_) {});
    return _nativeActions!;
  }

  Future<void> startForegroundSession({
    required String title,
    required String subtitle,
    required int startUtcMs,
    required int? targetEndUtcMs,
    required bool isCountUp,
    required NotificationStyle notificationStyle,
    required CompletionSound completionSound,
    required VibrationPattern vibrationPattern,
  }) async {
    if (!_isAndroid) return;
    try {
      await _methodChannel.invokeMethod('startForegroundSession', {
        'title': title,
        'subtitle': subtitle,
        'startUtcMs': startUtcMs,
        'targetEndUtcMs': targetEndUtcMs,
        'isCountUp': isCountUp,
        'notificationStyle': notificationStyle.key,
        'completionSound': completionSound.key,
        'vibrationPattern': vibrationPattern.key,
      });
    } catch (_) {
      // Gracefully ignore when running in unit tests or unsupported platform
    }
  }

  Future<void> pauseForegroundSession({
    required String title,
    required String formattedTime,
  }) async {
    if (!_isAndroid) return;
    try {
      await _methodChannel.invokeMethod('pauseForegroundSession', {
        'title': title,
        'formattedTime': formattedTime,
      });
    } catch (_) {}
  }

  Future<void> stopForegroundSession() async {
    if (!_isAndroid) return;
    try {
      await _methodChannel.invokeMethod('stopForegroundSession');
    } catch (_) {}
  }

  Future<void> triggerCompletionAlert({
    required CompletionSound sound,
    required VibrationPattern vibration,
    required String title,
  }) async {
    if (!_isAndroid) {
      if (vibration != VibrationPattern.off) {
        await HapticFeedback.heavyImpact();
      }
      return;
    }
    try {
      await _methodChannel.invokeMethod('triggerCompletionAlert', {
        'sound': sound.key,
        'vibration': vibration.key,
        'title': title,
      });
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }

  Future<void> setDndActive(bool active) async {
    if (!_isAndroid) return;
    try {
      await _methodChannel.invokeMethod('setDndActive', {'active': active});
    } catch (_) {}
  }

  Future<bool> hasDndPermission() async {
    if (!_isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('hasDndPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestDndPermission() async {
    if (!_isAndroid) return;
    try {
      await _methodChannel.invokeMethod('requestDndPermission');
    } catch (_) {}
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!_isAndroid) return true;
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> requestExactAlarmPermission() async {
    if (!_isAndroid) return;
    try {
      await _methodChannel.invokeMethod('requestExactAlarmPermission');
    } catch (_) {}
  }

  Future<void> setAmbientSound(AmbientSoundType sound) async {
    if (!_isAndroid) return;
    try {
      await _methodChannel.invokeMethod('setAmbientSound', {'sound': sound.key});
    } catch (_) {}
  }
}
