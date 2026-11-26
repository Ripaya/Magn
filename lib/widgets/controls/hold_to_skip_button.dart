import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';

/// Right-side dock button requiring a 0.8-second press-and-hold with a circular
/// progress fill ring around the perimeter to prevent accidental session resets.
class HoldToSkipButton extends StatefulWidget {
  const HoldToSkipButton({
    super.key,
    required this.enabled,
    required this.icon,
    required this.tooltip,
    required this.onCompleted,
  });

  final bool enabled;
  final IconData icon;
  final String tooltip;
  final VoidCallback onCompleted;

  @override
  State<HoldToSkipButton> createState() => _HoldToSkipButtonState();
}

class _HoldToSkipButtonState extends State<HoldToSkipButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AppConstants.holdToSkipDurationMs),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_triggered) {
          _triggered = true;
          HapticFeedback.heavyImpact();
          widget.onCompleted();
          _holdController.reset();
        }
      });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    _triggered = false;
    HapticFeedback.lightImpact();
    _holdController.forward(from: 0.0);
  }

  void _cancelHold() {
    if (_holdController.isAnimating) {
      _holdController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark
        ? const Color(0xFF17191E)
        : Colors.white.withValues(alpha: 0.86);
    final iconColor = widget.enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.28);

    return Tooltip(
      message: widget.enabled ? '${widget.tooltip} (Hold 0.8s)' : widget.tooltip,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: AnimatedBuilder(
          animation: _holdController,
          builder: (context, child) {
            final scale = 1.0 - (_holdController.value * 0.06);
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 58,
                height: 58,
                child: CustomPaint(
                  painter: _HoldRingPainter(
                    progress: _holdController.value,
                    ringColor: theme.colorScheme.onSurface,
                    trackColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.09),
                  ),
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: surfaceColor,
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
                      child: Icon(widget.icon, size: 22, color: iconColor),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HoldRingPainter extends CustomPainter {
  const _HoldRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2.0;

    if (progress <= 0.001) return;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = trackColor,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..color = ringColor,
    );
  }

  @override
  bool shouldRepaint(covariant _HoldRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ringColor != ringColor;
}
