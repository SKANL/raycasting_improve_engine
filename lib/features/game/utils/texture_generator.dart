import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class TextureGenerator {
  static const int tileSize = 32;
  static const int atlasSize = 128; // 4x4 tiles grid

  /// Generates a basic texture atlas with procedural patterns.
  /// Slot 0: Debug Grid
  /// Slot 1: Bricks
  /// Slot 2: Stone
  /// Slot 3: Wood
  static Future<ui.Image> generateAtlas() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint();

    // Fill background
    paint.color = const ui.Color(0xFF000000);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, atlasSize.toDouble(), atlasSize.toDouble()),
      paint,
    );

    // 0. Stone (0, 0) - Simple Noise
    _drawStone(canvas, 0, 0);

    // 1. Bricks (1, 0)
    _drawBricks(canvas, 1, 0);

    // 2. Wood (2, 0)
    _drawWood(canvas, 2, 0);

    // 3. Metal (3, 0)
    _drawMetal(canvas, 3, 0);

    final picture = recorder.endRecording();
    return picture.toImage(atlasSize, atlasSize);
  }

  static void _drawStone(ui.Canvas canvas, int tileX, int tileY) {
    final random = math.Random(1337);
    final offsetX = (tileX * tileSize).toDouble();
    final offsetY = (tileY * tileSize).toDouble();
    final paint = ui.Paint();

    for (var y = 0; y < tileSize; y++) {
      for (var x = 0; x < tileSize; x++) {
        final gray = random.nextInt(50) + 100;
        paint.color = ui.Color.fromARGB(255, gray, gray, gray);
        canvas.drawRect(
          ui.Rect.fromLTWH(offsetX + x, offsetY + y, 1, 1),
          paint,
        );
      }
    }
  }

  static void _drawBricks(ui.Canvas canvas, int tileX, int tileY) {
    final offsetX = (tileX * tileSize).toDouble();
    final offsetY = (tileY * tileSize).toDouble();
    final paint = ui.Paint()..color = const ui.Color(0xFF8B4513);
    final mortarPaint = ui.Paint()..color = const ui.Color(0xFFD3D3D3);

    // Mortar background
    canvas.drawRect(
      ui.Rect.fromLTWH(
        offsetX,
        offsetY,
        tileSize.toDouble(),
        tileSize.toDouble(),
      ),
      mortarPaint,
    );

    const brickH = 8.0;
    const brickW = 14.0;

    for (var row = 0; row < 4; row++) {
      final y = row * brickH;
      final rowOffset = row.isEven ? 0.0 : -7.0;

      for (var col = 0; col < 3; col++) {
        final x = col * (brickW + 2) + rowOffset;
        final drawX = offsetX + x + 1;
        final drawY = offsetY + y + 1;
        const drawW = brickW;
        const drawH = brickH - 2;

        canvas.drawRect(
          ui.Rect.fromLTWH(drawX, drawY, drawW, drawH),
          paint,
        );
      }
    }
  }

  static void _drawWood(ui.Canvas canvas, int tileX, int tileY) {
    final offsetX = (tileX * tileSize).toDouble();
    final offsetY = (tileY * tileSize).toDouble();
    final paint = ui.Paint()..color = const ui.Color(0xFFDEB887);

    canvas.drawRect(
      ui.Rect.fromLTWH(
        offsetX,
        offsetY,
        tileSize.toDouble(),
        tileSize.toDouble(),
      ),
      paint,
    );

    final linePaint = ui.Paint()
      ..color = const ui.Color(0xFF8B4513)
      ..strokeWidth = 1.0;

    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        ui.Offset(offsetX + i * 8, offsetY),
        ui.Offset(offsetX + i * 8, offsetY + tileSize),
        linePaint,
      );
    }
  }

  static void _drawMetal(ui.Canvas canvas, int tileX, int tileY) {
    final offsetX = (tileX * tileSize).toDouble();
    final offsetY = (tileY * tileSize).toDouble();

    // Base
    canvas.drawRect(
      ui.Rect.fromLTWH(
        offsetX,
        offsetY,
        tileSize.toDouble(),
        tileSize.toDouble(),
      ),
      ui.Paint()..color = const ui.Color(0xFF708090),
    );

    // Border
    final borderPaint = ui.Paint()
      ..color = const ui.Color(0xFF2F4F4F)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(
      ui.Rect.fromLTWH(
        offsetX + 1,
        offsetY + 1,
        tileSize - 2.0,
        tileSize - 2.0,
      ),
      borderPaint,
    );

    // Rivets
    final rivetPaint = ui.Paint()..color = const ui.Color(0xFFC0C0C0);
    const radius = 1.5;
    canvas.drawCircle(ui.Offset(offsetX + 4, offsetY + 4), radius, rivetPaint);
    canvas.drawCircle(
      ui.Offset(offsetX + tileSize - 4, offsetY + 4),
      radius,
      rivetPaint,
    );
    canvas.drawCircle(
      ui.Offset(offsetX + 4, offsetY + tileSize - 4),
      radius,
      rivetPaint,
    );
    canvas.drawCircle(
      ui.Offset(offsetX + tileSize - 4, offsetY + tileSize - 4),
      radius,
      rivetPaint,
    );
  }

  /// Generates a separate atlas for entities (Enemies, Items).
  /// 32x32 Tiles.
  /// Slot 0: Enemy (Red Blob)
  /// Slot 1: Key (Yellow)
  /// Generates a separate atlas for entities (Enemies, Items).
  /// 128x128 Atlas (4x4 grid of 32x32 tiles).
  /// Row 0: Idle (2 frames)
  /// Row 1: Walk (2 frames)
  /// Row 2: Attack (2 frames)
  /// Row 3: Pain/Die (2 frames)
  static Future<ui.Image> generateSpriteAtlas() async {
    const size = 128; // Increased from 64 to support more frames
    final buffer = Uint8List(size * size * 4);

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final index = (y * size + x) * 4;
        final slotX = x ~/ 32;
        final slotY = y ~/ 32; // 0=Idle, 1=Walk, 2=Attack, 3=Pain
        final lx = x % 32; // Local X
        final ly = y % 32; // Local Y

        var r = 0;
        var g = 0;
        var b = 0;
        var a = 0;

        // Base Enemy Shape (Circle-ish)
        const cx = 16.0;
        const cy = 16.0;
        final dx = cx - lx;
        final dy = cy - ly;
        final distSq = dx * dx + dy * dy;

        // --- ROW 0: IDLE ---
        if (slotY == 0) {
          if ((slotX == 0 || slotX == 1) && distSq < 12 * 12) {
            r = 150;
            g = 20;
            b = 20;
            a = 255; // Dark Red Body
            // Eyes (Blinking in frame 1)
            if (slotX == 0 || (slotX == 1 && ly > 12)) {
              if (lx > 10 && lx < 14 && ly > 10 && ly < 14) {
                r = 255;
                g = 255;
                b = 0;
              }
              if (lx > 18 && lx < 22 && ly > 10 && ly < 14) {
                r = 255;
                g = 255;
                b = 0;
              }
            }
          } else if (slotX == 2) {
            // Normal Projectile (Plasma Ball - Cyan/White)
            // Distinct core to separate from enemies
            final dist = math.sqrt(distSq);
            if (dist < 14) {
              // Glow
              final intensity = (1.0 - dist / 14.0);
              r = 0;
              g = (255 * intensity).toInt().clamp(0, 255);
              b = 255;
              a = (255 * intensity).toInt().clamp(0, 255);

              // Bright Core
              if (dist < 8) {
                r = 200;
                g = 255;
                b = 255;
                a = 255;
              }
            }
          } else if (slotX == 3) {
            // Bouncing Projectile (BFG - Green/White)
            final dist = math.sqrt(distSq);
            if (dist < 14) {
              final intensity = (1.0 - dist / 14.0);
              r = (50 * intensity).toInt().clamp(0, 255);
              g = 255;
              b = (50 * intensity).toInt().clamp(0, 255);
              a = (255 * intensity).toInt().clamp(0, 255);

              // Bright Core
              if (dist < 8) {
                r = 200;
                g = 255;
                b = 200;
                a = 255;
              }
            }
          }
        }
        // --- ROW 1: WALK ---
        else if (slotY == 1) {
          if (slotX == 3) {
            // Muzzle Flash (Slot 3) - Bright Explosion
            if (distSq < 14 * 14) {
              // Random spikes logic or just simple gradient
              final dist = math.sqrt(distSq);
              if (dist < 10) {
                r = 255;
                g = 255;
                b = 255;
                a = 255; // Core
              } else {
                r = 255;
                g = 200;
                b = 50;
                a = (255 * (1.0 - dist / 14)).toInt();
              }
            }
          } else {
            // Walking Enemy (Slots 0, 1, 2)
            // Bobbing effect
            final bob = (slotX == 0) ? -2 : 2;
            final wdy = (cy + bob) - ly;
            if (dx * dx + wdy * wdy < 12 * 12) {
              r = 180;
              g = 30;
              b = 30;
              a = 255; // Red Body
              // Eyes
              if (lx > 10 && lx < 14 && ly > 10 && ly < 14) {
                r = 255;
                g = 255;
                b = 0;
              }
              if (lx > 18 && lx < 22 && ly > 10 && ly < 14) {
                r = 255;
                g = 255;
                b = 0;
              }
            }
          }
        }
        // --- ROW 2: ATTACK ---
        else if (slotY == 2) {
          if (distSq < 12 * 12) {
            r = 255;
            g = 50;
            b = 50;
            a = 255; // Bright Red
            // Muzzle Flash
            if (slotX == 1) {
              if (lx > 20 && lx < 30 && ly > 14 && ly < 26) {
                r = 255;
                g = 255;
                b = 200; // Flash
              }
            }
            // Angry Eyes
            if (lx > 10 && lx < 14 && ly > 10 && ly < 14) {
              r = 255;
              g = 0;
              b = 0;
            }
            if (lx > 18 && lx < 22 && ly > 10 && ly < 14) {
              r = 255;
              g = 0;
              b = 0;
            }
          }
        }
        // --- ROW 3: PAIN / DIE ---
        else if (slotY == 3) {
          if (slotX == 0) {
            // Pain (White flash)
            if (distSq < 12 * 12) {
              r = 255;
              g = 200;
              b = 200;
              a = 255; // Whitish Red
              // Eyes Wide
              if (lx > 9 && lx < 15 && ly > 9 && ly < 15) {
                r = 0;
                g = 0;
                b = 0;
              }
              if (lx > 17 && lx < 23 && ly > 9 && ly < 15) {
                r = 0;
                g = 0;
                b = 0;
              }
            }
          } else {
            // Die (Flattened / Pool)
            if (lx > 4 && lx < 28 && ly > 20 && ly < 30) {
              r = 120;
              g = 0;
              b = 0;
              a = 255; // Blood pool
            }
          }
        }

        buffer[index] = r;
        buffer[index + 1] = g;
        buffer[index + 2] = b;
        buffer[index + 3] = a;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      buffer,
      size,
      size,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// Generates view-model sprites for weapons.
  /// Size: 320x64 (5 weapons x 64px width).
  /// 0: Pistol
  /// 1: Shotgun
  /// 2: Rifle
  /// 3: Bounce Pistol (uses Pistol sprite with diff colors)
  /// 4: Bounce Rifle (uses Rifle sprite with diff colors)
  static Future<ui.Image> generateWeaponAtlas() async {
    const width = 320; // 5 weapons * 64
    const height = 64;
    // const itemWidth = 64; // Unused

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // 0. Pistol
    _drawWeaponSprite(canvas, 0, 0, Colors.grey);

    // 1. Shotgun (Double barrel)
    _drawWeaponSprite(canvas, 1, 0, Colors.brown);

    // 2. Rifle (Automatic)
    _drawWeaponSprite(canvas, 2, 0, Colors.black);

    // 3. Bounce Pistol (Green/Futuristic)
    _drawWeaponSprite(canvas, 3, 0, Colors.lightGreen);

    // 4. Bounce Rifle (Blue/Futuristic)
    _drawWeaponSprite(canvas, 4, 0, Colors.lightBlue);

    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }

  static void _drawWeaponSprite(
    ui.Canvas canvas,
    int index,
    int row,
    ui.Color baseColor,
  ) {
    final offsetX = (index * 64).toDouble();
    final offsetY = (row * 64).toDouble();

    // Center of the 64x64 slot
    final cx = offsetX + 32;
    final bottom = offsetY + 64;

    // Metallic Gradient Helper
    ui.Paint getMetallicPaint(ui.Rect rect, ui.Color base) {
      return ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(rect.left, rect.top),
          ui.Offset(rect.right, rect.top),
          [
            base.withOpacity(0.4),
            base,
            base.withOpacity(0.6),
            base,
            base.withOpacity(0.4),
          ],
          [0.0, 0.2, 0.5, 0.8, 1.0],
        );
    }

    switch (index) {
      case 0: // Pistol
      case 3: // Bounce Pistol (Futuristic)
        // 1. Grip (Darker)
        final gripRect = ui.Rect.fromLTWH(cx - 5, bottom - 25, 10, 25);
        canvas.drawRect(
          gripRect,
          ui.Paint()..color = const ui.Color(0xFF2d2d2d),
        );

        // 2. Slide/Barrel (Metallic)
        final barrelRect = ui.Rect.fromLTWH(cx - 6, bottom - 35, 12, 28);
        canvas.drawRect(barrelRect, getMetallicPaint(barrelRect, baseColor));

        // 3. Slide Detail (Top highlight)
        canvas.drawRect(
          ui.Rect.fromLTWH(cx - 4, bottom - 35, 8, 28),
          ui.Paint()..color = ui.Color.fromARGB(50, 255, 255, 255),
        );

        // 4. Muzzle
        canvas.drawRect(
          ui.Rect.fromLTWH(cx - 2, bottom - 35, 4, 4),
          ui.Paint()..color = const ui.Color(0xFF111111),
        );
        break;

      case 1: // Shotgun
        // 1. Stock (Wood)
        final stockRect = ui.Rect.fromLTWH(cx - 8, bottom - 25, 16, 25);
        canvas.drawRect(
          stockRect,
          ui.Paint()..color = const ui.Color(0xFF5D4037),
        );
        // Wood grain
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            ui.Offset(cx - 6.0 + i * 5, bottom - 25),
            ui.Offset(cx - 6.0 + i * 5, bottom),
            ui.Paint()
              ..color = const ui.Color(0xFF3E2723)
              ..strokeWidth = 1,
          );
        }

        // 2. Barrels (Double Metallic)
        final b1 = ui.Rect.fromLTWH(cx - 8, bottom - 50, 6, 40);
        final b2 = ui.Rect.fromLTWH(cx + 2, bottom - 50, 6, 40);
        canvas.drawRect(b1, getMetallicPaint(b1, ui.Color(0xFF606060)));
        canvas.drawRect(b2, getMetallicPaint(b2, ui.Color(0xFF606060)));

        // 3. Muzzle Holes
        canvas.drawRect(
          ui.Rect.fromLTWH(cx - 7, bottom - 50, 4, 4),
          ui.Paint()..color = Colors.black,
        );
        canvas.drawRect(
          ui.Rect.fromLTWH(cx + 3, bottom - 50, 4, 4),
          ui.Paint()..color = Colors.black,
        );
        break;

      case 2: // Rifle
      case 4: // Bounce Rifle
        // 1. Stock (Dark Polymer)
        final stockRect = ui.Rect.fromLTWH(cx - 6, bottom - 20, 12, 20);
        canvas.drawRect(
          stockRect,
          ui.Paint()..color = const ui.Color(0xFF263238),
        );

        // 2. Body (Detailed)
        final bodyRect = ui.Rect.fromLTWH(cx - 8, bottom - 35, 16, 20);
        canvas.drawRect(bodyRect, getMetallicPaint(bodyRect, baseColor));

        // 3. Long Barrel
        final barrelRect2 = ui.Rect.fromLTWH(cx - 3, bottom - 60, 6, 30);
        canvas.drawRect(
          barrelRect2,
          getMetallicPaint(barrelRect2, const ui.Color(0xFF111111)),
        );

        // 4. Scope (Lens reflection)
        final scopeRect = ui.Rect.fromLTWH(cx - 4, bottom - 42, 8, 6);
        canvas.drawRect(
          scopeRect,
          ui.Paint()..color = const ui.Color(0xFF000000),
        );
        // Lens Glint
        canvas.drawCircle(
          ui.Offset(cx, bottom - 39),
          2,
          ui.Paint()..color = const ui.Color(0xFF4FC3F7),
        ); // Light Blue
        break;
    }
  }
}

// Helper class for Colors since we don't import material
class Colors {
  static const grey = ui.Color(0xFF808080);
  static const brown = ui.Color(0xFF8B4513);
  static const black = ui.Color(0xFF202020);
  static const lightGreen = ui.Color(0xFF90EE90);
  static const lightBlue = ui.Color(0xFFADD8E6);
}
