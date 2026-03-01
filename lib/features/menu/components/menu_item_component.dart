import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

/// Premium menu item with sci-fi aesthetic:
/// — Adaptive sizing based on screen dimensions
/// — Glowing highlight underline when selected
/// — Animated scan-line effect on selection
/// — Gradient text with neon glow
/// — Smooth spring-like animations
class MenuItemComponent extends PositionComponent with TapCallbacks {
  MenuItemComponent({
    required this.label,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onSelected,
    required this.screenSize,
    super.position,
  });

  final String label;
  final int index;
  bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSelected;
  final Vector2 screenSize;

  // Animation state
  double _glowIntensity = 0;
  double _lineExtension = 0;
  double _scanOffset = 0; // Scan-line horizontal sweep
  double _hoverScale = 1.0;
  double _age = 0;

  // --- Colors ---
  static const _neonWhite = Color(0xFFFFFFFF);
  static const _neonCyanGlow = Color(
    0xFF4DD0E1,
  ); // Bright cyan for extra contrast on selection
  static const _unselectedColor = Color(
    0xFF808E95,
  ); // Darker blue-grey to differentiate from active white

  // --- Adaptive sizing ---
  late double _fontSize;
  late double _letterSpacing;
  late double _lineMaxWidth;
  late double _itemHeight;
  late double _itemWidth;
  late double _underlineWidth;

  late TextPainter _textPainter;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Adaptive sizing based on screen width
    final sw = screenSize.x;
    _fontSize = (sw * 0.05).clamp(20.0, 36.0); // Made significantly larger
    _letterSpacing = (sw * 0.008).clamp(2.0, 4.0);
    _lineMaxWidth = (sw * 0.18).clamp(30.0, 90.0);
    _itemHeight = (screenSize.y * 0.05).clamp(28.0, 44.0);
    _itemWidth = (sw * 0.75).clamp(240.0, 420.0);
    _underlineWidth = (sw * 0.28).clamp(60.0, 160.0);

