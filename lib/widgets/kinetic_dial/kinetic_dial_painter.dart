import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../models/focus_mode.dart';

/// CustomPainter rendering the 3-Layer Mechanical Kinetic Focus Dial
/// styled with Minimal Editorial & Clean Webtoon Panel precision:
/// - Flat contrast with crisp 1px / 1.5px borders (zero blurry drop shadows)
/// - Layer 1 (Back): Rotating mineral-toned under-disk visible through a 10px-radius aperture
/// - Layer 2 (Middle): Flat Soft Parchment / Ink Oak face with architectural minute ticks
/// - Layer 3 (Front): Sharp baton hand with Cinnabar Red live needle tip & ghost marker
class KineticDialPainter extends CustomPainter {
  KineticDialPainter({
    required this.isDark,
    required this.mode,
    required this.phase,
    required this.isIdle,
    required this.isRunning,
    required this.liveHandAngleRad,
    required this.ghostMarkerAngleRad,
    required this.underDiskAngleRad,
    required this.maskSpringOffsetRad,
    required this.hasSurpassedRecord,
    required this.endlessLaps,
    required this.isDraggingRim,
    required this.showRimMinutesHint,
    required this.apertureTitle,
    required this.formattedTime,
    required this.digitsOpacity,
    required this.accentColor,
    required this.completedPomodoroRounds,
    required this.cyclesBeforeLongBreak,
  });

  final bool isDark;
  final FocusMode mode;
  final SessionPhase phase;
  final bool isIdle;
  final bool isRunning;
  final double liveHandAngleRad;
  final double ghostMarkerAngleRad;
  final double underDiskAngleRad;
  final double maskSpringOffsetRad;
  final bool hasSurpassedRecord;
  final int endlessLaps;
  final bool isDraggingRim;
  final bool showRimMinutesHint;
  final String apertureTitle;
  final String formattedTime;
  final double digitsOpacity;
  final Color accentColor;
  final int completedPomodoroRounds;
  final int cyclesBeforeLongBreak;

  List<Color> _currentGradientColors() {
    if (phase.isBreak) {
      return MagnColors.pomodoroBreakGradient;
    }
    switch (mode) {
      case FocusMode.pomodoro:
        return MagnColors.pomodoroFocusGradient;
      case FocusMode.focus:
        return MagnColors.focusSessionGradient;
      case FocusMode.endless:
        return hasSurpassedRecord
            ? MagnColors.endlessRecordGradient
            : MagnColors.endlessFlowGradient;
    }
  }

  /// Geometry helper for the recessed rectangular aperture window (10px rounded corners).
  static RRect buildApertureSlotRect(Offset center, double radius) {
    final slotWidth = radius * 1.14;
    final slotHeight = radius * 0.38;
    final slotCenter = Offset(center.dx, center.dy - radius * 0.36);
    final rect = Rect.fromCenter(
      center: slotCenter,
      width: slotWidth,
      height: slotHeight,
    );
    return RRect.fromRectAndRadius(rect, const Radius.circular(10.0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.455;

    // ── Outer Lap Indicator Ring (Endless Flow >= 60m) ────────────────────────
    if (mode == FocusMode.endless && endlessLaps > 0) {
      final lapRingRadius = radius + 9;
      final trackPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = isDark ? MagnColors.darkDivider : MagnColors.lightDivider;
      canvas.drawCircle(center, lapRingRadius, trackPaint);

      final lapArcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.butt
        ..color = hasSurpassedRecord
            ? MagnColors.cinnabarRed
            : MagnColors.deepMineralPine;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: lapRingRadius),
        -math.pi / 2,
        liveHandAngleRad.clamp(0.05, 2 * math.pi),
        false,
        lapArcPaint,
      );
    }

    // ── LAYER 2 BASE: Flat Architectural Mask Disk (no blurry shadow) ─────────
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(maskSpringOffsetRad);
    canvas.translate(-center.dx, -center.dy);

    _drawFlatDiskBody(canvas, center, radius);
    _drawPrecisionPerimeterTicks(canvas, center, radius);

    // ── LAYER 1 (THROUGH APERTURE): Rotating Gradient Under-Disk ──────────────
    final slotRRect = buildApertureSlotRect(center, radius);
    _drawGradientAperture(canvas, center, radius, slotRRect);

    // ── Contrast-Guarded Text Readout Inside Cutout Slot ──────────────────────
    _drawApertureReadout(canvas, slotRRect);

    canvas.restore();

    // ── Ghost Benchmark Notch on Outer Rim ────────────────────────────────────
    _drawGhostRimNotch(canvas, center, radius);

    // ── LAYER 3: Dual Hand Assembly (Ghost Marker + Sharp Primary Needle) ─────
    _drawGhostHand(canvas, center, radius);
    _drawPrimaryLiveHand(canvas, center, radius);
    _drawCenterPivotCap(canvas, center, radius);
  }

