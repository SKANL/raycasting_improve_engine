import 'dart:ui' as ui;
import 'dart:ui';
import 'package:raycasting_game/core/logging/log_service.dart';

/// Manages the GLSL fragment shader for raycasting.
///
/// OPT: The [FragmentShader] instance is created ONCE on [load] and reused
/// every frame. Only uniforms are updated via [setFloat]/[setImageSampler].
/// This eliminates one heap allocation + GPU program-state setup per frame
/// (was 60 allocs/sec), reducing both GC pressure and driver overhead.
class ShaderManager {
  static FragmentProgram? _program;

  /// Cached shader instance — updated each frame, never recreated.
  static FragmentShader? _cachedShader;

  static bool get isLoaded => _cachedShader != null;

  static Future<void> load() async {
    try {
      _program = await FragmentProgram.fromAsset('shaders/raycaster.frag');
      // Create the shader instance ONCE. We will re-use this same object
      // every frame, only updating its uniform values.
      _cachedShader = _program!.fragmentShader();
      LogService.info('RENDER', 'SHADER_LOADED', {
        'asset': 'shaders/raycaster.frag',
      });
      // ignore: avoid_catches_without_on_clauses - Shader loading can fail in various ways (missing file, compilation error, headless mode)
    } catch (e, stack) {
      LogService.error('RENDER', 'SHADER_LOAD_FAILED', e, stack);
    }
  }

  /// Updates the cached [FragmentShader] uniforms and returns it.
  ///
  /// No new shader object is allocated — the same GPU program state is
  /// updated in-place and drawn from.
  static Shader updateAndGetShader({
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
    if (_cachedShader == null) {
      throw Exception('Shader not loaded. Call ShaderManager.load() first.');
    }

    final shader = _cachedShader!;

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
    // OPT: Only iterate over active lights (lightCount * 8 floats).
    // Unused slots retain their previous values, which the shader ignores
    // because the loop breaks at `i >= int(uLightingParams.x)`.
    final activeFloats = lightCount * 8;
    for (var i = 0; i < activeFloats; i++) {
      shader.setFloat(17 + i, lights[i]);
    }

    // Sampler updates are cheap — image handles are just references.
    shader.setImageSampler(0, mapTexture);
    shader.setImageSampler(1, atlasTexture);

    return shader;
  }
}
