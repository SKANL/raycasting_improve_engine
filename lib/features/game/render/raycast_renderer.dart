import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_bloc/flame_bloc.dart';
// hide Image to avoid conflict with ui.Image
import 'package:raycasting_game/core/logging/log_service.dart';
import 'package:raycasting_game/features/core/ecs/components/render_component.dart';
import 'package:raycasting_game/features/core/ecs/components/transform_component.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/game/raycasting_game.dart';
import 'package:raycasting_game/features/game/render/shader_manager.dart';
import 'package:raycasting_game/features/game/render/vfx/particle_system.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

/// Renders the 3D raycasting view using data from WorldBloc.
class RaycastRenderer extends PositionComponent
    with
        HasGameReference<RaycastingGame>,
        FlameBlocListenable<WorldBloc, WorldState> {
  RaycastRenderer() : super(priority: -10);

  late final Paint _paint;
  double _time = 0;
  WorldState _latestState = const WorldState();
  final ParticleSystem _particleSystem = ParticleSystem();

  @override
  Future<void> onLoad() async {
    await ShaderManager.load();
    _paint = Paint();
  }

  @override
  void onNewState(WorldState state) {
    _latestState = state;
  }

  void spawnParticles(v64.Vector2 pos) {
    _particleSystem.emit(position: pos, count: 10, speed: 2);
  }

  @override
  void update(double dt) {
    _time += dt;
    _particleSystem.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (!ShaderManager.isLoaded) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF000000),
      );
      return;
    }
    try {
      if (_latestState.map == null) {
        _latestState = game.worldBloc.state;
      }

      final playerPos = _latestState.effectivePosition;
      final mapTexture = _latestState.mapTexture;
      final atlasTexture = _latestState.textureAtlas;

      if (mapTexture == null || atlasTexture == null) {
        return;
      }

      final config = game.perspectiveBloc.state.config;
      final planeLen = math.tan((config.fov * math.pi / 180) / 2);

      // Light Data Setup
      final lightData = <double>[];
      var activeLights = 0;
      final lights = _latestState.lights;
      for (final light in lights) {
        if (activeLights >= 8) break;
        lightData.add(light.position.dx);
        lightData.add(light.position.dy);
        lightData.add(light.radius);
        lightData.add(light.intensity);
        lightData.add(light.color.r);
        lightData.add(light.color.g);
        lightData.add(light.color.b);
        lightData.add(0);
        activeLights++;
      }

      final shader = ShaderManager.createShader(
        width: size.x,
        height: size.y,
        time: _time,
        playerX: playerPos.x,
        playerY: playerPos.y,
        playerDir: _latestState.playerDirection,
        fov: planeLen,
        pitch: config.pitch * 5.0,
        lights: lightData,
        lightCount: activeLights,
        mapTexture: mapTexture,
        atlasTexture: atlasTexture,
      );

      _paint.shader = shader;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _paint);

      // --- Sprite Rendering (Entities + Particles) ---
      final renderables = <_RenderableSprite>[];
      final v64Size = v64.Vector2(size.x, size.y);

      // 1. Entities
      if (_latestState.spriteAtlas != null) {
        for (final entity in _latestState.entities) {
          if (!entity.isActive) continue;
          final t = entity.getComponent<TransformComponent>();
          final r = entity.getComponent<RenderComponent>();
          if (t != null && r != null && r.isVisible) {
            renderables.add(
              _RenderableSprite(
                pos: t.position,
                texture: _latestState.spriteAtlas!,
                srcRect: const Rect.fromLTWH(0, 0, 32, 32),
                distSq: (_latestState.effectivePosition - t.position).length2,
              ),
            );
          }
        }
      }

      // 2. Particles
      if (_latestState.spriteAtlas != null) {
        for (final p in _particleSystem.particles) {
          renderables.add(
            _RenderableSprite(
              pos: p.position,
              texture: _latestState.spriteAtlas!,
              srcRect: p.textureRect,
              distSq: (_latestState.effectivePosition - p.position).length2,
              scale: p.scale,
            ),
          );
        }
      }

      // Sort Back-to-Front
      renderables.sort((a, b) => b.distSq.compareTo(a.distSq));

      // Draw
      for (final r in renderables) {
        _drawSprite(
          canvas,
          v64Size,
          _latestState,
          r.pos,
          r.texture,
          r.srcRect,
          planeLen,
          r.scale,
        );
      }
      // ignore: avoid_catches_without_on_clauses - Render loop must catch all exceptions to prevent app crash
    } catch (e, stack) {
      LogService.error('RENDER', 'FRAME_ERROR', e, stack);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFFFF0000),
      );
    }
  }

  void _drawSprite(
    Canvas canvas,
    v64.Vector2 screenSize,
    WorldState state,
    v64.Vector2 pos,
    Image texture,
    Rect srcRect,
    double planeLen,
    double scale,
  ) {
    final playerPos = state.effectivePosition;
    final playerDir = state.playerDirection;
    final spritePos = pos - playerPos;

    final planeX = -math.sin(playerDir) * planeLen;
    final planeY = math.cos(playerDir) * planeLen;
    final dirX = math.cos(playerDir);
    final dirY = math.sin(playerDir);

    final invDet = 1.0 / (planeX * dirY - dirX * planeY);
    final transformX = invDet * (dirY * spritePos.x - dirX * spritePos.y);
    final transformY = invDet * (-planeY * spritePos.x + planeX * spritePos.y);

    if (transformY <= 0) return;

    final spriteScreenX = (screenSize.x / 2) * (1 + transformX / transformY);
    final spriteHeight = (screenSize.y / transformY).abs() * scale;
    final spriteWidth =
        (screenSize.y / transformY).abs() * scale; // Assume square
    final spriteTop = (screenSize.y - spriteHeight) / 2;

    final dst = Rect.fromLTWH(
      spriteScreenX - spriteWidth / 2,
      spriteTop,
      spriteWidth,
      spriteHeight,
    );

    canvas.drawImageRect(texture, srcRect, dst, Paint());
  }
}

class _RenderableSprite {
  _RenderableSprite({
    required this.pos,
    required this.texture,
    required this.srcRect,
    required this.distSq,
    this.scale = 1.0,
  });
  final v64.Vector2 pos;
  final Image texture;
  final Rect srcRect;
  final double distSq;
  final double scale;
}
