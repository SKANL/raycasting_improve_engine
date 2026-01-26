import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:raycasting_game/features/core/world/models/game_map.dart';

class TexturePacker {
  /// Packs the [GameMap] into a [ui.Image] for the shader.
  /// Format: RGBA
  /// R: Type (0=Empty, 1=Wall, etc.) / 255
  /// G: Floor Height * 255
  /// B: Ceiling Height * 255
  /// A: Texture ID
  static Future<ui.Image> packMap(GameMap map) async {
    final width = map.width;
    final height = map.height;

    // 4 bytes per pixel (RGBA)
    final buffer = Uint8List(width * height * 4);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final cell = map.grid[y][x];
        final index = (y * width + x) * 4;

        // R: Type
        buffer[index] = cell.type;

        // G: Floor Height (0.0 - 1.0 mapped to 0 - 255)
        buffer[index + 1] = (cell.floorHeight * 255).clamp(0, 255).toInt();

        // B: Ceiling Height (0.0 - 1.0 mapped to 0 - 255)
        buffer[index + 2] = (cell.ceilingHeight * 255).clamp(0, 255).toInt();

        // A: Texture ID
        buffer[index + 3] = cell.textureId;
      }
    }

    final completer = Completer<ui.Image>();

    ui.decodeImageFromPixels(
      buffer,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );

    return completer.future;
  }
}
