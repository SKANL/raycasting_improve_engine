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
import 'package:raycasting_game/features/core/ecs/components/animation_component.dart';
import 'package:raycasting_game/features/game/weapon/models/ammo_type.dart';
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
  bool _hasLoggedRender = false;

  @override
  Future<void> onLoad() async {
    await ShaderManager.load();
    _paint = Paint();

    // Set size to match game viewport
    size = game.size.clone();

    LogService.info('RENDER', 'RENDERER_LOADED', {
      'size': '${size.x}x${size.y}',
    });
  }

  @override
  void onNewState(WorldState state) {
    // If we transition to empty/loading, clear the local visual caches!
    if (state.status == WorldStatus.initial ||
        state.status == WorldStatus.loading) {
      if (_latestState.status != state.status) {
        _particleSystem.clear();
        _projectileTrailTimers.clear();
        LogService.info('RENDER', 'VFX_CACHE_CLEARED', {});
      }
    }
    _latestState = state;
  }

  void spawnMuzzleFlash(v64.Vector2 position, double direction) {
    _particleSystem.emit(
      position: position,
      count: 15,
      speed: 3.0,
      life: 0.15,
      // Row 1 (y=32), Slot 3 (x=96) - Muzzle Flash
      textureRect: const Rect.fromLTWH(96, 32, 32, 32),
    );
  }

  void spawnParticles(v64.Vector2 pos) {
    _particleSystem.emit(position: pos, count: 10, speed: 2);
  }

  final Map<String, double> _projectileTrailTimers = {};

  @override
  void update(double dt) {
    _time += dt;
    _particleSystem.update(dt);

    // Trail Emitter
    for (final proj in _latestState.projectiles) {
      _projectileTrailTimers.putIfAbsent(proj.id, () => 0);
      final timer = _projectileTrailTimers[proj.id]! + dt;

      if (timer >= 0.05) {
        // Emit every 50ms
        _projectileTrailTimers[proj.id] = 0;

        final isBouncing = proj.ammoType == AmmoType.bouncing;
        final slotX = isBouncing ? 3 : 2;

        _particleSystem.emit(
          position: proj.position,
          count: 1,
          speed: 0, // Stationary trail
          life: 0.3,
          scale: 0.4,
          textureRect: Rect.fromLTWH(slotX * 32.0, 0, 32, 32),
          color: isBouncing
              ? const Color(0xAA00FF00)
              : const Color(0xAA00FFFF), // Green/Cyan tint
        );
      } else {
        _projectileTrailTimers[proj.id] = timer;
      }
    }

    // Cleanup old timers
    _projectileTrailTimers.removeWhere(
      (id, _) => !_latestState.projectiles.any((p) => p.id == id),
    );
  }

  @override
  void render(Canvas canvas) {
    if (!ShaderManager.isLoaded) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, game.size.x, game.size.y),
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
        LogService.warning('RENDER', 'MISSING_TEXTURES', {
          'mapTexture': mapTexture != null,
          'atlasTexture': atlasTexture != null,
        });
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
        width: game.size.x,
        height: game.size.y,
        time: _time,
        playerX: playerPos.x,
        playerY: playerPos.y,
        playerDir: _latestState.playerDirection,
        fov: planeLen,
        pitch: config.pitch * 5.0,
        fogDistance: 9.0,
        lights: lightData,
        lightCount: activeLights,
        mapTexture: mapTexture,
        atlasTexture: atlasTexture,
      );

      _paint.shader = shader;
      canvas.drawRect(Rect.fromLTWH(0, 0, game.size.x, game.size.y), _paint);

      // Debug: Log successful render once
      if (!_hasLoggedRender) {
        LogService.info('RENDER', 'FIRST_RENDER', {
          'canvasSize': '${size.x}x${size.y}',
          'playerPos': '${playerPos.x},${playerPos.y}',
          'lights': activeLights,
        });
        _hasLoggedRender = true;
      }

      // --- Sprite Rendering (Entities + Particles) ---
      final renderables = <_RenderableSprite>[];
      final v64Size = v64.Vector2(game.size.x, game.size.y);

      // 1. Entities
      if (_latestState.spriteAtlas != null) {
        for (final entity in _latestState.entities) {
          if (!entity.isActive) continue;
          final t = entity.getComponent<TransformComponent>();

          Rect? srcRect;
          double scale = 1.0;

          // Check for Animation first
          final anim = entity.getComponent<AnimationComponent>();

          double opacity = 1.0;
          final r = entity.getComponent<RenderComponent>();
          if (r != null) {
            opacity = r.opacity;
            // Scale based on RenderComponent width (default 32px tile)
            if (r.width > 0) {
              scale = r.width / 32.0;
            }
          }

          if (anim != null) {
            srcRect = anim.currentSprite;
          } else {
            // Fallback to RenderComponent
            if (r != null && r.isVisible) {
              // Assuming RenderComponent might have a fixed rect or use default
              // For now, hardcoded default if RenderComponent exists but no rect logic
              srcRect = const Rect.fromLTWH(0, 0, 32, 32);
            }
          }

          if (t != null && srcRect != null) {
            final sqDist =
                (_latestState.effectivePosition - t.position).length2;
            final dist = math.sqrt(sqDist);

            // CPU Fog Logic: Pre-calculate to avoid Raycast if invisible
            final maxFogDist = 5.0; // Same as shader fog distance
            final fogFactor =
                1.0 - math.exp(-math.pow(dist / (maxFogDist * 0.5), 2.0));
            final finalOpacity = math.max(0.0, opacity * (1.0 - fogFactor));

            // Early cull: Don't process DDA or draw if invisible due to fog
            if (finalOpacity > 0.05) {
              // OCCLUSION CHECK
              if (_isSpriteVisible(_latestState, t.position)) {
                renderables.add(
                  _RenderableSprite(
                    pos: t.position,
                    texture: _latestState.spriteAtlas!,
                    srcRect: srcRect,
                    distSq: sqDist,
                    scale: scale,
                    opacity: finalOpacity,
                  ),
                );
              }
            }
          }
        }
      }

      // 2. Particles
      if (_latestState.spriteAtlas != null) {
        for (final p in _particleSystem.particles) {
          final sqDist = (_latestState.effectivePosition - p.position).length2;
          final dist = math.sqrt(sqDist);

          // CPU Fog Logic
          final maxFogDist = 5.0;
          final fogFactor =
              1.0 - math.exp(-math.pow(dist / (maxFogDist * 0.5), 2.0));
          final finalOpacity = math.max(0.0, 1.0 * (1.0 - fogFactor));

          if (finalOpacity > 0.05) {
            // Occlusion check only if visible through fog
            if (_isSpriteVisible(_latestState, p.position)) {
              renderables.add(
                _RenderableSprite(
                  pos: p.position,
                  texture: _latestState.spriteAtlas!,
                  srcRect: p.textureRect,
                  distSq: sqDist,
                  scale: p.scale,
                  opacity: finalOpacity,
                ),
              );
            }
          }
        }
      }

      // 3. Projectiles
      if (_latestState.spriteAtlas != null) {
        for (final proj in _latestState.projectiles) {
          final sqDist =
              (_latestState.effectivePosition - proj.position).length2;
          final maxDistanceSq = 5.0 * 5.0; // Fast squared fog distance check

          if (sqDist < maxDistanceSq) {
            if (_isSpriteVisible(_latestState, proj.position)) {
              // SlotX = 2 for normal, 3 for bouncing
              final slotX = (proj.ammoType == AmmoType.normal) ? 2 : 3;

              final srcRect = Rect.fromLTWH(slotX * 32.0, 0, 32, 32);

              // GLOW/HALO (Back)
              renderables.add(
                _RenderableSprite(
                  pos: proj.position,
                  texture: _latestState.spriteAtlas!,
                  srcRect: srcRect,
                  distSq: sqDist,
                  scale: 1.2, // Larger
                  opacity: 0.4, // Transparent
                ),
              );

              // CORE (Front)
              renderables.add(
                _RenderableSprite(
                  pos: proj.position,
                  texture: _latestState.spriteAtlas!,
                  srcRect: srcRect,
                  distSq: sqDist - 0.01, // Slight bias to draw in front
                  scale: 0.6,
                ),
              );
            }
          }
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
          r.opacity,
          r.color,
        );
      }

      // 4. Draw Weapon View-Model
      if (_latestState.weaponAtlas != null) {
        _drawWeapon(canvas, v64Size);
      }

      // ignore: avoid_catches_without_on_clauses - Render loop must catch all exceptions to prevent app crash
    } catch (e, stack) {
      LogService.error('RENDER', 'FRAME_ERROR', e, stack);
      LogService.error('RENDER', 'FRAME_ERROR', e, stack);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, game.size.x, game.size.y),
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
    double opacity,
    Color? color,
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

    // Relaxed clipping: allow sprites to get very close (0.1) before rejection
    // This prevents "popping" too early when walking into them.
    if (transformY <= 0.1) return;

    final spriteScreenX = (screenSize.x / 2) * (1 + transformX / transformY);

    // [FIX] Clamp transformY for dimension scaling to avoid >10,000px rects
    // that crash the rasterizer when enemies get very close to the camera.
    final sizeTransformY = math.max(0.4, transformY.abs());

    final spriteHeight = (screenSize.y / sizeTransformY) * scale;
    final spriteWidth = spriteHeight; // Assume square
    final spriteTop = (screenSize.y - spriteHeight) / 2;

    final dst = Rect.fromLTWH(
      spriteScreenX - spriteWidth / 2,
      spriteTop,
      spriteWidth,
      spriteHeight,
    );

    final paint = Paint()..color = const Color(0xFFFFFFFF).withOpacity(opacity);
    if (color != null) {
      paint.colorFilter = ColorFilter.mode(color, BlendMode.modulate);
    }

    canvas.drawImageRect(texture, srcRect, dst, paint);
  }

  void _drawWeapon(Canvas canvas, v64.Vector2 screenSize) {
    final weaponState = game.weaponBloc.state;
    final weapon = weaponState.currentWeapon;
    final atlas = _latestState.weaponAtlas!;

    // Map weapon ID to atlas index
    int index = 0;
    switch (weapon.id) {
      case 'pistol':
        index = 0;
        break;
      case 'shotgun':
        index = 1;
        break;
      case 'rifle':
        index = 2;
        break;
      case 'bounce_pistol':
        index = 3;
        break;
      case 'bounce_rifle':
        index = 4;
        break;
      default:
        index = 0;
    }

    const spriteSize = 64.0;
    final srcRect = Rect.fromLTWH(
      index * spriteSize,
      0,
      spriteSize,
      spriteSize,
    );

    // Scale up for view model
    final scale = 4.0;
    final drawWidth = spriteSize * scale;
    final drawHeight = spriteSize * scale;

    // Bobbing effect when moving
    // We need input bloc or velocity?
    // Let's use simplified bobbing based on time if moving?
    // For now, static or simple breathing.
    final bobOffset = math.sin(_time * 5) * 5.0;

    final dstRect = Rect.fromLTWH(
      (screenSize.x - drawWidth) / 2,
      screenSize.y - drawHeight + bobOffset, // Anchor to bottom
      drawWidth,
      drawHeight,
    );

    canvas.drawImageRect(atlas, srcRect, dstRect, Paint());
  }

  /// Checks if a sprite at [target] is visible from the player's position
  /// by performing a DDA raycast against the map.
  bool _isSpriteVisible(WorldState state, v64.Vector2 target) {
    if (state.map == null) return true;
    final map = state.map!;
    final start = state.effectivePosition;

    final direction = target - start;
    final distance = direction.length;

    // Normalize
    final dirX = direction.x / distance;
    final dirY = direction.y / distance;

    // DDA Setup
    var mapX = start.x.floor();
    var mapY = start.y.floor();

    final deltaDistX = (dirX == 0) ? 1e30 : (1 / dirX).abs();
    final deltaDistY = (dirY == 0) ? 1e30 : (1 / dirY).abs();

    var stepX = 0;
    var sideDistX = 0.0;
    if (dirX < 0) {
      stepX = -1;
      sideDistX = (start.x - mapX) * deltaDistX;
    } else {
      stepX = 1;
      sideDistX = (mapX + 1.0 - start.x) * deltaDistX;
    }

    var stepY = 0;
    var sideDistY = 0.0;
    if (dirY < 0) {
      stepY = -1;
      sideDistY = (start.y - mapY) * deltaDistY;
    } else {
      stepY = 1;
      sideDistY = (mapY + 1.0 - start.y) * deltaDistY;
    }

    // Cast Ray
    // We stop 0.5 units before the target to allow seeing it if it's "in" a wall?
    // No, sprites are usually in empty space. We scan up to the target.
    // Optimization: Don't scan infinite, just up to target distance.

    // var currentDist = 0.0; // Unused

    // Pre-calculate target map coordinates to avoid flooring in the hot loop
    final targetMapX = target.x.floor();
    final targetMapY = target.y.floor();

    // Max steps safety
    var steps = 0;
    const maxSteps = 50;

    while (steps < maxSteps) {
      // Advance ray
      if (sideDistX < sideDistY) {
        sideDistX += deltaDistX;
        mapX += stepX;
      } else {
        sideDistY += deltaDistY;
        mapY += stepY;
      }

      if (map.getCell(mapX, mapY).isSolid) {
        return false; // Wall hit! Occluded.
      }

      // Check if we reached the target cell
      if (mapX == targetMapX && mapY == targetMapY) {
        return true; // Reached target without hitting wall
      }

      steps++;
    }

    return true; // Fallback
  }
}

class _RenderableSprite {
  _RenderableSprite({
    required this.pos,
    required this.texture,
    required this.srcRect,
    required this.distSq,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.color,
  });
  final v64.Vector2 pos;
  final Image texture;
  final Rect srcRect;
  final double distSq;
  final double scale;
  final double opacity;
  final Color? color;
}
