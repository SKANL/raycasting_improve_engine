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
    final rng = math.Random(1337);
    final offsetX = (tileX * tileSize).toDouble();
    final offsetY = (tileY * tileSize).toDouble();
    final paint = ui.Paint();

    for (var y = 0; y < tileSize; y++) {
      for (var x = 0; x < tileSize; x++) {
        // Charcoal tones, high contrast noise
        final base = rng.nextInt(25);
        final gray = base + 15; // 15 to 40
        paint.color = ui.Color.fromARGB(255, gray, gray + 2, gray + 4);
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
    final mortarPaint = ui.Paint()..color = const ui.Color(0xFF0A0C0E);

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
    final rng = math.Random(42);

    for (var row = 0; row < 4; row++) {
      final y = row * brickH;
      final rowOffset = row.isEven ? 0.0 : -7.0;

      for (var col = 0; col < 3; col++) {
        final x = col * (brickW + 2) + rowOffset;
        final drawX = offsetX + x + 1;
        final drawY = offsetY + y + 1;
        const drawW = brickW;
        const drawH = brickH - 2;

        final paint = ui.Paint()..color = const ui.Color(0xFF1A1D21);
        canvas.drawRect(
          ui.Rect.fromLTWH(drawX, drawY, drawW, drawH),
          paint,
        );

        // Add noise/texture to each brick
        for (var by = 0; by < drawH; by++) {
          for (var bx = 0; bx < drawW; bx++) {
            if (rng.nextDouble() > 0.4) {
              final noise = rng.nextInt(15);
              final pixelPaint = ui.Paint()
                ..color = ui.Color.fromARGB(
                  255,
                  26 + noise,
                  29 + noise,
                  33 + noise,
                );
              canvas.drawRect(
                ui.Rect.fromLTWH(drawX + bx, drawY + by, 1, 1),
                pixelPaint,
              );
            }
          }
        }
      }
    }
  }

  static void _drawWood(ui.Canvas canvas, int tileX, int tileY) {
    // Floor texture: Dark dirt/mud
    final rng = math.Random(999);
    final offsetX = (tileX * tileSize).toDouble();
    final offsetY = (tileY * tileSize).toDouble();
    final paint = ui.Paint();

    for (var y = 0; y < tileSize; y++) {
      for (var x = 0; x < tileSize; x++) {
        // Dark desaturated dirt tones #1E1C1A
        final noise = rng.nextInt(20);
        final r = 20 + noise;
        final g = 18 + (noise * 0.9).toInt();
        final b = 16 + (noise * 0.8).toInt();
        paint.color = ui.Color.fromARGB(255, r, g, b);
        canvas.drawRect(
          ui.Rect.fromLTWH(offsetX + x, offsetY + y, 1, 1),
          paint,
        );
      }
    }
  }

  static void _drawMetal(ui.Canvas canvas, int tileX, int tileY) {
    // Ceiling texture: Dark rocky gray
    final rng = math.Random(777);
    final offsetX = (tileX * tileSize).toDouble();
    final offsetY = (tileY * tileSize).toDouble();
    final paint = ui.Paint();

    for (var y = 0; y < tileSize; y++) {
      for (var x = 0; x < tileSize; x++) {
        // Slightly brighter rocky noise so it survives the aggressive GLSL darkening
        final gray = rng.nextInt(25) + 30; // 30 to 55 base gray
        paint.color = ui.Color.fromARGB(255, gray, gray + 2, gray + 4);
        canvas.drawRect(
          ui.Rect.fromLTWH(offsetX + x, offsetY + y, 1, 1),
          paint,
        );
      }
    }
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
    return _generateSpriteAtlasCanvas();
    // ignore: dead_code
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
          } else if (slotX == 1 || slotX == 2) {
            // Die (Flattened / Pool)
            if (lx > 4 && lx < 28 && ly > 20 && ly < 30) {
              r = 120;
              g = 0;
              b = 0;
              a = 255; // Blood pool
            }
            // slotX == 3 → Wall Torch sprite — Minecraft-style pixel art
            // 32×32 canvas. Torch is a diagonal stick (45°, bottom-left to
            // upper-right) inset into the wall, with layered pixel-art fire
            // at the tip and an iron bracket at the base.
          } else if (slotX == 3) {
            // ─────────────────────────────────────────────────────────────
            // Colour palette
            // ─────────────────────────────────────────────────────────────
            // Wood shades (for depth on the diagonal)
            const woodLight = 0xFFDEB887; // light grain highlight
            const woodMid = 0xFFC19A6B; // main face colour
            const woodDark = 0xFF8B5E3C; // shadow side
            const woodDarker = 0xFF6B3A1F; // deep shadow
            const woodCap = 0xFF4A280D; // charred tip / top-cap

            // Fire shades (top to bottom of flame)
            const fireTip = 0xFFFFFFCC; // white-hot tip
            const fireYellow = 0xFFFFE000; // bright yellow
            const fireOrangeH = 0xFFFF9900; // high orange
            const fireOrangeL = 0xFFFF6600; // low orange
            const fireRed = 0xFFCC2200; // base red spark

            // Bracket metal
            const metalHigh = 0xFFA0A0A8; // highlight
            const metalMid = 0xFF707078; // main face
            const metalDark = 0xFF404048; // shadow

            // Transparent sentinel
            const T = 0x00000000;

            // ─────────────────────────────────────────────────────────────
            // Full 32×32 pixel map (row 0 = top of sprite).
            // Each entry is an ARGB int.
            // ─────────────────────────────────────────────────────────────
            const pixelMap = <List<int>>[
              //    0    1    2    3    4    5    6    7    8    9   10   11   12   13   14   15   16   17   18   19   20   21   22   23   24   25   26   27   28   29   30   31
              /* 00 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                fireTip,
                fireTip,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 01 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                fireYellow,
                fireTip,
                fireYellow,
                fireTip,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 02 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                fireYellow,
                fireTip,
                fireYellow,
                fireTip,
                fireYellow,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 03 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                fireOrangeH,
                fireYellow,
                fireTip,
                fireYellow,
                fireTip,
                fireOrangeH,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 04 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                fireOrangeH,
                fireYellow,
                fireTip,
                fireYellow,
                fireTip,
                fireOrangeH,
                fireOrangeL,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 05 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                fireOrangeH,
                fireOrangeH,
                fireYellow,
                fireYellow,
                fireOrangeH,
                fireOrangeH,
                fireOrangeL,
                fireRed,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 06 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                fireOrangeL,
                fireOrangeH,
                fireOrangeH,
                fireYellow,
                fireOrangeH,
                fireOrangeL,
                fireRed,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 07 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                fireRed,
                fireOrangeL,
                fireOrangeH,
                fireOrangeH,
                fireOrangeL,
                fireRed,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 08 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                fireRed,
                fireOrangeL,
                fireOrangeL,
                fireRed,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 09 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                woodCap,
                woodCap,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 10 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                woodCap,
                woodDark,
                woodMid,
                woodCap,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 11 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                woodCap,
                woodDark,
                woodMid,
                woodDark,
                woodCap,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 12 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                woodCap,
                woodDark,
                woodMid,
                woodLight,
                woodMid,
                woodDark,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 13 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                woodDarker,
                woodDark,
                woodMid,
                woodLight,
                woodMid,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 14 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                woodDarker,
                woodDark,
                woodMid,
                woodLight,
                woodMid,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 15 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                woodDarker,
                woodDark,
                woodMid,
                woodLight,
                woodMid,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 16 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                woodDarker,
                woodDark,
                woodMid,
                woodLight,
                woodLight,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 17 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                woodDarker,
                woodDark,
                woodMid,
                woodLight,
                woodMid,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 18 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                woodDarker,
                woodDark,
                woodMid,
                woodLight,
                woodMid,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 19 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                woodDarker,
                woodDark,
                woodMid,
                woodLight,
                woodMid,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 20 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                woodDarker,
                woodDark,
                woodMid,
                woodLight,
                woodMid,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 21 */ [
                T,
                T,
                T,
                T,
                T,
                woodDarker,
                woodDark,
                woodMid,
                woodLight,
                woodMid,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 22 */ [
                T,
                T,
                T,
                T,
                woodDarker,
                woodDark,
                woodMid,
                woodLight,
                woodMid,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 23 */ [
                T,
                T,
                T,
                woodDarker,
                woodDark,
                woodMid,
                woodLight,
                woodMid,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 24 */ [
                T,
                T,
                metalHigh,
                metalMid,
                woodDark,
                woodMid,
                woodMid,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 25 */ [
                T,
                metalHigh,
                metalMid,
                metalMid,
                metalDark,
                woodDarker,
                woodDarker,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 26 */ [
                metalHigh,
                metalMid,
                metalMid,
                metalDark,
                metalDark,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 27 */ [
                metalMid,
                metalMid,
                metalDark,
                metalDark,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 28 */ [
                metalMid,
                metalDark,
                metalDark,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 29 */ [
                metalDark,
                metalDark,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 30 */ [
                metalDark,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
              /* 31 */ [
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
                T,
              ],
            ];

            if (ly < pixelMap.length && lx < pixelMap[ly].length) {
              final argb = pixelMap[ly][lx];
              a = (argb >> 24) & 0xFF;
              r = (argb >> 16) & 0xFF;
              g = (argb >> 8) & 0xFF;
              b = argb & 0xFF;
            }
          } // end slotX == 3
        } // end slotY == 3

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

  // ignore: long-method
  static void _drawWeaponSprite(
    ui.Canvas canvas,
    int index,
    int row,
    ui.Color baseColor,
  ) {
    final ox = (index * 64).toDouble(); // tile X offset
    final oy = (row  * 64).toDouble(); // tile Y offset
    // All coordinates below are relative to the tile top-left (ox, oy).
    // The tile is 64×64.  bottom=64, center-X=32.

    // ── helpers ───────────────────────────────────────────────────────────
    ui.Rect r(double l, double t, double w, double h) =>
        ui.Rect.fromLTWH(ox + l, oy + t, w, h);

    ui.Paint fill(ui.Color c) => ui.Paint()..color = c;

    // Horizontal metallic gradient on a rect
    ui.Paint metal(ui.Rect rect, ui.Color mid,
        {double darkF = 0.38, double lightF = 1.35}) {
      final dark = ui.Color.fromARGB(
        mid.alpha,
        (mid.red   * darkF).clamp(0, 255).round(),
        (mid.green * darkF).clamp(0, 255).round(),
        (mid.blue  * darkF).clamp(0, 255).round(),
      );
      final lite = ui.Color.fromARGB(
        mid.alpha,
        (mid.red   * lightF).clamp(0, 255).round(),
        (mid.green * lightF).clamp(0, 255).round(),
        (mid.blue  * lightF).clamp(0, 255).round(),
      );
      return ui.Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.topRight,
          [dark, lite, mid, dark],
          [0.0, 0.25, 0.6, 1.0],
        );
    }

    // Rounded rect helper
    void rr(ui.Canvas c, double l, double t, double w, double h,
        double rad, ui.Paint p) =>
        c.drawRRect(
          ui.RRect.fromRectAndRadius(r(l, t, w, h), ui.Radius.circular(rad)),
          p,
        );

    // ── draw line helper (relative)
    void ln(ui.Canvas c, double x1, double y1, double x2, double y2,
        ui.Color col, double sw) =>
        c.drawLine(
          ui.Offset(ox + x1, oy + y1),
          ui.Offset(ox + x2, oy + y2),
          fill(col)..strokeWidth = sw,
        );

    // ── shadow tint
    const shadowC = ui.Color(0x55000000);
    // ── highlight tint
    const hiC     = ui.Color(0x44FFFFFF);

    // ─────────────────────────────────────────────────────────────────────
    switch (index) {

      // ════════════════════════════════════════════════════════════════════
      case 0: // PISTOL  (compact semi-auto, Glock-inspired)
      // ════════════════════════════════════════════════════════════════════
        {
          // Grip (polymer, slightly tilted — drawn as rects for simplicity)
          final gripR = r(26, 42, 14, 22);
          canvas.drawRRect(
            ui.RRect.fromLTRBAndCorners(gripR.left, gripR.top, gripR.right, gripR.bottom,
              bottomLeft: const ui.Radius.circular(3),
              bottomRight: const ui.Radius.circular(3),
            ),
            fill(const ui.Color(0xFF1A1A1A)),
          );
          // Grip texture stippling
          for (var gy = 0; gy < 5; gy++) {
            for (var gx = 0; gx < 3; gx++) {
              canvas.drawCircle(
                ui.Offset(ox + 28.5 + gx * 4.5, oy + 44.5 + gy * 4.0),
                0.8,
                fill(const ui.Color(0xFF333333)),
              );
            }
          }
          // Trigger guard
          canvas.drawArc(
            r(24, 37, 10, 9),
            0, 3.14159, false,
            fill(const ui.Color(0xFF111111))..style = ui.PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
          // Slide (main body − metallic dark grey)
          final slideR = r(22, 18, 20, 26);
          canvas.drawRect(slideR, metal(slideR, const ui.Color(0xFF555555)));
          // Slide top flat
          canvas.drawRect(r(23, 18, 18, 4), fill(const ui.Color(0xFF444444)));
          // Cut-out ejection port (right side)
          canvas.drawRect(r(38, 24, 4, 8), fill(const ui.Color(0xFF0A0A0A)));
          // Serrations (rear slide grip)
          for (var i = 0; i < 5; i++) {
            ln(canvas, 37.0, 19.0 + i * 2.8, 40.0, 19.0 + i * 2.8,
               const ui.Color(0xFF333333), 1.0);
          }
          // Barrel (extends slightly past slide top)
          rr(canvas, 28, 13, 8, 8, 1.5, metal(r(28, 13, 8, 8), const ui.Color(0xFF3A3A3A)));
          // Muzzle hole
          canvas.drawCircle(ui.Offset(ox + 32, oy + 15), 2.0,
              fill(const ui.Color(0xFF050505)));
          // Front sight (tiny post)
          canvas.drawRect(r(31, 13, 2, 3), fill(const ui.Color(0xFFEEEEEE)));
          // Rear sight notch
          canvas.drawRect(r(22, 18, 5, 3), fill(const ui.Color(0xFF888888)));
          canvas.drawRect(r(23, 18, 3, 2), fill(const ui.Color(0xFF0A0A0A)));
          // Top highlight
          canvas.drawRect(r(23, 18, 18, 2), fill(hiC));
        }
        break;

      // ════════════════════════════════════════════════════════════════════
      case 1: // SHOTGUN  (double-barrel side-by-side + pump grip)
      // ════════════════════════════════════════════════════════════════════
        {
          // Stock (walnut wood)
          final stR = r(18, 44, 28, 20);
          canvas.drawRRect(
            ui.RRect.fromLTRBAndCorners(stR.left, stR.top, stR.right, stR.bottom,
              bottomLeft:  const ui.Radius.circular(4),
              bottomRight: const ui.Radius.circular(4),
            ),
            fill(const ui.Color(0xFF5C3011)),
          );
          // Wood grain lines
          for (var i = 0; i < 5; i++) {
            ln(canvas, 20.0 + i * 5.5, 44.0, 19.0 + i * 5.5, 64.0,
               const ui.Color(0xFF3B1E0A), 0.8);
          }
          // Stock highlight
          canvas.drawRect(r(18, 44, 28, 2), fill(const ui.Color(0x33FFCC88)));
          // Receiver / action
          final recR = r(16, 36, 32, 12);
          canvas.drawRect(recR, metal(recR, const ui.Color(0xFF5A5A5A)));
          canvas.drawRect(r(17, 37, 30, 3), fill(const ui.Color(0xFF333333)));
          // Pump forend
          final pumpR = r(17, 28, 30, 9);
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(pumpR, const ui.Radius.circular(3)),
            metal(pumpR, const ui.Color(0xFF4A3010)),
          );
          // Pump grip lines
          for (var i = 0; i < 6; i++) {
            ln(canvas, 18.0 + i * 4.5, 29.0, 18.0 + i * 4.5, 36.0,
               const ui.Color(0xFF2A1A08), 1.2);
          }
          // Left barrel
          final lb = r(18, 4, 11, 28);
          canvas.drawRRect(ui.RRect.fromRectAndRadius(lb, const ui.Radius.circular(2)),
              metal(lb, const ui.Color(0xFF626262)));
          canvas.drawRect(r(19, 4, 9, 3), fill(const ui.Color(0xFF444444)));
          // Right barrel
          final rb = r(31, 4, 11, 28);
          canvas.drawRRect(ui.RRect.fromRectAndRadius(rb, const ui.Radius.circular(2)),
              metal(rb, const ui.Color(0xFF5A5A5A)));
          canvas.drawRect(r(32, 4, 9, 3), fill(const ui.Color(0xFF3A3A3A)));
          // Muzzle holes
          canvas.drawOval(r(19, 4, 9, 5), fill(const ui.Color(0xFF0A0A0A)));
          canvas.drawOval(r(32, 4, 9, 5), fill(const ui.Color(0xFF0A0A0A)));
          // Rib between barrels
          canvas.drawRect(r(29, 6, 2, 22), fill(const ui.Color(0xFF787878)));
          // Top highlight
          canvas.drawRect(r(16, 36, 32, 1), fill(hiC));
          // Barrel band
          canvas.drawRect(r(16, 14, 32, 3), metal(r(16, 14, 32, 3), const ui.Color(0xFF888888)));
        }
        break;

      // ════════════════════════════════════════════════════════════════════
      case 2: // RIFLE  (assault rifle, AK/M16 inspired)
      // ════════════════════════════════════════════════════════════════════
        {
          // Stock / buffer tube
          rr(canvas, 36, 50, 18, 10, 2, fill(const ui.Color(0xFF1A2030)));
          canvas.drawRect(r(36, 50, 18, 2), fill(const ui.Color(0xFF2A3040)));
          // Pistol grip (polymer)
          final pgR = r(34, 42, 12, 20);
          canvas.drawRRect(
            ui.RRect.fromLTRBAndCorners(pgR.left, pgR.top, pgR.right, pgR.bottom,
              bottomLeft:  const ui.Radius.circular(4),
              bottomRight: const ui.Radius.circular(4),
            ),
            fill(const ui.Color(0xFF181818)),
          );
          // Grip stippling
          for (var gy = 0; gy < 4; gy++) {
            for (var gx = 0; gx < 3; gx++) {
              canvas.drawCircle(
                ui.Offset(ox + 35.5 + gx * 3.5, oy + 44 + gy * 4.5),
                0.7, fill(const ui.Color(0xFF2A2A2A)));
            }
          }
          // Trigger guard
          canvas.drawArc(r(31, 36, 12, 10), 0, 3.14159, false,
            fill(const ui.Color(0xFF111111))..style = ui.PaintingStyle.stroke
              ..strokeWidth = 2.0);
          // Lower receiver
          final lrR = r(14, 38, 34, 14);
          canvas.drawRect(lrR, metal(lrR, const ui.Color(0xFF3A3A3A)));
          // Magazine (box, angled)
          final magR = r(22, 44, 12, 16);
          canvas.drawRRect(
            ui.RRect.fromLTRBAndCorners(magR.left, magR.top, magR.right, magR.bottom,
              bottomLeft:  const ui.Radius.circular(2),
              bottomRight: const ui.Radius.circular(2),
            ),
            metal(magR, const ui.Color(0xFF484848)),
          );
          // Mag spine lines
          ln(canvas, 28.0, 45.0, 28.0, 60.0, const ui.Color(0xFF222222), 1.5);
          canvas.drawRect(r(22, 44, 12, 2), fill(const ui.Color(0xFF666666)));
          // Upper receiver / carry-handle rail
          final urR = r(10, 28, 40, 12);
          canvas.drawRect(urR, metal(urR, const ui.Color(0xFF404040)));
          // Carry-handle
          final chR = r(24, 22, 18, 8);
          canvas.drawRect(chR, metal(chR, const ui.Color(0xFF353535)));
          canvas.drawRect(r(24, 22, 18, 2), fill(const ui.Color(0xFF555555)));
          // Rail serrations
          for (var i = 0; i < 5; i++) {
            ln(canvas, 11.0 + i * 7.5, 28.0, 11.0 + i * 7.5, 30.0,
               const ui.Color(0xFF555555), 1.0);
          }
          // Barrel (long, cylindrical look)
          canvas.drawRect(r(10, 18, 16, 12),
              metal(r(10, 18, 16, 12), const ui.Color(0xFF3C3C3C)));
          canvas.drawRect(r(8,  8,  8, 12),
              metal(r(8,  8,  8, 12),  const ui.Color(0xFF484848)));
          final barR = r(9, 2, 6, 8);
          canvas.drawRRect(ui.RRect.fromRectAndRadius(barR, const ui.Radius.circular(1.5)),
              metal(barR, const ui.Color(0xFF3A3A3A)));
          // Muzzle device (3 small notches)
          for (var i = 0; i < 3; i++) {
            canvas.drawRect(r(9.0 + i * 2.0, 2.0, 1.5, 4), fill(const ui.Color(0xFF555555)));
          }
          // Muzzle hole
          canvas.drawOval(r(10, 2, 4, 4), fill(const ui.Color(0xFF050505)));
          // Charging handle
          canvas.drawRect(r(46, 28, 4, 5), fill(const ui.Color(0xFF282828)));
          // Top highlight
          canvas.drawRect(r(10, 28, 40, 1), fill(hiC));
          // Front sight post
          ln(canvas, 12.0, 17.0, 12.0, 19.0, const ui.Color(0xFFDDDDDD), 1.5);
        }
        break;

      // ════════════════════════════════════════════════════════════════════
      case 3: // BOUNCE PISTOL (compact energy pistol, cyan/green coils)
      // ════════════════════════════════════════════════════════════════════
        {
          final glowC   = baseColor;  // lightGreen
          final glowMid = ui.Color.fromARGB(200, glowC.red, glowC.green, glowC.blue);
          final glowDim = ui.Color.fromARGB(80,  glowC.red, glowC.green, glowC.blue);

          // Grip (futuristic rounded polymer)
          rr(canvas, 25, 42, 16, 22, 3, fill(const ui.Color(0xFF101820)));
          // Grip accent stripe
          canvas.drawRect(r(25, 48, 16, 2), fill(glowDim));
          canvas.drawRect(r(25, 55, 16, 2), fill(glowDim));

          // Body / frame (bulkier than normal pistol)
          final bodyR = r(20, 20, 24, 24);
          canvas.drawRRect(ui.RRect.fromRectAndRadius(bodyR, const ui.Radius.circular(3)),
              metal(bodyR, const ui.Color(0xFF1A2A2A)));
          // Side panel accent
          canvas.drawRect(r(21, 22, 22, 3),
              fill(ui.Color.fromARGB(120, glowC.red, glowC.green, glowC.blue)));

          // Energy coil on barrel (3 rings, decreasing size upward)
          for (var i = 0; i < 3; i++) {
            final ry = oy + 12.0 + i * 5.0;
            canvas.drawOval(
              ui.Rect.fromCenter(center: ui.Offset(ox + 32, ry), width: 12 - i.toDouble(), height: 4),
              fill(glowMid)..style = ui.PaintingStyle.stroke..strokeWidth = 1.5,
            );
          }
          // Inner glow on coil
          canvas.drawRect(r(27, 10, 10, 18),
              fill(ui.Color.fromARGB(40, glowC.red, glowC.green, glowC.blue)));

          // Barrel (short energy muzzle)
          final barR = r(27, 6, 10, 6);
          canvas.drawRRect(ui.RRect.fromRectAndRadius(barR, const ui.Radius.circular(2)),
              metal(barR,  const ui.Color(0xFF1A3030)));
          // Muzzle glow opening
          canvas.drawOval(r(29, 6, 6, 4), fill(glowMid));
          canvas.drawOval(r(30, 7, 4, 2), fill(const ui.Color(0xFF00FFCC)));

          // Trigger guard (glowing)
          canvas.drawArc(r(22, 38, 10, 8), 0, 3.14159, false,
            fill(glowDim)..style = ui.PaintingStyle.stroke..strokeWidth = 1.5);

          // Top highlight
          canvas.drawRect(r(20, 20, 24, 2), fill(hiC));
        }
        break;

      // ════════════════════════════════════════════════════════════════════
      case 4: // BOUNCE RIFLE (long energy rifle, blue/cyan coil rings)
      // ════════════════════════════════════════════════════════════════════
        {
          final glowC   = baseColor; // lightBlue
          final glowMid = ui.Color.fromARGB(200, glowC.red, glowC.green, glowC.blue);
          final glowDim = ui.Color.fromARGB(80,  glowC.red, glowC.green, glowC.blue);

          // Stock (dark composite)
          rr(canvas, 36, 50, 20, 14, 3, fill(const ui.Color(0xFF0D1520)));
          canvas.drawRect(r(36, 50, 20, 2), fill(const ui.Color(0xFF1A2535)));
          // Stock energy accent
          canvas.drawRect(r(38, 57, 14, 2),
              fill(ui.Color.fromARGB(100, glowC.red, glowC.green, glowC.blue)));

          // Pistol grip
          rr(canvas, 34, 40, 12, 22, 3, fill(const ui.Color(0xFF0A1218)));
          canvas.drawRect(r(35, 44, 10, 2), fill(glowDim));
          canvas.drawRect(r(35, 51, 10, 2), fill(glowDim));

          // Main body / rail (long horizontal)
          final bodyR = r(8, 30, 48, 14);
          canvas.drawRect(bodyR, metal(bodyR, const ui.Color(0xFF152030)));
          canvas.drawRect(r(8, 30, 48, 2), fill(const ui.Color(0xFF1F3040)));

          // Energy conduit (glowing channel on top)
          canvas.drawRect(r(8, 30, 48, 3),
              fill(ui.Color.fromARGB(80, glowC.red, glowC.green, glowC.blue)));

          // Barrel (long, extends to top)
          final barR = r(8, 4, 10, 28);
          canvas.drawRRect(ui.RRect.fromRectAndRadius(barR, const ui.Radius.circular(2)),
              metal(barR, const ui.Color(0xFF101E2A)));

          // Energy coil rings along barrel (5 rings evenly spaced)
          for (var i = 0; i < 5; i++) {
            final ry = oy + 7.0 + i * 5.0;
            canvas.drawOval(
              ui.Rect.fromCenter(center: ui.Offset(ox + 13, ry), width: 14, height: 4),
              fill(glowMid)..style = ui.PaintingStyle.stroke..strokeWidth = 1.8,
            );
            // Inner glow within ring
            canvas.drawOval(
              ui.Rect.fromCenter(center: ui.Offset(ox + 13, ry), width: 10, height: 3),
              fill(ui.Color.fromARGB(30, glowC.red, glowC.green, glowC.blue)),
            );
          }

          // Barrel glow channel
          canvas.drawRect(r(10, 4, 6, 26),
              fill(ui.Color.fromARGB(25, glowC.red, glowC.green, glowC.blue)));

          // Muzzle emitter
          rr(canvas, 8, 2, 10, 4, 1.5, metal(r(8, 2, 10, 4), const ui.Color(0xFF102030)));
          canvas.drawOval(r(10, 2, 6, 4), fill(glowMid));
          canvas.drawOval(r(11, 3, 4, 2), fill(const ui.Color(0xFFAAEEFF)));

          // Scope rail / carry handle
          final scopeR = r(22, 24, 20, 8);
          canvas.drawRect(scopeR, metal(scopeR, const ui.Color(0xFF1A2A38)));
          // Lens
          canvas.drawOval(r(28, 25, 8, 5), fill(const ui.Color(0xFF050A10)));
          canvas.drawOval(r(30, 26, 4, 3), fill(glowMid));
          // Scope highlight
          ln(canvas, 30.0, 26.0, 31.5, 27.5, const ui.Color(0xAAFFFFFF), 0.8);

          // Charging handle
          canvas.drawRect(r(54, 30, 2, 7), fill(const ui.Color(0xFF0A1520)));

          // Magazine (slimmer box)
          final magR = r(26, 40, 10, 12);
          canvas.drawRRect(
            ui.RRect.fromLTRBAndCorners(magR.left, magR.top, magR.right, magR.bottom,
              bottomLeft:  const ui.Radius.circular(2),
              bottomRight: const ui.Radius.circular(2),
            ),
            metal(magR, const ui.Color(0xFF182530)),
          );
          canvas.drawRect(r(26, 40, 10, 2),
              fill(ui.Color.fromARGB(150, glowC.red, glowC.green, glowC.blue)));

          // Shadow below body
          canvas.drawRect(r(8, 42, 56, 2), fill(shadowC));
          // Top highlight
          canvas.drawRect(r(8, 30, 48, 1), fill(hiC));
        }
        break;
    }
  }

  // ── Canvas-based humanoid sprite atlas ─────────────────────────────────
  // Layout: 128 × 384 px
  //   Grunt    Y   0–127  (military olive)
  //   Shooter  Y 128–255  (tactical steel)
  //   Guardian Y 256–383  (heavy blood-armor)
  //
  // Per type, col 0–1: animation frames A/B per row. Cols 2–3 at Y=0: particles.
  static Future<ui.Image> _generateSpriteAtlasCanvas() async {
    const w = 128;
    const h = 384;
    final rec = ui.PictureRecorder();
    final c   = ui.Canvas(
      rec, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    c.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = const ui.Color(0x00000000),
    );
    // Projectile particle glows — backward-compat positions (Y=0 cols 2-3)
    _spriteProjectileGlow(c, 64, 0,
        const ui.Color(0xFF0088EE), const ui.Color(0xFF44FFFF));
    _spriteProjectileGlow(c, 96, 0,
        const ui.Color(0xFF008800), const ui.Color(0xFF88FF88));
    // Enemy sprite sheets
    _spriteEnemyAllFrames(c, 0,   _ESPalette.grunt);
    _spriteEnemyAllFrames(c, 128, _ESPalette.shooter);
    _spriteEnemyAllFrames(c, 256, _ESPalette.guardian);
    return rec.endRecording().toImage(w, h);
  }

  static void _spriteProjectileGlow(
    ui.Canvas c, double ox, double oy, ui.Color core, ui.Color rim,
  ) {
    c.drawCircle(
      ui.Offset(ox + 16, oy + 16), 12,
      ui.Paint()
        ..color = rim.withValues(alpha: 0.6)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5),
    );
    c.drawCircle(ui.Offset(ox + 16, oy + 16), 7,  ui.Paint()..color = core);
    c.drawCircle(ui.Offset(ox + 16, oy + 16), 3,
        ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  }

  static void _spriteEnemyAllFrames(ui.Canvas c, double yBase, _ESPalette p) {
    _spriteEnemy(c,  0, yBase +  0, p, _ESFrame.idleA);
    _spriteEnemy(c, 32, yBase +  0, p, _ESFrame.idleB);
    _spriteEnemy(c,  0, yBase + 32, p, _ESFrame.walkA);
    _spriteEnemy(c, 32, yBase + 32, p, _ESFrame.walkB);
    _spriteEnemy(c,  0, yBase + 64, p, _ESFrame.attackA);
    _spriteEnemy(c, 32, yBase + 64, p, _ESFrame.attackB);
    _spriteEnemy(c,  0, yBase + 96, p, _ESFrame.pain);
    _spriteEnemy(c, 32, yBase + 96, p, _ESFrame.die);
  }

  /// Draws a single 32×32 humanoid enemy tile at canvas origin (ox, oy).
  static void _spriteEnemy(
      ui.Canvas c, double ox, double oy, _ESPalette p, _ESFrame f) {
    final ui.Color helmet, helmetHi, visor, torso, arm, gunB, gunHi, leg, boot,
        eye;
    switch (p) {
      case _ESPalette.grunt:
        helmet   = const ui.Color(0xFF263010); helmetHi = const ui.Color(0xFF3E5018);
        visor    = const ui.Color(0xFF1A1A0E); torso    = const ui.Color(0xFF32481A);
        arm      = const ui.Color(0xFF2A3A14); gunB     = const ui.Color(0xFF282828);
        gunHi    = const ui.Color(0xFF444444); leg      = const ui.Color(0xFF243018);
        boot     = const ui.Color(0xFF141410); eye      = const ui.Color(0xFFFF6600);
      case _ESPalette.shooter:
        helmet   = const ui.Color(0xFF282835); helmetHi = const ui.Color(0xFF444455);
        visor    = const ui.Color(0xFF003880); torso    = const ui.Color(0xFF383848);
        arm      = const ui.Color(0xFF303040); gunB     = const ui.Color(0xFF181820);
        gunHi    = const ui.Color(0xFF3A3A4A); leg      = const ui.Color(0xFF282830);
        boot     = const ui.Color(0xFF141418); eye      = const ui.Color(0xFF00CCFF);
      case _ESPalette.guardian:
        helmet   = const ui.Color(0xFF380808); helmetHi = const ui.Color(0xFF600000);
        visor    = const ui.Color(0xFF8A0000); torso    = const ui.Color(0xFF250505);
        arm      = const ui.Color(0xFF280000); gunB     = const ui.Color(0xFF0F0808);
        gunHi    = const ui.Color(0xFF350808); leg      = const ui.Color(0xFF1E0000);
        boot     = const ui.Color(0xFF0F0000); eye      = const ui.Color(0xFFFF2200);
    }
    final paint = ui.Paint();
    void b(double x, double y, double w, double h, ui.Color col) {
      paint.color = col;
      c.drawRect(ui.Rect.fromLTWH(ox + x, oy + y, w, h), paint);
    }
    var headY = 0.0, llY = 0.0, rlY = 0.0, armY = 0.0;
    var muzzle = false;
    switch (f) {
      case _ESFrame.idleA:   headY = -0.5; break;
      case _ESFrame.idleB:   headY =  0.5; break;
      case _ESFrame.walkA:   llY = -2; rlY =  2; break;
      case _ESFrame.walkB:   llY =  2; rlY = -2; break;
      case _ESFrame.attackA: armY = -3; break;
      case _ESFrame.attackB: armY = -3; muzzle = true; break;
      case _ESFrame.pain:    break;
      case _ESFrame.die:     break;
    }
    // Die: collapsed heap
    if (f == _ESFrame.die) {
      b(4, 19, 22, 6, torso);  b(4, 21, 9,  9, leg);
      b(16, 21, 9,  9, leg);   b(3, 27, 26, 3, boot);
      b(19, 14, 10, 8, helmet); b(21, 16, 6, 4, visor);
      b(22, 17, 2,  2, const ui.Color(0xFF330000));
      return;
    }
    // Pain: body flash
    if (f == _ESFrame.pain) {
      final flash = ui.Color.fromARGB(255,
        ((torso.r * 255 + 0xCC) ~/ 2).clamp(0, 255),
        ((torso.g * 255 + 0xCC) ~/ 2).clamp(0, 255),
        ((torso.b * 255 + 0xCC) ~/ 2).clamp(0, 255));
      b(11, 2, 10, 8, helmetHi); b(13, 4, 6, 4, visor);
      b(14, 5, 2, 2, eye);       b(18, 5, 2, 2, eye);
      b(14, 11, 4, 2, helmet);
      b(9, 13, 14, 11, flash);   b(5, 13, 4, 5, flash);
      b(23, 13, 4, 5, flash);    b(5, 18, 4, 8, arm);
      b(23, 18, 4, 8, arm);      b(25, 20, 7, 3, gunB);
      b(10, 24, 5, 7, leg);      b(17, 24, 5, 7, leg);
      b(9, 30, 7, 2, boot);      b(17, 30, 7, 2, boot);
      return;
    }
    // Helmet
    b(11, 2 + headY, 10, 8, helmet);
    b(11, 2 + headY, 10, 2, helmetHi);
    b(13, 4 + headY, 6,  4, visor);
    b(14, 5 + headY, 2,  2, eye);
    b(18, 5 + headY, 2,  2, eye);
    b(14, 10 + headY, 4, 2, helmet);
    // Shoulders + torso
    b(5, 12, 7, 4, torso);  b(20, 12, 7, 4, torso);
    b(9, 12, 14, 12, torso);
    b(9, 12, 14, 1, ui.Color.fromARGB(70, 255, 255, 255)); // chest seam
    // Arms
    b(5, 16, 4, 9, arm);
    b(23, 16 + armY, 4, 9, arm);
    // Weapon
    final gy = 18.0 + armY;
    b(25, gy, 7, 3, gunB);  b(25, gy, 2, 3, gunHi);  b(30, gy + 1, 2, 1, gunHi);
    if (muzzle) {
      b(30, gy - 2, 3, 4, const ui.Color(0xFFFFFF00));
      b(31, gy - 3, 2, 2, const ui.Color(0xFFFFFFFF));
    }
    // Guardian shoulder spikes
    if (p == _ESPalette.guardian) {
      b(5, 8, 3, 6, helmetHi);  b(24, 8, 3, 6, helmetHi);
    }
    // Legs + boots
    b(10, 24 + llY, 5, 7, leg);  b(17, 24 + rlY, 5, 7, leg);
    b(11, 24 + llY, 2, 7, ui.Color.fromARGB(40, 255, 255, 255));
    b(18, 24 + rlY, 2, 7, ui.Color.fromARGB(40, 255, 255, 255));
    b(9, 31 + llY, 7, 2, boot);  b(17, 31 + rlY, 7, 2, boot);
  }
}

enum _ESPalette { grunt, shooter, guardian }
enum _ESFrame   { idleA, idleB, walkA, walkB, attackA, attackB, pain, die }

// Helper class for Colors since we don't import material
class Colors {
  static const grey = ui.Color(0xFF808080);
  static const brown = ui.Color(0xFF8B4513);
  static const black = ui.Color(0xFF202020);
  static const lightGreen = ui.Color(0xFF90EE90);
  static const lightBlue = ui.Color(0xFFADD8E6);
}