    size = Vector2(_itemWidth, _itemHeight);
    anchor = Anchor.center;
    _buildTextPainter();
  }

  void _buildTextPainter() {
    final color = isSelected ? _neonWhite : _unselectedColor;
    final style = TextStyle(
      fontFamily: 'Roboto',
      fontSize: _fontSize,
      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
      letterSpacing: _letterSpacing,
      color: color,
    );

    _textPainter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void updateSelection(bool selected) {
    if (isSelected != selected) {
      isSelected = selected;
      _buildTextPainter();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;

    // Smooth glow animation (spring-like)
    final targetGlow = isSelected ? 1.0 : 0.0;
    _glowIntensity += (targetGlow - _glowIntensity) * dt * 8;
    _glowIntensity = _glowIntensity.clamp(0.0, 1.0);

    // Smooth line extension
    final targetLine = isSelected ? 1.0 : 0.0;
    _lineExtension += (targetLine - _lineExtension) * dt * 6;
    _lineExtension = _lineExtension.clamp(0.0, 1.0);

    // Scale effect (subtle)
    final targetScale = isSelected ? 1.02 : 1.0;
    _hoverScale += (targetScale - _hoverScale) * dt * 10;

    // Scan-line sweep (only when selected)
    if (isSelected) {
      _scanOffset += dt * 1.5;
      if (_scanOffset > 2.0) _scanOffset -= 2.0;
    } else {
      _scanOffset = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final centerX = size.x / 2;
    final centerY = size.y / 2;

    canvas.save();
    // Apply subtle scale from center
    canvas.translate(centerX, centerY);
    canvas.scale(_hoverScale, _hoverScale);
    canvas.translate(-centerX, -centerY);

    // --- 1. Glow background pill (selected only) ---
    if (_glowIntensity > 0.01) {
      final glowRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: _textPainter.width + 40,
          height: _itemHeight * 0.75,
        ),
        const Radius.circular(6),
      );

      // Outer soft glow
      final outerGlow = Paint()
        ..color = _neonWhite.withValues(alpha: _glowIntensity * 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawRRect(glowRect, outerGlow);

      // Inner subtle cyan-ish fill for selection
      final innerFill = Paint()
        ..color = _neonCyanGlow.withValues(alpha: _glowIntensity * 0.15);
      canvas.drawRRect(glowRect, innerFill);

      // Border glow line
      final borderPaint = Paint()
        ..color = _neonWhite.withValues(alpha: _glowIntensity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(glowRect, borderPaint);
    }

    // --- 2. Scan-line sweep effect (selected only) ---
    if (_glowIntensity > 0.3) {
      final scanX =
          centerX - _textPainter.width / 2 + (_textPainter.width * _scanOffset);
      if (_scanOffset < 1.0) {
        final scanPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              _neonCyanGlow.withValues(alpha: 0.0),
              _neonWhite.withValues(alpha: _glowIntensity * 0.35),
              _neonCyanGlow.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromLTWH(scanX - 20, 0, 40, size.y));
        canvas.drawRect(
          Rect.fromLTWH(
            scanX - 20,
            centerY - _itemHeight * 0.35,
            40,
            _itemHeight * 0.7,
          ),
          scanPaint,
        );
      }
    }

    // --- 3. Underline bar (selected) ---
    if (_lineExtension > 0.01) {
      final underlineY = centerY + _textPainter.height / 2 + 6;
      final halfWidth = _underlineWidth * _lineExtension / 2;

      // Gradient underline
      final underlinePaint = Paint()
        ..strokeWidth = 2.0
        ..shader =
            LinearGradient(
              colors: [
                _neonWhite.withValues(alpha: 0.0),
                _neonWhite.withValues(alpha: _glowIntensity * 0.9),
                _neonWhite.withValues(alpha: _glowIntensity * 0.9),
                _neonWhite.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.2, 0.8, 1.0],
            ).createShader(
              Rect.fromLTRB(
                centerX - halfWidth,
                underlineY,
                centerX + halfWidth,
                underlineY,
              ),
            );
      canvas.drawLine(
        Offset(centerX - halfWidth, underlineY),
        Offset(centerX + halfWidth, underlineY),
        underlinePaint,
      );

      // Soft glow under the line
      final glowLine = Paint()
        ..color = _neonWhite.withValues(alpha: _glowIntensity * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawLine(
        Offset(centerX - halfWidth * 0.6, underlineY),
        Offset(centerX + halfWidth * 0.6, underlineY),
        glowLine..strokeWidth = 4.0,
      );
    }

    // --- 4. Decorative side dashes (selected) ---
    if (_lineExtension > 0.3) {
      final dashAlpha = ((_lineExtension - 0.3) / 0.7).clamp(0.0, 1.0);
      final dashPaint = Paint()
        ..color = _neonWhite.withValues(alpha: dashAlpha * 0.4)
        ..strokeWidth = 1.0;

      final textHalfW = _textPainter.width / 2;
      final gap = 16.0;

      // Right dash →
      final rStart = centerX + textHalfW + gap;
      final rEnd = rStart + _lineMaxWidth * _lineExtension;
      final rShader = LinearGradient(
        colors: [
          _neonWhite.withValues(alpha: dashAlpha * 0.5),
          _neonWhite.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(rStart, centerY, rEnd, centerY));
      dashPaint.shader = rShader;
      canvas.drawLine(
        Offset(rStart, centerY),
        Offset(rEnd, centerY),
        dashPaint,
      );

      // Arrow tip →
      if (_lineExtension > 0.6) {
        final arrowA = ((_lineExtension - 0.6) * 2.5).clamp(0.0, 1.0);
        final ap = Paint()
          ..color = _neonWhite.withValues(alpha: arrowA * 0.5)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(rEnd - 6, centerY - 4),
          Offset(rEnd, centerY),
          ap,
        );
        canvas.drawLine(
          Offset(rEnd - 6, centerY + 4),
          Offset(rEnd, centerY),
          ap,
        );
      }

      // Left dash ←
      final lStart = centerX - textHalfW - gap;
      final lEnd = lStart - _lineMaxWidth * _lineExtension;
      final lShader = LinearGradient(
        colors: [
          _neonWhite.withValues(alpha: dashAlpha * 0.5),
          _neonWhite.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(lStart, centerY, lEnd, centerY));
      dashPaint.shader = lShader;
      canvas.drawLine(
        Offset(lStart, centerY),
        Offset(lEnd, centerY),
        dashPaint,
      );
    }

    // --- 5. Text (with subtle breathing animation for unselected) ---
    final textX = centerX - _textPainter.width / 2;
    final textY = centerY - _textPainter.height / 2;

    _textPainter.paint(canvas, Offset(textX, textY));

    // --- 6. Neon text glow (selected) ---
    if (_glowIntensity > 0.01) {
      final glowStyle = TextStyle(
        fontFamily: 'Roboto',
        fontSize: _fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: _letterSpacing,
        color: _neonWhite.withValues(alpha: _glowIntensity * 0.5),
      );
      final glowPainter = TextPainter(
        text: TextSpan(text: label, style: glowStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      // Layer 1: Wide soft glow
      canvas.saveLayer(
        null,
        Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      glowPainter.paint(canvas, Offset(textX, textY));
      canvas.restore();

      // Layer 2: Tight sharp glow
      canvas.saveLayer(
        null,
        Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      glowPainter.paint(canvas, Offset(textX, textY));
      canvas.restore();
    }

    // --- 7. Index indicator dot (unselected items get a subtle dot) ---
    if (!isSelected) {
      final dotPulse = (sin(_age * 1.5 + index * 0.8) * 0.3 + 0.7).clamp(
        0.0,
        1.0,
      );
      final dotPaint = Paint()
        ..color = _unselectedColor.withValues(alpha: 0.25 * dotPulse);
      canvas.drawCircle(
        Offset(centerX - _textPainter.width / 2 - 12, centerY),
        2.0,
        dotPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    // Expand touch target for mobile
    final expandX = size.x * 0.1;
    final expandY = size.y * 0.3;
    return point.x >= -expandX &&
        point.x <= size.x + expandX &&
        point.y >= -expandY &&
        point.y <= size.y + expandY;
  }

  @override
  void onTapDown(TapDownEvent event) {
    onSelected();
    onTap();
  }
}