  void _drawFlatDiskBody(Canvas canvas, Offset center, double radius) {
    final surfaceColor =
        isDark ? MagnColors.darkDiskSurface : MagnColors.lightDiskSurface;
    canvas.drawCircle(center, radius, Paint()..color = surfaceColor);

    // Crisp 1px panel border (1.5px Deep Mineral Pine / Cream when active or dragging)
    final isActive = isDraggingRim || isRunning;
    final borderColor = isActive
        ? (isDark
            ? MagnColors.warmSilkCream.withValues(alpha: 0.72)
            : MagnColors.deepMineralPine)
        : (isDark ? MagnColors.darkDiskRim : MagnColors.lightDiskRim);

    final rimStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isActive ? 1.5 : 1.0
      ..color = borderColor;
    canvas.drawCircle(center, radius - 0.75, rimStroke);

    // Subtle inner editorial registration hairline
    final innerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = (isDark ? MagnColors.warmSilkCream : MagnColors.inkOak)
          .withValues(alpha: 0.07);
    canvas.drawCircle(center, radius - 16.0, innerRing);
  }

  void _drawPrecisionPerimeterTicks(
    Canvas canvas,
    Offset center,
    double radius,
  ) {
    final baseAlpha = isDraggingRim ? 0.42 : 0.16;
    final majorAlpha = isDraggingRim ? 0.85 : 0.45;
    final tickColor =
        isDark ? MagnColors.warmSilkCream : MagnColors.inkOak;

    for (var i = 0; i < 60; i++) {
      final isMajor = i % 5 == 0;
      if (!isMajor && !isDraggingRim) continue;

      final angle = (i / 60.0) * 2 * math.pi - math.pi / 2;
      final outerR = radius - 6.0;
      final innerR = outerR - (isMajor ? 8.0 : 4.0);

      final p1 = Offset(
        center.dx + math.cos(angle) * innerR,
        center.dy + math.sin(angle) * innerR,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * outerR,
        center.dy + math.sin(angle) * outerR,
      );

      final isDatum = i == 0;
      final Color lineColor;
      if (isDatum && isRunning) {
        lineColor = MagnColors.cinnabarRed;
      } else if (isDatum) {
        lineColor = isDark
            ? MagnColors.warmSilkCream
            : MagnColors.deepMineralPine;
      } else {
        lineColor =
            tickColor.withValues(alpha: isMajor ? majorAlpha : baseAlpha);
      }

      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = isDatum ? 2.0 : (isMajor ? 1.4 : 1.0)
        ..strokeCap = StrokeCap.square;

      canvas.drawLine(p1, p2, paint);
    }
  }

  void _drawGradientAperture(
    Canvas canvas,
    Offset center,
    double radius,
    RRect slotRRect,
  ) {
    canvas.save();
    canvas.clipRRect(slotRRect);

    // Layer 1: Full-diameter rotating tonal wheel sitting beneath the mask
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(underDiskAngleRad);
    canvas.translate(-center.dx, -center.dy);

    final underDiskRect = Rect.fromCircle(center: center, radius: radius * 1.05);
    final colors = _currentGradientColors();

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: colors,
        stops: const [0.0, 0.26, 0.52, 0.78, 1.0],
      ).createShader(underDiskRect);
    canvas.drawCircle(center, radius * 1.05, sweepPaint);

    canvas.restore();

    // Flat editorial scrim for guaranteed crisp contrast without blur
    canvas.drawRRect(
      slotRRect,
      Paint()..color = MagnColors.deepestInk.withValues(alpha: 0.28),
    );

    canvas.restore();

