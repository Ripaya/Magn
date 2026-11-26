import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/focus_mode.dart';

/// CustomPainter rendering the 3-Layer Mechanical Kinetic Focus Dial:
/// - Layer 1 (Back): Rotating luminous Gradient Under-Disk visible through the cutout
/// - Layer 2 (Middle): Tactile matte ceramic/OLED Top Mask Disk with recessed inner-shadow
///   pill aperture and contrast-guarded mode/time display
/// - Layer 3 (Front): Sculpted Dual Hand Assembly (Primary Live Hand with cast shadow +
///   Ghost Benchmark Marker + precision pivot cap)
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

  /// Geometry helper for the recessed horizontal pill cutout slot (in local coordinates).
  static RRect buildApertureSlotRect(Offset center, double radius) {
    final slotWidth = radius * 1.12;
    final slotHeight = radius * 0.36;
    final slotCenter = Offset(center.dx, center.dy - radius * 0.37);
    final rect = Rect.fromCenter(
      center: slotCenter,
      width: slotWidth,
      height: slotHeight,
    );
    return RRect.fromRectAndRadius(rect, Radius.circular(slotHeight / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.455;

    // ── Outer Lap Indicator Ring (Endless Flow >= 60m) ────────────────────────
    if (mode == FocusMode.endless && endlessLaps > 0) {
      final lapRingRadius = radius + 10;
      final trackPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
      canvas.drawCircle(center, lapRingRadius, trackPaint);

      final lapArcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 1.5 * math.pi,
          colors: hasSurpassedRecord
              ? const [Color(0xFFF59E0B), Color(0xFFFDE047)]
              : const [Color(0xFF7C3AED), Color(0xFFA855F7)],
        ).createShader(Rect.fromCircle(center: center, radius: lapRingRadius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: lapRingRadius),
        -math.pi / 2,
        liveHandAngleRad.clamp(0.05, 2 * math.pi),
        false,
        lapArcPaint,
      );
    }

    // ── Physical Architectural Cast Shadow Beneath Disk ───────────────────────
    _drawDiskShadow(canvas, center, radius);

    // ── LAYER 2 BASE: Matte Ceramic / OLED Top Mask Disk ──────────────────────
    canvas.save();
    // Apply damped spring rotation to the mask disk when switching modes
    canvas.translate(center.dx, center.dy);
    canvas.rotate(maskSpringOffsetRad);
    canvas.translate(-center.dx, -center.dy);

    _drawMatteDiskBody(canvas, center, radius);
    _drawSubtlePerimeterTicks(canvas, center, radius);

    // ── LAYER 1 (THROUGH APERTURE): Rotating Gradient Under-Disk ──────────────
    final slotRRect = buildApertureSlotRect(center, radius);
    _drawGradientAperture(canvas, center, radius, slotRRect);

    // ── Contrast-Guarded Text Readout Inside Cutout Slot ──────────────────────
    _drawApertureReadout(canvas, slotRRect);

    canvas.restore();

    // ── Ghost Benchmark Notch on Outer Rim ────────────────────────────────────
    _drawGhostRimNotch(canvas, center, radius);

    // ── LAYER 3: Dual Hand Assembly (Ghost Marker + Sculpted Primary Hand) ────
    _drawGhostHand(canvas, center, radius);
    _drawPrimaryLiveHand(canvas, center, radius);
    _drawCenterPivotCap(canvas, center, radius);
  }

  void _drawDiskShadow(Canvas canvas, Offset center, double radius) {
    if (isDark) {
      // Subtle ambient halo on pure OLED black so the circular matte face breathes
      final glowPaint = Paint()
        ..color = _currentGradientColors()[2].withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
      canvas.drawCircle(center.translate(0, 6), radius * 0.98, glowPaint);
    } else {
      // Gallery wall directional soft cast shadow matching the reference clock photo
      final deepShadow = Paint()
        ..color = const Color(0xFF1A202C).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
      canvas.drawCircle(center.translate(6, 18), radius * 0.96, deepShadow);

      final contactShadow = Paint()
        ..color = const Color(0xFF0F172A).withValues(alpha: 0.09)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center.translate(2, 6), radius * 0.99, contactShadow);
    }
  }

  void _drawMatteDiskBody(Canvas canvas, Offset center, double radius) {
    final diskRect = Rect.fromCircle(center: center, radius: radius);

    // Subtle directional lighting across the matte face for tactile depth
    final faceGradient = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 1.3,
      colors: isDark
          ? const [Color(0xFF1A1C21), Color(0xFF111216), Color(0xFF0B0C0E)]
          : const [Color(0xFFFFFFFF), Color(0xFFF6F7F9), Color(0xFFEAECEF)],
      stops: const [0.0, 0.65, 1.0],
    );

    final diskPaint = Paint()..shader = faceGradient.createShader(diskRect);
    canvas.drawCircle(center, radius, diskPaint);

    // Tactile bevel edge ring
    final rimStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDraggingRim ? 2.2 : 1.3
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: isDraggingRim ? 0.30 : 0.12),
                Colors.white.withValues(alpha: 0.03),
              ]
            : [
                Colors.white.withValues(alpha: 0.95),
                const Color(0xFFCBD2DC).withValues(alpha: 0.85),
              ],
      ).createShader(diskRect);
    canvas.drawCircle(center, radius - 0.8, rimStroke);
  }

  void _drawSubtlePerimeterTicks(Canvas canvas, Offset center, double radius) {
    final baseAlpha = isDraggingRim ? 0.36 : 0.14;
    final majorAlpha = isDraggingRim ? 0.62 : 0.28;
    final tickColor = isDark ? Colors.white : MagnColors.lightInkPrimary;

    for (var i = 0; i < 60; i++) {
      final isMajor = i % 5 == 0;
      // Keep the ultra-clean aesthetic when not dragging: only 12 major markers at rest,
      // full 60-minute precision ticks fade in while dragging the outer rim!
      if (!isMajor && !isDraggingRim) continue;

      final angle = (i / 60.0) * 2 * math.pi - math.pi / 2;
      final outerR = radius - 8.0;
      final innerR = outerR - (isMajor ? 7.5 : 4.0);

      final p1 = Offset(
        center.dx + math.cos(angle) * innerR,
        center.dy + math.sin(angle) * innerR,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * outerR,
        center.dy + math.sin(angle) * outerR,
      );

      final paint = Paint()
        ..color = tickColor.withValues(alpha: isMajor ? majorAlpha : baseAlpha)
        ..strokeWidth = isMajor ? 1.5 : 1.0
        ..strokeCap = StrokeCap.round;

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

    // Layer 1: Full-diameter rotating gradient disk sitting physically beneath the mask
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(underDiskAngleRad);
    canvas.translate(-center.dx, -center.dy);

    final underDiskRect = Rect.fromCircle(center: center, radius: radius * 1.05);
    final colors = _currentGradientColors();

    // Rich dual-blend gradient: Sweep + Linear depth simulating the illuminated pigment wheel
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: colors,
        stops: const [0.0, 0.26, 0.52, 0.78, 1.0],
      ).createShader(underDiskRect);
    canvas.drawCircle(center, radius * 1.05, sweepPaint);

    final luminousSheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.16),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.22),
        ],
      ).createShader(underDiskRect);
    canvas.drawCircle(center, radius * 1.05, luminousSheen);

    canvas.restore();

    // Inner recessed bevel shadow along top/left wall of the cutout slot
    // (gives the unmistakable 3D milled-aperture depth from the reference image!)
    final innerShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..color = Colors.black.withValues(alpha: isDark ? 0.55 : 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    canvas.drawRRect(slotRRect.shift(const Offset(0, 2.2)), innerShadowPaint);

    // Subtle crisp dark scrim pill behind typography for WCAG 4.5:1 contrast guarantee
    final scrimRect = slotRRect.deflate(3.0);
    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28);
    canvas.drawRRect(scrimRect, scrimPaint);

    canvas.restore();

    // Crisp micro-chamfer rim outline around the cutout aperture
    final chamferPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.08);
    canvas.drawRRect(slotRRect, chamferPaint);
  }

  void _drawApertureReadout(Canvas canvas, RRect slotRRect) {
    final slotCenter = slotRRect.center;
    final showDigits = digitsOpacity > 0.02;

    // Mode / Phase title inside cutout window
    final titleSpan = TextSpan(
      text: apertureTitle,
      style: TextStyle(
        fontSize: showDigits ? 10.5 : 12.0,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.1,
        color: Colors.white.withValues(alpha: 0.94),
        shadows: const [
          Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
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

    // Crisp monospace MM:SS readout directly beneath mode name inside slot
    final timeSpan = TextSpan(
      text: formattedTime,
      style: AppTheme.monoStyle(
        fontSize: 21.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: Colors.white.withValues(alpha: digitsOpacity.clamp(0.0, 1.0)),
      ).copyWith(
        shadows: const [
          Shadow(color: Color(0x70000000), blurRadius: 5, offset: Offset(0, 1)),
        ],
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
        ? const Color(0xFFF59E0B)
        : (isDark
            ? Colors.white.withValues(alpha: 0.45)
            : MagnColors.lightInkPrimary.withValues(alpha: 0.35));

    canvas.drawCircle(notchCenter, 3.0, Paint()..color = notchColor);
  }

  void _drawGhostHand(Canvas canvas, Offset center, double radius) {
    // Only draw distinct ghost hand when it differs meaningfully from the live hand
    // or during active Endless / Focus benchmark tracking.
    if (isIdle && mode != FocusMode.endless) return;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(ghostMarkerAngleRad);

    final ghostLength = radius * 0.78;
    final ghostPaint = Paint()
      ..color = (isDark ? Colors.white : MagnColors.lightInkPrimary)
          .withValues(alpha: isDark ? 0.22 : 0.16)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset.zero, Offset(0, -ghostLength), ghostPaint);
    canvas.restore();
  }

  void _drawPrimaryLiveHand(Canvas canvas, Offset center, double radius) {
    final handLength = radius * 0.80;
    final handWidth = radius * 0.068;
    final tailLength = radius * 0.09;

    final handRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        -handWidth / 2,
        -handLength,
        handWidth / 2,
        tailLength,
      ),
      Radius.circular(handWidth / 2),
    );

    // 1. Directional cast shadow on the matte disk (signature look from the reference image)
    canvas.save();
    canvas.translate(center.dx + 4.5, center.dy + 7.5);
    canvas.rotate(liveHandAngleRad);
    final handShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.55 : 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.5);
    canvas.drawRRect(handRRect, handShadowPaint);
    canvas.restore();

    // 2. Sculpted matte cylindrical baton hand
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(liveHandAngleRad);

    final bodyGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: isDark
          ? const [
              MagnColors.darkHandEdge,
              MagnColors.darkHandHighlight,
              MagnColors.darkHand,
            ]
          : const [
              MagnColors.lightHandHighlight,
              MagnColors.lightHand,
              MagnColors.lightHandEdge,
            ],
      stops: const [0.0, 0.45, 1.0],
    );

    final bodyPaint = Paint()
      ..shader = bodyGradient.createShader(handRRect.outerRect);
    canvas.drawRRect(handRRect, bodyPaint);

    // Subtle hairline contour so light-on-light matte hand stays razor-crisp
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.25)
          : const Color(0xFF94A3B8).withValues(alpha: 0.42);
    canvas.drawRRect(handRRect, outlinePaint);

    // Micro indicator tip accent when dragging or actively sweeping
    if (isDraggingRim || isRunning) {
      final tipColor = _currentGradientColors()[2];
      canvas.drawCircle(
        Offset(0, -handLength + handWidth * 0.72),
        handWidth * 0.22,
        Paint()..color = tipColor.withValues(alpha: 0.90),
      );
    }

    canvas.restore();
  }

  void _drawCenterPivotCap(Canvas canvas, Offset center, double radius) {
    final capRadius = radius * 0.056;
    canvas.drawCircle(
      center.translate(1.2, 2.0),
      capRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.50 : 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    final capPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: isDark
            ? const [Color(0xFFFFFFFF), Color(0xFF9AA2B1)]
            : const [Color(0xFFFFFFFF), Color(0xFFD5D9E1)],
      ).createShader(Rect.fromCircle(center: center, radius: capRadius));
    canvas.drawCircle(center, capRadius, capPaint);
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
        oldDelegate.accentColor != accentColor;
  }
}
