import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/focus_mode.dart';
import '../../providers/app_providers.dart';
import 'hold_to_skip_button.dart';

/// Minimalist 3-action Bottom Control Dock:
/// - Left: Options button
/// - Center: Large primary Play / Pause morphing pill/circle button
/// - Right: 0.8s Hold-to-Skip / Stop button
class ControlDock extends ConsumerStatefulWidget {
  const ControlDock({
    super.key,
    required this.onOpenOptions,
  });

  final VoidCallback onOpenOptions;

  @override
  ConsumerState<ControlDock> createState() => _ControlDockState();
}

class _ControlDockState extends ConsumerState<ControlDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playPauseIconController;

  @override
  void initState() {
    super.initState();
    _playPauseIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: ref.read(timerEngineProvider).isRunning ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _playPauseIconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerEngineProvider);
    final strictMode = ref.watch(settingsProvider.select((s) => s.strictMode));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen<bool>(
      timerEngineProvider.select((s) => s.isRunning),
      (prev, isRunning) {
        if (isRunning) {
          _playPauseIconController.forward();
        } else {
          _playPauseIconController.reverse();
        }
      },
    );

    final pauseLocked =
        strictMode && timerState.isRunning && !timerState.phase.isBreak;
    final skipIcon = timerState.mode == FocusMode.pomodoro
        ? Icons.skip_next_rounded
        : Icons.stop_rounded;
    final skipTooltip = timerState.mode == FocusMode.pomodoro
        ? 'Skip Phase'
        : 'End Session';

    final secondarySurface = isDark
        ? const Color(0xFF17191E)
        : Colors.white.withValues(alpha: 0.86);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left — Options Button
          Tooltip(
            message: 'Options & Presets',
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onOpenOptions();
              },
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: secondarySurface,
                  shape: BoxShape.circle,
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 21,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),

          // Center — Primary Play / Pause Morphing Action
          GestureDetector(
            onTap: () {
              if (pauseLocked) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Strict Mode active · Hold stop to abort'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                return;
              }
              HapticFeedback.mediumImpact();
              ref.read(timerEngineProvider.notifier).togglePlayPause();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: timerState.isRunning ? 84 : 112,
              height: 62,
              decoration: BoxDecoration(
                color: pauseLocked
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                    : theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: pauseLocked
                    ? Icon(
                        Icons.lock_rounded,
                        size: 24,
                        color: theme.colorScheme.onPrimary,
                      )
                    : AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _playPauseIconController,
                        size: 30,
                        color: theme.colorScheme.onPrimary,
                      ),
              ),
            ),
          ),

          // Right — Hold-to-Skip / Stop Button (0.8s circular fill)
          HoldToSkipButton(
            enabled: timerState.isActive,
            icon: skipIcon,
            tooltip: skipTooltip,
            onCompleted: () {
              ref.read(timerEngineProvider.notifier).skipOrStop();
            },
          ),
        ],
      ),
    );
  }
}