    // Crisp 1.5px solid editorial frame around cutout aperture
    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = isDark
          ? MagnColors.warmSilkCream.withValues(alpha: 0.28)
          : MagnColors.inkOak.withValues(alpha: 0.40);
    canvas.drawRRect(slotRRect, framePaint);
  }

  void _drawApertureReadout(Canvas canvas, RRect slotRRect) {
    final slotCenter = slotRRect.center;
    final showDigits = digitsOpacity > 0.02;

    // Heading in Plus Jakarta Sans (-0.02em tracking)
    final titleFontSize = showDigits ? 10.5 : 12.0;
    final titleSpan = TextSpan(
      text: apertureTitle,
      style: AppTheme.headingStyle(
        fontSize: titleFontSize,
        fontWeight: FontWeight.w700,
        color: MagnColors.warmSilkCream.withValues(alpha: 0.92),
      ).copyWith(letterSpacing: 1.8),
    );
    final titlePainter = TextPainter(
      text: titleSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: slotRRect.width - 16);

    if (!showDigits) {
      titlePainter.paint(
        canvas,
        Offset(
          slotCenter.dx - titlePainter.width / 2,
          slotCenter.dy - titlePainter.height / 2,
        ),
      );
      return;
    }

    // Numbers & timers in JetBrains Mono with tabular-nums
    final timeSpan = TextSpan(
      text: formattedTime,
      style: AppTheme.monoStyle(
        fontSize: 21.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: MagnColors.warmSilkCream.withValues(
          alpha: digitsOpacity.clamp(0.0, 1.0),
        ),
      ),
    );
    final timePainter = TextPainter(
      text: timeSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: slotRRect.width - 12);

    const gap = 2.0;
    final totalHeight = titlePainter.height + gap + timePainter.height;
    final startY = slotCenter.dy - totalHeight / 2;

    titlePainter.paint(
      canvas,
      Offset(slotCenter.dx - titlePainter.width / 2, startY),
    );
    timePainter.paint(
      canvas,
      Offset(
        slotCenter.dx - timePainter.width / 2,
        startY + titlePainter.height + gap,
      ),
    );
  }

  void _drawGhostRimNotch(Canvas canvas, Offset center, double radius) {
    final angle = ghostMarkerAngleRad - math.pi / 2;
    final notchCenter = Offset(
      center.dx + math.cos(angle) * (radius - 11.5),
      center.dy + math.sin(angle) * (radius - 11.5),
    );
    final notchColor = mode == FocusMode.endless && hasSurpassedRecord
        ? MagnColors.cinnabarRed
        : (isDark
            ? MagnColors.warmSilkCream.withValues(alpha: 0.45)
            : MagnColors.inkOak.withValues(alpha: 0.40));

    canvas.drawRect(
      Rect.fromCenter(center: notchCenter, width: 4.5, height: 4.5),
      Paint()..color = notchColor,
    );
  }

  void _drawGhostHand(Canvas canvas, Offset center, double radius) {
    if (isIdle && mode != FocusMode.endless) return;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(ghostMarkerAngleRad);

    final ghostLength = radius * 0.78;
    final ghostPaint = Paint()
      ..color = (isDark ? MagnColors.warmSilkCream : MagnColors.inkOak)
          .withValues(alpha: isDark ? 0.25 : 0.20)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(Offset.zero, Offset(0, -ghostLength), ghostPaint);
    canvas.restore();
  }

  void _drawPrimaryLiveHand(Canvas canvas, Offset center, double radius) {
    final handLength = radius * 0.80;
    final handWidth = radius * 0.056;
    final tailLength = radius * 0.11;

    final handRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        -handWidth / 2,
        -handLength,
        handWidth / 2,
        tailLength,
      ),
      const Radius.circular(2.0),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(liveHandAngleRad);

    // Sharp flat architectural needle — Deep Mineral Pine in light, Warm Silk Cream in dark
    final handColor =
        isDark ? MagnColors.warmSilkCream : MagnColors.inkOak;
    canvas.drawRRect(handRRect, Paint()..color = handColor);

    // Crisp 1px contrast edge
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isDark
          ? MagnColors.deepestInk.withValues(alpha: 0.5)
          : MagnColors.warmSilkCream.withValues(alpha: 0.25);
    canvas.drawRRect(handRRect, outlinePaint);

    // Cinnabar Red live needle tip strictly while active/running (< 5% area)
    if (isRunning || isDraggingRim) {
      final tipLength = radius * 0.16;
      final tipRRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          -handWidth / 2,
          -handLength,
          handWidth / 2,
          -handLength + tipLength,
        ),
        const Radius.circular(2.0),
      );
      canvas.drawRRect(
        tipRRect,
        Paint()..color = MagnColors.cinnabarRed,
      );
    }

    canvas.restore();
  }

  void _drawCenterPivotCap(Canvas canvas, Offset center, double radius) {
    final capRadius = radius * 0.055;
    final outerColor =
        isDark ? MagnColors.warmSilkCream : MagnColors.deepMineralPine;
    canvas.drawCircle(center, capRadius, Paint()..color = outerColor);

    canvas.drawCircle(
      center,
      capRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = isDark ? MagnColors.deepestInk : MagnColors.inkOak,
    );

    final innerDotColor = isRunning
        ? MagnColors.cinnabarRed
        : (isDark ? MagnColors.deepestInk : MagnColors.warmSilkCream);
    canvas.drawCircle(
      center,
      capRadius * 0.42,
      Paint()..color = innerDotColor,
    );
  }

  @override
  bool shouldRepaint(covariant KineticDialPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.mode != mode ||
        oldDelegate.phase != phase ||
        oldDelegate.isIdle != isIdle ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.liveHandAngleRad != liveHandAngleRad ||
        oldDelegate.ghostMarkerAngleRad != ghostMarkerAngleRad ||
        oldDelegate.underDiskAngleRad != underDiskAngleRad ||
        oldDelegate.maskSpringOffsetRad != maskSpringOffsetRad ||
        oldDelegate.hasSurpassedRecord != hasSurpassedRecord ||
        oldDelegate.endlessLaps != endlessLaps ||
        oldDelegate.isDraggingRim != isDraggingRim ||
        oldDelegate.apertureTitle != apertureTitle ||
        oldDelegate.formattedTime != formattedTime ||
        oldDelegate.digitsOpacity != digitsOpacity ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.completedPomodoroRounds != completedPomodoroRounds ||
        oldDelegate.cyclesBeforeLongBreak != cyclesBeforeLongBreak;
  }
}
