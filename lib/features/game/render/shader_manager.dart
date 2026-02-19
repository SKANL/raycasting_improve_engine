import 'dart:ui' as ui;
import 'dart:ui';
import 'package:raycasting_game/core/logging/log_service.dart';

class ShaderManager {
  static FragmentProgram? _program;
  static bool get isLoaded => _program != null;

  static Future<void> load() async {
    try {
      _program = await FragmentProgram.fromAsset('shaders/raycaster.frag');
      LogService.info('RENDER', 'SHADER_LOADED', {
        'asset': 'shaders/raycaster.frag',
      });
      // ignore: avoid_catches_without_on_clauses - Shader loading can fail in various ways (missing file, compilation error, headless mode)
    } catch (e, stack) {
      LogService.error('RENDER', 'SHADER_LOAD_FAILED', e, stack);
    }
  }

  static Shader createShader({
    required double width,
    required double height,
    required double time,
    required double playerX,
    required double playerY,
    required double playerDir,
    required double fov,
    required double pitch,
    required double fogDistance,
    required List<double> lights,
    required int lightCount,
    required ui.Image mapTexture,
    required ui.Image atlasTexture,
  }) {
    if (_program == null) {
      throw Exception('Shader not loaded. Call ShaderManager.load() first.');
    }

    final shader = _program!.fragmentShader();

    // Set Scalars (0-7)
    shader.setFloat(0, width);
    shader.setFloat(1, height);
    shader.setFloat(2, time);
    shader.setFloat(3, playerX);
    shader.setFloat(4, playerY);
    shader.setFloat(5, playerDir);
    shader.setFloat(6, fov);
    shader.setFloat(7, pitch);

    // Set Ambient (vec4) - Indices 8, 9, 10, 11
    shader.setFloat(8, 0.2);
    shader.setFloat(9, 0.2);
    shader.setFloat(10, 0.3);
    shader.setFloat(11, 0); // Padding

    // Set Fog Distance (float) - Index 12
    shader.setFloat(12, fogDistance);

    // Set Lighting Params (vec4) - Indices 13, 14, 15, 16
    // x = uLightCount
    shader.setFloat(13, lightCount.toDouble());
    shader.setFloat(14, 0);
    shader.setFloat(15, 0);
    shader.setFloat(16, 0);

    // Set Lights (vec4 array) - Starts at 17
    for (var i = 0; i < lights.length; i++) {
      shader.setFloat(17 + i, lights[i]);
    }

    shader.setImageSampler(0, mapTexture);
    shader.setImageSampler(1, atlasTexture);

    return shader;
  }
}
