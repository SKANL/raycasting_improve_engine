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
    final buffer = Uint8List(atlasSize * atlasSize * 4);

    for (var y = 0; y < atlasSize; y++) {
      for (var x = 0; x < atlasSize; x++) {
        final index = (y * atlasSize + x) * 4;

        // Determine which tile slot we are in
        final tileX = x ~/ tileSize;
        final tileY = y ~/ tileSize;
        final slot = tileY * 4 + tileX;

        // Local UV within the tile (0-31)
        final localX = x % tileSize;
        final localY = y % tileSize;

        var r = 0;
        var g = 0;
        var b = 0;

        if (slot == 0) {
          // Debug: Checkerboard
          final isWhite = ((localX ~/ 8) + (localY ~/ 8)).isEven;
          final val = isWhite ? 255 : 128;
          r = val;
          g = 0;
          b = val; // Purple/Pink
        } else if (slot == 1) {
          // Bricks: Reddish with mortar lines
          // Simple mortar check
          if (localY % 8 == 0 || (localY ~/ 8).isEven
              ? localX % 16 == 0
              : (localX + 8) % 16 == 0) {
            r = 180;
            g = 180;
            b = 180; // Grey Mortar
          } else {
            // Noise for brick texture
            final noise = math.Random(x * y).nextInt(30);
            r = 200 - noise;
            g = 100 - noise;
            b = 80 - noise;
          }
        } else if (slot == 2) {
          // Stone: Grey Noise
          final noise = math.Random(x ^ y).nextInt(60);
          final val = 100 + noise;
          r = val;
          g = val;
          b = val;
        } else if (slot == 3) {
          // Wood: Brown Vertical lines
          final noise = math.Random(x).nextInt(40);
          r = 140 + noise;
          g = 90 + noise;
          b = 50 + noise;
        } else {
          // Unused: Black
          r = 0;
          g = 0;
          b = 0;
        }

        buffer[index] = r;
        buffer[index + 1] = g;
        buffer[index + 2] = b;
        buffer[index + 3] = 255; // Alpha
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      buffer,
      atlasSize,
      atlasSize,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );

    return completer.future;
  }

  /// Generates a separate atlas for entities (Enemies, Items).
  /// 32x32 Tiles.
  /// Slot 0: Enemy (Red Blob)
  /// Slot 1: Key (Yellow)
  static Future<ui.Image> generateSpriteAtlas() async {
    const size = 64; // Small atlas
    final buffer = Uint8List(size * size * 4);

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final index = (y * size + x) * 4;
        final slot = (x ~/ 32) + (y ~/ 32) * 2;
        final lx = x % 32;
        final ly = y % 32;

        var r = 0;
        var g = 0;
        var b = 0;
        var a = 0;

        if (slot == 0) {
          // Enemy: Red Circle with Eyes
          const cx = 16.0;
          const cy = 16.0;
          final dx = cx - lx;
          final dy = cy - ly;
          if (dx * dx + dy * dy < 12 * 12) {
            r = 200;
            g = 20;
            b = 20;
            a = 255; // Red Body

            // Eyes
            if (lx > 10 && lx < 14 && ly > 10 && ly < 14) {
              r = 0;
              g = 0;
              b = 0;
            } // Left
            if (lx > 18 && lx < 22 && ly > 10 && ly < 14) {
              r = 0;
              g = 0;
              b = 0;
            } // Right
          }
        } else if (slot == 1) {
          // Key: Yellow rectangle roughly
          if (lx > 12 && lx < 20 && ly > 4 && ly < 20) {
            r = 255;
            g = 215;
            b = 0;
            a = 255;
          }
          if (lx > 12 && lx < 24 && ly > 8 && ly < 12) {
            r = 255;
            g = 215;
            b = 0;
            a = 255;
          }
        } else if (slot == 2) {
          // Muzzle Flash / Spark: Yellow/Orange burst
          const cx = 16.0;
          const cy = 16.0;
          final dx = cx - lx;
          final dy = cy - ly;
          final distSq = dx * dx + dy * dy;
          if (distSq < 10 * 10) {
            final dist = math.sqrt(distSq);
            r = 255;
            g = (200 - (dist * 15)).toInt().clamp(0, 255);
            b = 50;
            a = (255 * (1.0 - dist / 10.0)).toInt().clamp(0, 255);
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
}
