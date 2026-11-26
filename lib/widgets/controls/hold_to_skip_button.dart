import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Right-side modular panel button requiring a 0.8-second press-and-hold with a
/// Cinnabar Red rectangular perimeter progress stroke to prevent accidental resets.
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
    final iconColor = widget.enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.30);

    return Tooltip(
      message: widget.enabled ? '${widget.tooltip} (Hold 0.8s)' : widget.tooltip,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: AnimatedBuilder(
          animation: _holdController,
          builder: (context, child) {
            final scale = 1.0 - (_holdController.value * 0.04);
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 56,
                height: 56,
                child: CustomPaint(
                  painter: _HoldPanelRingPainter(
                    progress: _holdController.value,
                    ringColor: MagnColors.cinnabarRed,
                    trackColor: MagnColors.borderColor(context),
                  ),
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: AppTheme.panelDecoration(
                        context,
                        radius: AppTheme.panelRadius,
                        borderColor: _holdController.value > 0.01
                            ? MagnColors.cinnabarRed.withValues(alpha: 0.65)
                            : null,
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

class _HoldPanelRingPainter extends CustomPainter {
  const _HoldPanelRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      const Radius.circular(11),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = trackColor,
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      final extract = metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0));
      canvas.drawPath(
        extract,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.square
          ..color = ringColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HoldPanelRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ringColor != ringColor;
}
