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
import 'package:raycasting_game/features/core/ecs/components/pickup_component.dart';
import 'package:raycasting_game/features/game/models/projectile.dart';
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

  // OPT: Pre-allocated light data buffer — no heap allocation per frame.
  // Layout per light (8 floats): posX, posY, radius, intensity, r, g, b, pad
  // Max 8 lights × 8 floats = 64 slots. Buffer is zero-initialised once.
  static const int _maxLights = 8;
  final List<double> _lightData = List<double>.filled(_maxLights * 8, 0.0);

  // OPT: Player direction trig cached once per render() call.
  // Every _drawSprite() uses these — avoids redundant cos/sin invocations.
  double _cachedDirX = 1.0;
  double _cachedDirY = 0.0;

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
        _bounceFlashes.clear();
        _wallDecals.clear();
        _muzzleFlashTimer = 0.0;
        // Also invalidate weapon picture so it's re-baked with the new screen size.
        _cachedWeaponPicture?.dispose();
        _cachedWeaponPicture = null;
        _cachedWeaponId = '';
        _equipT = 0.0; // play equip animation on next game start
        _aimT        = 0.0;
        _aimCooldown = 0.0;
        LogService.info('RENDER', 'VFX_CACHE_CLEARED', {});
      }
    }
    _latestState = state;
  }

  void spawnMuzzleFlash(v64.Vector2 position, double direction) {
    // Screen-space flash — no world-space particle blob.
    _muzzleFlashTimer = _muzzleFlashDuration;
  }

  /// Spawns a canvas-primitive bounce spark at the given world position.
  void spawnBounceEffect(v64.Vector2 worldPos) {
    _bounceFlashes.add((pos: worldPos.clone(), timer: 0.25));
  }

  /// Spawns a wall-impact decal at the given world position. Capped at 64.
  void spawnWallDecal(v64.Vector2 worldPos) {
    if (_wallDecals.length < 64) {
      _wallDecals.add((pos: worldPos.clone(), timer: _wallDecalDuration));
    }
  }

  void spawnParticles(v64.Vector2 pos) {
    _particleSystem.emit(position: pos, count: 10, speed: 2);
  }

  final Map<String, double> _projectileTrailTimers = {};

  // Screen-space muzzle flash (replaces world-space particle blob).
  double _muzzleFlashTimer = 0.0;
  static const double _muzzleFlashDuration = 0.12;

  // Bounce impact sparks: list of (worldPos, remaining life).
  final List<({v64.Vector2 pos, double timer})> _bounceFlashes = [];

  // Wall impact decals: bullet marks that fade over 8 seconds.
  final List<({v64.Vector2 pos, double timer})> _wallDecals = [];
  static const double _wallDecalDuration = 8.0;

  // Weapon viewmodel picture cache: baked once per weapon change, replayed
  // each frame with a cheap canvas.translate(0, bob) — avoids 40+ draw calls/frame.
  Picture? _cachedWeaponPicture;
  String   _cachedWeaponId   = '';
  double   _cachedWeaponW    = 0;
  double   _cachedWeaponH    = 0;

  // Equip animation: 0.0 = weapon lateral/holstered → 1.0 = in firing position.
  // Driven by the Flame game loop (update dt), no AnimationController needed.
  double _equipT = 1.0; // starts at 1 so the first frame is already in position
  static const double _equipDuration = 0.42; // seconds (easeOutCubic)

  // Carry ↔ Aim transition:
  //   0.0 = low-ready carry  (barrel pointing down  — image-2 reference)
  //   1.0 = aimed / firing   (barrel on crosshair   — image-3 reference)
  // Rises instantly when the player fires; slowly lowers after _aimReturnDelay.
  double _aimT        = 0.0;
  double _aimCooldown = 0.0;
  static const double _aimReturnDelay = 1.2;  // seconds before lowering
  static const double _aimReturnSpeed = 3.0;  // speed of lowering (t/s)

  @override
  void update(double dt) {
    _time += dt;
    _particleSystem.update(dt);

    // Advance equip animation.
    if (_equipT < 1.0) {
      _equipT = (_equipT + dt / _equipDuration).clamp(0.0, 1.0);
    }

    // Carry ↔ Aim: snap to aimed on fire, slowly return to carry after delay.
    if (_muzzleFlashTimer > 0) {
      _aimT        = 1.0;
      _aimCooldown = _aimReturnDelay;
    } else if (_aimT > 0.0) {
      if (_aimCooldown > 0) {
        _aimCooldown -= dt;
      } else {
        _aimT = math.max(0.0, _aimT - dt * _aimReturnSpeed);
      }
    }

    // Trail Emitter — only for plasma/bolt (tracers render their own tail).
    for (final proj in _latestState.projectiles) {
      if (proj.renderStyle == ProjectileRenderStyle.tracer) continue;

      _projectileTrailTimers.putIfAbsent(proj.id, () => 0);
      final timer = _projectileTrailTimers[proj.id]! + dt;

      if (timer >= 0.06) {
        _projectileTrailTimers[proj.id] = 0;
        final isBouncing = proj.ammoType == AmmoType.bouncing;
        final slotX = isBouncing ? 3 : 2;
        _particleSystem.emit(
          position: proj.position,
          count: 1,
          speed: 0,
          life: 0.25,
          scale: 0.25, // smaller — not a giant blob
          textureRect: Rect.fromLTWH(slotX * 32.0, 0, 32, 32),
          color: proj.isEnemy
              ? const Color(0x88FF5500)
              : (isBouncing
                  ? const Color(0x8800FF44)
                  : const Color(0x8800CCFF)),
        );
      } else {
        _projectileTrailTimers[proj.id] = timer;
      }
    }

    // Cleanup old timers
    _projectileTrailTimers.removeWhere(
      (id, _) => !_latestState.projectiles.any((p) => p.id == id),
    );

    // Tick screen-space muzzle flash timer.
    if (_muzzleFlashTimer > 0) {
      _muzzleFlashTimer = math.max(0.0, _muzzleFlashTimer - dt);
    }

    // Tick bounce sparks: age in-place, then remove expired entries.
    for (var i = _bounceFlashes.length - 1; i >= 0; i--) {
      final f = _bounceFlashes[i];
      final remaining = f.timer - dt;
      if (remaining <= 0) {
        _bounceFlashes.removeAt(i);
      } else {
        _bounceFlashes[i] = (pos: f.pos, timer: remaining);
      }
    }

    // Tick wall decals: fade over _wallDecalDuration seconds.
    for (var i = _wallDecals.length - 1; i >= 0; i--) {
      final d = _wallDecals[i];
      final remaining = d.timer - dt;
      if (remaining <= 0) {
        _wallDecals.removeAt(i);
      } else {
        _wallDecals[i] = (pos: d.pos, timer: remaining);
      }
    }
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

      // OPT: Cache player direction trig for this frame.
      // Used in _drawSprite × N and frustum culling below — compute once.
      final playerDir = _latestState.playerDirection;
      _cachedDirX = math.cos(playerDir);
      _cachedDirY = math.sin(playerDir);

      // OPT: Fill pre-allocated light buffer in-place (no List allocation).
      var activeLights = 0;
      for (final light in _latestState.lights) {
        if (activeLights >= _maxLights) break;
        final base = activeLights * 8;
        _lightData[base]     = light.position.dx;
        _lightData[base + 1] = light.position.dy;
        _lightData[base + 2] = light.radius;
        _lightData[base + 3] = light.intensity;
        _lightData[base + 4] = light.color.r;
        _lightData[base + 5] = light.color.g;
        _lightData[base + 6] = light.color.b;
        _lightData[base + 7] = 0.0;
        activeLights++;
      }

      final shader = ShaderManager.updateAndGetShader(
        width: game.size.x,
        height: game.size.y,
        time: _time,
        playerX: playerPos.x,
        playerY: playerPos.y,
        playerDir: playerDir,
        fov: planeLen,
        pitch: config.pitch * 5.0,
        fogDistance: 9.0,
        lights: _lightData,
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
      final pickupsToDraw = <({v64.Vector2 pos, PickupComponent pickup, double distSq})>[];
      final v64Size = v64.Vector2(game.size.x, game.size.y);

      // 1. Entities
      if (_latestState.spriteAtlas != null) {
        for (final entity in _latestState.entities) {
          if (!entity.isActive) continue;
          final t = entity.getComponent<TransformComponent>();

          // Ammo pickups are canvas-primitive drawn — skip normal billboard path.
          final pickup = entity.getComponent<PickupComponent>();
          if (pickup != null && t != null) {
            final delta = t.position - _latestState.effectivePosition;
            final camDot = _cachedDirX * delta.x + _cachedDirY * delta.y;
            // Occlusion: same wall-DDA check used for enemies — pickups must
            // NOT be visible through walls.
            if (camDot > 0.1 && _isSpriteVisible(_latestState, t.position)) {
              pickupsToDraw.add((pos: t.position, pickup: pickup, distSq: delta.length2));
            }
            continue;
          }

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
            final spriteDelta = t.position - _latestState.effectivePosition;
            final sqDist = spriteDelta.length2;
            final dist = math.sqrt(sqDist);

            // OPT: Frustum culling — reject sprites behind the camera plane
            // with a cheap dot-product before running the more expensive DDA.
            // camDot = projection of sprite direction onto camera forward vector.
            final camDot = _cachedDirX * spriteDelta.x + _cachedDirY * spriteDelta.y;
            if (camDot <= 0.05) continue; // Behind or exactly on camera plane

            // OPT: Also reject sprites far off to the side (outside ~120° FOV).
            // Uses |perpComponent / camDot| > threshold without trig.
            final perpAbs = (_cachedDirX * spriteDelta.y - _cachedDirY * spriteDelta.x).abs();
            if (perpAbs > camDot * 2.0) continue; // Outside ~63° half-angle

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

      // 3. Projectiles — ALL drawn as canvas primitives (no billboard sprites).
      // Tracers: perspective-correct streak with minimum 30 px screen length.
      // Plasma/bolt: depth-scaled glow circle hard-capped at 24 px radius.
      final tracersToDraw = <Projectile>[];
      final plasmasToDraw  = <Projectile>[];
      for (final proj in _latestState.projectiles) {
        final sqDist = (_latestState.effectivePosition - proj.position).length2;
        // Use fog distance squared as culling limit (9 u = ~81 sq)
        if (sqDist >= 81.0) continue;
        if (!_isSpriteVisible(_latestState, proj.position)) continue;
        if (proj.renderStyle == ProjectileRenderStyle.tracer) {
          tracersToDraw.add(proj);
        } else {
          plasmasToDraw.add(proj);
        }
      }

      // Sort Back-to-Front
      renderables.sort((a, b) => b.distSq.compareTo(a.distSq));

      // Draw sprites
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
          null,
        );
      }

      // 4a. Draw plasma orbs (depth-scaled additive circles).
      for (final proj in plasmasToDraw) {
        _drawPlasmaOrb(canvas, v64Size, _latestState, proj, planeLen);
      }

      // 4b. Draw tracer streaks LAST — additive, composites on top.
      for (final proj in tracersToDraw) {
        _drawBulletStreak(canvas, v64Size, _latestState, proj, planeLen);
      }

      // 5. Draw Weapon View-Model
      if (_latestState.weaponAtlas != null) {
        _drawWeapon(canvas, v64Size);
      }

      // 6. Screen-space muzzle flash overlay (no world coords — no blob).
      if (_muzzleFlashTimer > 0) {
        _drawScreenSpaceMuzzleFlash(
            canvas, v64Size, _muzzleFlashTimer / _muzzleFlashDuration);
      }

      // 7. Bounce-impact sparks (world-projected canvas primitives).
      for (final f in _bounceFlashes) {
        _drawBounceSpark(canvas, v64Size, _latestState, f.pos, f.timer / 0.25, planeLen);
      }

      // 8. Ammo pickups — canvas-primitive orbs/boxes at world positions.
      for (final p in pickupsToDraw) {
        _drawAmmoPickup(canvas, v64Size, _latestState, p.pos, p.pickup, planeLen);
      }

      // 9. Wall decals — bullet impact marks that fade over time.
      for (final d in _wallDecals) {
        _drawWallDecal(canvas, v64Size, _latestState, d.pos, d.timer / _wallDecalDuration, planeLen);
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
    final spritePos = pos - playerPos;

    // OPT: Use pre-cached trig values computed once per render() pass.
    final planeX = -_cachedDirY * planeLen;
    final planeY = _cachedDirX * planeLen;
    final dirX = _cachedDirX;
    final dirY = _cachedDirY;

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

  // ── Weapon Viewmodel ─────────────────────────────────────────────────────
  // The weapon geometry is expensive (~40 draw calls). We bake it into a
  // ui.Picture once per weapon-change (or screen-size change), then replay it
  // each frame with only a cheap canvas.translate for the breathing bob.
  void _drawWeapon(Canvas canvas, v64.Vector2 screenSize) {
    final weapon = game.weaponBloc.state.currentWeapon;
    final w = screenSize.x;
    final h = screenSize.y;

    // Invalidate cache when weapon changes or viewport is resized.
    if (_cachedWeaponId != weapon.id ||
        _cachedWeaponW  != w ||
        _cachedWeaponH  != h) {
      // Dispose old GPU resource before replacing.
      _cachedWeaponPicture?.dispose();
      _cachedWeaponId = weapon.id;
      _cachedWeaponW  = w;
      _cachedWeaponH  = h;
      final recorder = PictureRecorder();
      final c = Canvas(recorder);
      // Bake at rest position; all animation applied as canvas transforms.
      _bakeWeapon(c, weapon.id, w, h);
      _cachedWeaponPicture = recorder.endRecording();
      // Trigger equip animation on every weapon switch.
      _equipT = 0.0;
    }

    // ── Equip + Carry/Aim combined transform ────────────────────────────────
    // Curve both progress values with easeOutCubic.
    final tE    = 1.0 - math.pow(1.0 - _equipT,  3.0) as double; // equip
    final tAim  = 1.0 - math.pow(1.0 - _aimT,    3.0) as double; // carry↔aim

    // --- Angle ---
    // kAngleStart : -90° weapon enters laterally from the right side
    // kAngleCarry : +22° low-ready carry — barrel pointing slightly down (image 2)
    // kAngleAim   :  -5° aimed          — barrel on the crosshair           (image 3)
    const kAngleStart = -math.pi * 0.5;      // −90°
    const kAngleCarry =  math.pi * 0.122;    // +22° (barrel down, low-ready)
    const kAngleAim   = -math.pi * 0.028;    //  −5° (barrel at crosshair)

    // Carry ↔ aim interpolation.
    final kAngleFinal = kAngleCarry + (kAngleAim - kAngleCarry) * tAim;
    // Equip: start lateral → final settled angle.
    final angle = kAngleStart + (kAngleFinal - kAngleStart) * tE;

    // --- Vertical offset ---
    // Equip raise: weapon rises from below the screen into position.
    final equipPush = h * 0.32 * (1.0 - tE);
    // Carry lower: weapon drops h*0.10 in low-ready; rises to 0 when aiming.
    final carryPush = h * 0.10 * (1.0 - tAim) * tE; // only after equip settles
    // Breathing bob: fades in once equip completes, suppressed while aiming.
    final bobAmp    = 3.5 * math.min(1.0, _equipT * 4.0) * (1.0 - tAim * 0.6);
    final bob       = math.sin(_time * 2.5) * bobAmp;

    final push = equipPush + carryPush + bob;

    // Pivot at the weapon grip — consistent across pistol / shotgun / rifle.
    const pivotFx = 0.72;
    const pivotFy = 0.82;
    final pivotX  = w * pivotFx;
    final pivotY  = h * pivotFy;

    // Apply transform: rotate around grip pivot + push.
    canvas.save();
    canvas.translate(pivotX, pivotY + push);
    canvas.rotate(angle);
    canvas.translate(-pivotX, -pivotY);
    canvas.drawPicture(_cachedWeaponPicture!);
    canvas.restore();
  }

  /// Dispatches to the correct per-weapon draw method.
  /// Called only when the cache is invalidated — NOT every frame.
  void _bakeWeapon(Canvas canvas, String id, double w, double h) {
    switch (id) {
      case 'pistol':       _vmPistol(canvas, w, h, bounce: false);
      case 'bounce_pistol':_vmPistol(canvas, w, h, bounce: true);
      case 'shotgun':      _vmShotgun(canvas, w, h);
      case 'rifle':        _vmRifle(canvas, w, h, bounce: false);
      case 'bounce_rifle': _vmRifle(canvas, w, h, bounce: true);
    }
  }

  /// Pistol / Bounce-Pistol viewmodel (right-hand, barrel pointing upper-left).
  // ignore: long-method
  void _vmPistol(Canvas canvas, double w, double h, {required bool bounce}) {
    Paint f(Color c) => Paint()..color = c;
    Paint mgv(Rect r, Color d, Color m, Color l) => Paint()
      ..shader = Gradient.linear(r.topLeft, r.bottomLeft, [d, m, l], [0.0, 0.45, 1.0]);

    final Color bodyDark = bounce ? const Color(0xFF0A1E1A) : const Color(0xFF181818);
    final Color bodyMid  = bounce ? const Color(0xFF1A4A3A) : const Color(0xFF3C3C3C);
    final Color bodyLite = bounce ? const Color(0xFF2A6A55) : const Color(0xFF666666);
    const glowGreen = Color(0xFF00FF88);
    const glowBlue  = Color(0xFF00AAFF);
    final glowC = bounce ? glowGreen : glowBlue;

    // 1. Barrel ──────────────────────────────────────────────────────────────
    final barR = Rect.fromLTWH(w * 0.20, h * 0.632, w * 0.382, h * 0.030);
    canvas.drawRect(barR, mgv(barR, const Color(0xFF1C1C1C), const Color(0xFF545454), const Color(0xFF2A2A2A)));
    // top-edge highlight
    canvas.drawRect(Rect.fromLTWH(w * 0.20, h * 0.632, w * 0.382, h * 0.004), f(const Color(0x55FFFFFF)));
    // energy coil rings on bounce barrel
    if (bounce) {
      for (var i = 0; i < 3; i++) {
        final cx = w * 0.27 + i * w * 0.098;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, h * 0.647), width: w * 0.026, height: h * 0.030),
          f(glowGreen)..style = PaintingStyle.stroke..strokeWidth = 1.8..blendMode = BlendMode.plus,
        );
      }
    }
    // Muzzle cap
    canvas.drawRect(
        Rect.fromLTWH(w * 0.186, h * 0.630, w * 0.016, h * 0.034), f(const Color(0xFF111111)));
    canvas.drawCircle(Offset(w * 0.194, h * 0.647), h * 0.008, f(const Color(0xFF050505)));
    // Front sight post (above barrel tip)
    canvas.drawRect(
        Rect.fromLTWH(w * 0.228, h * 0.617, w * 0.009, h * 0.015), f(const Color(0xFFDDDDDD)));

    // 2. Slide / Receiver ──────────────────────────────────────────────────
    final slideR = Rect.fromLTWH(w * 0.500, h * 0.601, w * 0.226, h * 0.104);
    canvas.drawRRect(
      RRect.fromRectAndRadius(slideR, const Radius.circular(3)),
      mgv(slideR, bodyDark, bodyMid, bodyLite),
    );
    // Ejection port
    canvas.drawRect(
        Rect.fromLTWH(w * 0.604, h * 0.632, w * 0.066, h * 0.038), f(const Color(0xFF080808)));
    // Rear serrations
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(
        Offset(w * 0.694 + i * w * 0.008, h * 0.606),
        Offset(w * 0.694 + i * w * 0.008, h * 0.694),
        f(const Color(0xFF222222))..strokeWidth = w * 0.003,
      );
    }
    // Rear sight notch
    canvas.drawRect(
        Rect.fromLTWH(w * 0.708, h * 0.600, w * 0.026, h * 0.010), f(const Color(0xFF888888)));
    canvas.drawRect(
        Rect.fromLTWH(w * 0.718, h * 0.600, w * 0.010, h * 0.008), f(const Color(0xFF111111)));
    // Bounce glow panel on slide
    if (bounce) {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.510, h * 0.612, w * 0.200, h * 0.014),
        f(const Color(0x5500FF88))..blendMode = BlendMode.plus,
      );
    }
    // Slide top highlight
    canvas.drawRect(
        Rect.fromLTWH(w * 0.500, h * 0.601, w * 0.226, h * 0.008), f(const Color(0x33FFFFFF)));
    // Bounce: trigger color tint
    if (bounce) {
      canvas.drawRect(Rect.fromLTWH(w * 0.502, h * 0.613, w * 0.018, h * 0.010),
          f(glowC)..blendMode = BlendMode.plus);
    }

    // 3. Grip ────────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        w * 0.596, h * 0.705, w * 0.696, h * 1.02,
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
      f(bounce ? const Color(0xFF101A18) : const Color(0xFF141414)),
    );
    // Stippling
    for (var gy = 0; gy < 5; gy++) {
      for (var gx = 0; gx < 3; gx++) {
        canvas.drawCircle(
          Offset(w * 0.614 + gx * w * 0.024, h * 0.730 + gy * h * 0.038),
          h * 0.004,
          f(const Color(0xFF272727)),
        );
      }
    }
    if (bounce) {
      canvas.drawRect(Rect.fromLTWH(w * 0.596, h * 0.762, w * 0.100, h * 0.012),
          f(const Color(0x8800FF88)));
    }

    // 4. Trigger guard arc ──────────────────────────────────────────────────
    canvas.drawArc(
      Rect.fromLTWH(w * 0.566, h * 0.700, w * 0.088, h * 0.060),
      0, math.pi, false,
      f(const Color(0xFF111111))..style = PaintingStyle.stroke..strokeWidth = w * 0.005,
    );
    // Trigger
    canvas.drawLine(
      Offset(w * 0.610, h * 0.706), Offset(w * 0.604, h * 0.740),
      f(const Color(0xFF555555))..strokeWidth = w * 0.004,
    );
  }

  /// Shotgun viewmodel (centered, dual barrels pointing upward, wood stock).
  // ignore: long-method
  void _vmShotgun(Canvas canvas, double w, double h) {
    Paint f(Color c) => Paint()..color = c;
    Paint mgv(Rect r, Color d, Color m, Color l) => Paint()
      ..shader = Gradient.linear(r.topLeft, r.bottomLeft, [d, m, l], [0.0, 0.5, 1.0]);
    Paint mgh(Rect r, Color d, Color m, Color l) => Paint()
      ..shader = Gradient.linear(r.topLeft, r.topRight, [d, m, l], [0.0, 0.5, 1.0]);

    // 1. Dual barrels ─────────────────────────────────────────────────────
    for (var side = 0; side < 2; side++) {
      final bx = w * 0.380 + side * w * 0.116;
      final bw2 = w * 0.102;
      final bRect = Rect.fromLTWH(bx, h * 0.360, bw2, h * 0.393);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bRect, const Radius.circular(4)),
        mgv(bRect, const Color(0xFF1C1C1C), const Color(0xFF585858), const Color(0xFF3A3A3A)),
      );
      // Barrel edge highlight
      canvas.drawRect(Rect.fromLTWH(bx, h * 0.360, bw2, h * 0.007),
          f(const Color(0x44FFFFFF)));
      // Muzzle hole
      canvas.drawOval(
        Rect.fromLTWH(bx + bw2 * 0.14, h * 0.352, bw2 * 0.72, h * 0.030),
        f(const Color(0xFF060606)),
      );
      canvas.drawOval(
        Rect.fromLTWH(bx + bw2 * 0.10, h * 0.350, bw2 * 0.80, h * 0.034),
        f(const Color(0xFF606060))..style = PaintingStyle.stroke..strokeWidth = 2,
      );
    }
    // Rib between barrels
    canvas.drawRect(
        Rect.fromLTWH(w * 0.481, h * 0.360, w * 0.012, h * 0.393), f(const Color(0xFF888888)));

    // 2. Barrel band (metal ring) ─────────────────────────────────────────
    final bandR = Rect.fromLTWH(w * 0.372, h * 0.584, w * 0.232, h * 0.026);
    canvas.drawRect(bandR, mgh(bandR, const Color(0xFF3A3A3A), const Color(0xFF888888), const Color(0xFF4A4A4A)));
    canvas.drawRect(Rect.fromLTWH(w * 0.372, h * 0.584, w * 0.232, h * 0.006),
        f(const Color(0x33FFFFFF)));

    // 3. Pump fore-grip (wood) ────────────────────────────────────────────
    final pumpR = Rect.fromLTWH(w * 0.366, h * 0.756, w * 0.244, h * 0.070);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pumpR, const Radius.circular(5)),
      mgh(pumpR, const Color(0xFF3A1A06), const Color(0xFF7A4015), const Color(0xFF3A1A06)),
    );
    for (var i = 0; i < 7; i++) {
      final lx = w * 0.378 + i * w * 0.028;
      canvas.drawLine(Offset(lx, h * 0.760), Offset(lx, h * 0.822),
          f(const Color(0xFF2A0E03))..strokeWidth = w * 0.006);
    }
    canvas.drawRect(Rect.fromLTWH(w * 0.366, h * 0.756, w * 0.244, h * 0.010),
        f(const Color(0x33FFFFFF)));

    // 4. Receiver / action ────────────────────────────────────────────────
    final recR = Rect.fromLTWH(w * 0.356, h * 0.826, w * 0.262, h * 0.080);
    canvas.drawRect(recR, mgv(recR, const Color(0xFF252525), const Color(0xFF505050), const Color(0xFF303030)));
    canvas.drawRect(Rect.fromLTWH(w * 0.356, h * 0.826, w * 0.262, h * 0.010),
        f(const Color(0x33FFFFFF)));
    // Trigger guard arc
    canvas.drawArc(
      Rect.fromLTWH(w * 0.397, h * 0.898, w * 0.096, h * 0.063),
      0, math.pi, false,
      f(const Color(0xFF111111))..style = PaintingStyle.stroke..strokeWidth = w * 0.006,
    );
    canvas.drawLine(Offset(w * 0.444, h * 0.902), Offset(w * 0.428, h * 0.944),
        f(const Color(0xFF444444))..strokeWidth = w * 0.004);

    // 5. Wood stock ───────────────────────────────────────────────────────
    final stR = Rect.fromLTWH(w * 0.352, h * 0.906, w * 0.308, h * 0.120);
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        stR.left, stR.top, stR.right, h * 1.04,
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
      ),
      mgh(stR, const Color(0xFF3A1606), const Color(0xFF7A4010), const Color(0xFF3A1606)),
    );
    // Wood grain lines
    for (var i = 0; i < 5; i++) {
      final gx = w * 0.368 + i * w * 0.052;
      canvas.drawLine(Offset(gx, h * 0.910), Offset(gx - w * 0.010, h * 1.04),
          f(const Color(0xFF2A0E03))..strokeWidth = w * 0.005);
    }
    canvas.drawRect(Rect.fromLTWH(w * 0.352, h * 0.906, w * 0.308, h * 0.010),
        f(const Color(0xFF8A5020)));
  }

  /// Rifle / Bounce-Rifle viewmodel (long barrel from lower-right to upper-left).
  // ignore: long-method
  void _vmRifle(Canvas canvas, double w, double h, {required bool bounce}) {
    Paint f(Color c) => Paint()..color = c;
    Paint mgv(Rect r, Color d, Color m, Color l) => Paint()
      ..shader = Gradient.linear(r.topLeft, r.bottomLeft, [d, m, l], [0.0, 0.45, 1.0]);
    Paint mgh(Rect r, Color d, Color m, Color l) => Paint()
      ..shader = Gradient.linear(r.topLeft, r.topRight, [d, m, l], [0.0, 0.45, 1.0]);

    const Color glowB = Color(0xFF44AAFF);
    final Color bodyDark = bounce ? const Color(0xFF061218) : const Color(0xFF141414);
    final Color bodyMid  = bounce ? const Color(0xFF0C2840) : const Color(0xFF303030);
    final Color bodyLite = bounce ? const Color(0xFF104068) : const Color(0xFF505050);

    // 1. Main barrel ──────────────────────────────────────────────────────
    final barR = Rect.fromLTWH(w * 0.034, h * 0.576, w * 0.562, h * 0.030);
    canvas.drawRect(barR,
        mgh(barR, const Color(0xFF1A1A1A), const Color(0xFF484848), const Color(0xFF2A2A2A)));
    canvas.drawRect(Rect.fromLTWH(w * 0.034, h * 0.576, w * 0.562, h * 0.004),
        f(const Color(0x55FFFFFF)));
    // Muzzle device (3 spaced blocks at barrel tip)
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.037 + i * w * 0.010, h * 0.574, w * 0.007, h * 0.034),
        f(const Color(0xFF404040)),
      );
    }
    // Muzzle hole
    canvas.drawCircle(Offset(w * 0.058, h * 0.591), h * 0.009, f(const Color(0xFF060606)));
    // Front sight post
    canvas.drawRect(
        Rect.fromLTWH(w * 0.120, h * 0.560, w * 0.008, h * 0.016), f(const Color(0xFFDDDDDD)));

    if (bounce) {
      // Energy rings along barrel
      for (var i = 0; i < 5; i++) {
        final cx = w * 0.12 + i * w * 0.088;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, h * 0.591), width: w * 0.022, height: h * 0.032),
          f(glowB)..style = PaintingStyle.stroke..strokeWidth = 1.8..blendMode = BlendMode.plus,
        );
      }
      // Glow channel along barrel
      canvas.drawRect(
        Rect.fromLTWH(w * 0.04, h * 0.582, w * 0.54, h * 0.010),
        f(const Color(0x1844AAFF))..blendMode = BlendMode.plus,
      );
    }

    // 2. Gas tube (thin, above barrel mid-section) ────────────────────────
    canvas.drawRect(
        Rect.fromLTWH(w * 0.09, h * 0.563, w * 0.38, h * 0.013), f(const Color(0xFF222222)));

    // 3. Handguard ────────────────────────────────────────────────────────
    final hgR = Rect.fromLTWH(w * 0.440, h * 0.568, w * 0.106, h * 0.102);
    canvas.drawRRect(
      RRect.fromRectAndRadius(hgR, const Radius.circular(3)),
      mgv(hgR, bodyDark, bodyMid, bodyDark),
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(w * 0.452 + i * w * 0.022, h * 0.572),
        Offset(w * 0.452 + i * w * 0.022, h * 0.578),
        f(const Color(0xFF555555))..strokeWidth = w * 0.003,
      );
    }

    // 4. Upper receiver ───────────────────────────────────────────────────
    final urR = Rect.fromLTWH(w * 0.530, h * 0.550, w * 0.268, h * 0.114);
    canvas.drawRect(urR, mgv(urR, bodyMid, bodyLite, bodyMid));
    canvas.drawRect(Rect.fromLTWH(w * 0.530, h * 0.550, w * 0.268, h * 0.006),
        f(const Color(0x44FFFFFF)));
    // Ejection port
    canvas.drawRect(
        Rect.fromLTWH(w * 0.728, h * 0.574, w * 0.052, h * 0.050), f(const Color(0xFF090909)));
    // Charging handle
    canvas.drawRect(
        Rect.fromLTWH(w * 0.782, h * 0.558, w * 0.018, h * 0.042), f(const Color(0xFF1A1A1A)));

    // 5. Top optic / carry handle ─────────────────────────────────────────
    if (!bounce) {
      // Carry handle with rear sight
      final chR = Rect.fromLTWH(w * 0.558, h * 0.512, w * 0.202, h * 0.040);
      canvas.drawRect(
          chR, mgv(chR, const Color(0xFF191919), const Color(0xFF353535), const Color(0xFF191919)));
      canvas.drawRect(Rect.fromLTWH(w * 0.558, h * 0.512, w * 0.202, h * 0.005),
          f(const Color(0x33FFFFFF)));
      for (var i = 0; i < 5; i++) {
        canvas.drawLine(Offset(w * 0.566 + i * w * 0.036, h * 0.515),
            Offset(w * 0.566 + i * w * 0.036, h * 0.520),
            f(const Color(0xFF555555))..strokeWidth = w * 0.003);
      }
    } else {
      // Scope with glowing energy lens
      final scopeR = Rect.fromLTWH(w * 0.562, h * 0.504, w * 0.192, h * 0.050);
      canvas.drawRRect(
        RRect.fromRectAndRadius(scopeR, const Radius.circular(4)),
        mgv(scopeR, const Color(0xFF060E18), const Color(0xFF0C2035), const Color(0xFF060E18)),
      );
      // Lens
      canvas.drawOval(
          Rect.fromLTWH(w * 0.628, h * 0.509, w * 0.062, h * 0.042), f(const Color(0xFF050A10)));
      canvas.drawOval(
        Rect.fromLTWH(w * 0.636, h * 0.514, w * 0.044, h * 0.030),
        f(glowB)..blendMode = BlendMode.plus,
      );
      canvas.drawLine(Offset(w * 0.646, h * 0.520), Offset(w * 0.654, h * 0.526),
          f(const Color(0x99FFFFFF))..strokeWidth = 1.5);
      // Glow top rail
      canvas.drawRect(Rect.fromLTWH(w * 0.530, h * 0.550, w * 0.268, h * 0.006),
          f(const Color(0x5544AAFF))..blendMode = BlendMode.plus);
    }

    // 6. Lower receiver ────────────────────────────────────────────────────
    final lrR = Rect.fromLTWH(w * 0.525, h * 0.664, w * 0.272, h * 0.118);
    canvas.drawRect(lrR, mgv(lrR, bodyDark, bodyMid, bodyDark));

    // 7. Magazine ─────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        w * 0.587, h * 0.782, w * 0.673, h * 0.965,
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      mgv(Rect.fromLTWH(w * 0.587, h * 0.782, w * 0.086, h * 0.183),
          bodyMid, bodyLite, bodyMid),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.587, h * 0.782, w * 0.086, h * 0.009),
      f(bounce ? const Color(0xFF44AAFF) : const Color(0xFF666666)),
    );
    canvas.drawLine(Offset(w * 0.630, h * 0.792), Offset(w * 0.630, h * 0.960),
        f(const Color(0xFF111111))..strokeWidth = w * 0.004);
    if (bounce) {
      canvas.drawRect(Rect.fromLTWH(w * 0.588, h * 0.782, w * 0.084, h * 0.010),
          f(const Color(0x7744AAFF))..blendMode = BlendMode.plus);
    }

    // 8. Pistol grip ──────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        w * 0.698, h * 0.782, w * 0.794, h * 1.02,
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
      f(bounce ? const Color(0xFF061018) : const Color(0xFF111111)),
    );
    for (var gy = 0; gy < 4; gy++) {
      for (var gx = 0; gx < 3; gx++) {
        canvas.drawCircle(
          Offset(w * 0.712 + gx * w * 0.022, h * 0.808 + gy * h * 0.040),
          h * 0.004,
          f(const Color(0xFF1E1E1E)),
        );
      }
    }
    if (bounce) {
      canvas.drawRect(Rect.fromLTWH(w * 0.698, h * 0.824, w * 0.096, h * 0.010),
          f(const Color(0x5544AAFF)));
    }

    // 9. Trigger guard ────────────────────────────────────────────────────
    canvas.drawArc(
      Rect.fromLTWH(w * 0.640, h * 0.774, w * 0.096, h * 0.066),
      0, math.pi, false,
      f(const Color(0xFF0E0E0E))..style = PaintingStyle.stroke..strokeWidth = w * 0.006,
    );
    canvas.drawLine(Offset(w * 0.688, h * 0.780), Offset(w * 0.674, h * 0.824),
        f(const Color(0xFF444444))..strokeWidth = w * 0.004);

    // 10. Stock (extends off right edge) ──────────────────────────────────
    final stR = Rect.fromLTWH(w * 0.782, h * 0.652, w * 0.244, h * 0.112);
    canvas.drawRRect(
      RRect.fromRectAndRadius(stR, const Radius.circular(4)),
      mgv(stR, bodyDark, bodyMid, bodyDark),
    );
    if (bounce) {
      canvas.drawRect(Rect.fromLTWH(w * 0.786, h * 0.678, w * 0.236, h * 0.012),
          f(const Color(0x4444AAFF)));
    }
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

  // ─────────────────────────────────────────────────────────────────────────
  // Projectile Primitive Rendering
  // ─────────────────────────────────────────────────────────────────────────

  /// Renders a plasma / bolt orb as a depth-scaled glow circle.
  ///
  /// Uses canvas primitives only — no billboard sprite.  The radius is
  /// hard-capped so it never fills the screen when the bullet is close.
  /// Enemy orbs glow orange/red; player orbs glow cyan/white.
  void _drawPlasmaOrb(
    Canvas canvas,
    v64.Vector2 screenSize,
    WorldState state,
    Projectile proj,
    double planeLen,
  ) {
    final (cx, depth) =
        _projectPointToScreenX(proj.position, screenSize, state, planeLen);
    if (depth == null) return;

    final centerY = screenSize.y / 2.0;

    // Radius: depth-scaled, capped so it never fills the screen.
    // visualScale: per-weapon multiplier (bouncePistol=1.7, bounceRifle=1.3, etc.)
    final radius = (screenSize.y / depth * 0.032 * proj.visualScale).clamp(3.0, 40.0);

    final isBouncing = proj.ammoType == AmmoType.bouncing;
    final Color outerColor;
    final Color midColor;
    if (proj.isEnemy) {
      outerColor = const Color(0x88FF4400);
      midColor   = const Color(0xCCFF8800);
    } else if (isBouncing) {
      outerColor = const Color(0x8800FF44);
      midColor   = const Color(0xCC88FF88);
    } else {
      outerColor = const Color(0x880088FF);
      midColor   = const Color(0xCC44DDFF);
    }
    const coreColor = Color(0xFFFFFFFF);

    final cx0 = Offset(cx, centerY);

    // Outer glow (additive, soft)
    canvas.drawCircle(
      cx0, radius,
      Paint()
        ..color = outerColor
        ..blendMode = BlendMode.plus,
    );
    // Mid ring
    canvas.drawCircle(
      cx0, radius * 0.55,
      Paint()
        ..color = midColor
        ..blendMode = BlendMode.plus,
    );
    // Bright core
    canvas.drawCircle(
      cx0, radius * 0.25,
      Paint()
        ..color = coreColor
        ..blendMode = BlendMode.plus,
    );
  }

  /// Renders a hitscan tracer as a perspective-correct screen-space streak.
  ///
  /// Algorithm (Ion Fury / Quake style):
  ///   1. Project the bullet HEAD to screen X.
  ///   2. Project a point 0.3 wu BEHIND the bullet for the TAIL.
  ///   3. Enforce a minimum screen streak of 30 px so the bullet is always
  ///      visible even when it travels straight away from the camera.
  ///   4. Draw: gradient rounded-rect tail → head + additive glow circle.
  void _drawBulletStreak(
    Canvas canvas,
    v64.Vector2 screenSize,
    WorldState state,
    Projectile proj,
    double planeLen,
  ) {
    final (headX, headDepth) =
        _projectPointToScreenX(proj.position, screenSize, state, planeLen);
    if (headDepth == null) return;

    final centerY = screenSize.y / 2.0;
    final thickness  = (screenSize.y / headDepth * 0.012 * proj.visualScale).clamp(1.0, 7.0);
    final glowRadius = (screenSize.y / headDepth * 0.022 * proj.visualScale).clamp(2.5, 16.0);

    // --- Determine tail screen X ---
    const minStreakPx = 30.0; // always visible even when shooting straight ahead
    final speed = proj.velocity.length;
    double tailX;
    if (speed > 0.1) {
      final tailWorld = proj.position - (proj.velocity / speed) * 0.3;
      final (tx, _)   = _projectPointToScreenX(tailWorld, screenSize, state, planeLen);
      final rawLen    = (headX - tx).abs();
      if (rawLen < minStreakPx) {
        // Bullet going nearly straight: enforce minimum and keep direction.
        // When rawLen == 0 we fall back to extending left (into the screen center).
        final sign = rawLen < 0.5
            ? (headX < screenSize.x / 2 ? 1.0 : -1.0)
            : (headX > tx ? 1.0 : -1.0);
        tailX = headX - sign * minStreakPx;
      } else {
        tailX = tx;
      }
    } else {
      tailX = headX - minStreakPx;
    }

    final glowColor = proj.isEnemy ? const Color(0xCCFF5500) : const Color(0xCC00EEFF);
    const coreColor = Color(0xFFFFFFFF);

    // Streak body: gradient from transparent (tail) to glowColor (head)
    final minX     = math.min(tailX, headX);
    final maxX     = math.max(tailX, headX);
    final gradFrom = tailX < headX ? Offset(minX, centerY) : Offset(maxX, centerY);
    final gradTo   = tailX < headX ? Offset(maxX, centerY) : Offset(minX, centerY);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(minX, centerY - thickness / 2, maxX, centerY + thickness / 2),
        Radius.circular(thickness / 2),
      ),
      Paint()
        ..shader = Gradient.linear(
          gradFrom, gradTo, [const Color(0x00000000), glowColor],
        )
        ..blendMode = BlendMode.plus,
    );

    // Glow halo at head
    canvas.drawCircle(
      Offset(headX, centerY), glowRadius,
      Paint()..color = glowColor..blendMode = BlendMode.plus,
    );
    // White core
    canvas.drawCircle(
      Offset(headX, centerY), glowRadius * 0.30,
      Paint()..color = coreColor..blendMode = BlendMode.plus,
    );
  }

  /// Screen-space muzzle flash: radial gradient at weapon barrel, no world coords.
  /// [alpha] runs from 1.0 (just fired) → 0.0 (expired).
  void _drawScreenSpaceMuzzleFlash(
      Canvas canvas, v64.Vector2 screenSize, double alpha) {
    if (alpha <= 0) return;
    final cx = screenSize.x * 0.5;
    final cy = screenSize.y * 0.70; // near the bottom of the view-model
    final radius = 90.0 * alpha;
    final shader = Gradient.radial(
      Offset(cx, cy),
      radius,
      [
        Color.fromARGB((220 * alpha).round(), 255, 255, 180),
        Color.fromARGB((160 * alpha).round(), 255, 160, 0),
        Color.fromARGB((80 * alpha).round(), 255, 80, 0),
        const Color(0x00000000),
      ],
      [0.0, 0.35, 0.65, 1.0],
    );
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.plus,
    );
  }

  /// Draws a canvas-primitive spark burst at a world position (bounce impact).
  /// [alpha] runs 1.0 → 0.0. Projects to screen via raycaster transform.
  void _drawBounceSpark(
    Canvas canvas,
    v64.Vector2 screenSize,
    WorldState state,
    v64.Vector2 worldPos,
    double alpha,
    double planeLen,
  ) {
    if (alpha <= 0) return;
    final (screenX, depth) = _projectPointToScreenX(worldPos, screenSize, state, planeLen);
    if (depth == null || depth < 0.05) return;
    final screenH = screenSize.y;
    final centerY = screenH / 2;
    final baseR = (screenH / depth * 0.03).clamp(4.0, 20.0) * alpha;

    // Outer glow
    canvas.drawCircle(
      Offset(screenX, centerY),
      baseR * 2.5,
      Paint()
        ..color = Color.fromARGB((80 * alpha).round(), 0, 255, 120)
        ..blendMode = BlendMode.plus,
    );
    // Mid ring
    canvas.drawCircle(
      Offset(screenX, centerY),
      baseR,
      Paint()
        ..color = Color.fromARGB((180 * alpha).round(), 100, 255, 180)
        ..blendMode = BlendMode.plus,
    );
    // Bright core
    canvas.drawCircle(
      Offset(screenX, centerY),
      baseR * 0.4,
      Paint()
        ..color = Color.fromARGB((255 * alpha).round(), 220, 255, 240)
        ..blendMode = BlendMode.plus,
    );
  }

  /// Renders an ammo pickup as a canvas-primitive at the given world position.
  /// Normal ammo  → Doom-style gold ammo clip box with bullet tops visible.
  /// Bouncing ammo → tall cyan energy cell with glowing top.
  void _drawAmmoPickup(
    Canvas canvas,
    v64.Vector2 screenSize,
    WorldState state,
    v64.Vector2 worldPos,
    PickupComponent pickup,
    double planeLen,
  ) {
    final (sx, depth) = _projectPointToScreenX(worldPos, screenSize, state, planeLen);
    if (depth == null || depth < 0.1) return;

    final screenH = screenSize.y;
    // +20% size vs original 0.04 factor
    final baseSize = (screenH / depth * 0.048).clamp(4.8, 38.4);
    // Float slightly above the floor centreline
    final cy = screenH / 2.0 + screenH / depth * 0.06;
    // Gentle bob animation
    final bob = math.sin(_time * 2.8 + worldPos.x) * baseSize * 0.10;
    final cy2 = cy + bob;

    if (pickup.ammoType == AmmoType.bouncing) {
      // ── Energy Cell (Doom-style) ─────────────────────────────────────────
      // Tall narrow rectangular cell with bright glowing top
      final cellW = baseSize * 0.65;
      final cellH = baseSize * 1.5;
      final cellRect = Rect.fromCenter(
          center: Offset(sx, cy2), width: cellW, height: cellH);

      // Cell body with vertical gradient (dark base → bright top)
      canvas.drawRRect(
        RRect.fromRectAndRadius(cellRect, Radius.circular(cellW * 0.15)),
        Paint()
          ..shader = Gradient.linear(
            cellRect.bottomCenter,
            cellRect.topCenter,
            [const Color(0xFF003322), const Color(0xFF00CC77), const Color(0xFF44FFAA)],
            [0.0, 0.6, 1.0],
          ),
      );
      // Bright glow rim
      canvas.drawRRect(
        RRect.fromRectAndRadius(cellRect, Radius.circular(cellW * 0.15)),
        Paint()
          ..color = const Color(0x8800FF88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseSize * 0.08
          ..blendMode = BlendMode.plus,
      );
      // Horizontal ribbing lines
      for (var i = 1; i <= 3; i++) {
        final ry = cellRect.top + cellH * i / 4.0;
        canvas.drawLine(
          Offset(cellRect.left + cellW * 0.1, ry),
          Offset(cellRect.right - cellW * 0.1, ry),
          Paint()
            ..color = const Color(0x6600FFAA)
            ..strokeWidth = baseSize * 0.04,
        );
      }
      // Glowing top cap
      final topCapRect = Rect.fromCenter(
          center: Offset(sx, cellRect.top + baseSize * 0.06),
          width: cellW * 0.8, height: baseSize * 0.22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(topCapRect, Radius.circular(topCapRect.height * 0.4)),
        Paint()..color = const Color(0xFF88FFD0)..blendMode = BlendMode.plus,
      );
      // Outer glow aura
      canvas.drawCircle(
        Offset(sx, cy2),
        baseSize * 1.0,
        Paint()
          ..color = const Color(0x2200FF88)
          ..blendMode = BlendMode.plus,
      );
    } else {
      // ── Ammo Clip Box (Doom-style) ────────────────────────────────────────
      // Wide flat gold box with bullet tips visible across the top
      final bw = baseSize * 1.6;
      final bh = baseSize * 0.9;
      final boxRect = Rect.fromCenter(
          center: Offset(sx, cy2 + bh * 0.15), width: bw, height: bh);

      // Box body: gold/olive metallic
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, Radius.circular(bh * 0.12)),
        Paint()
          ..shader = Gradient.linear(
            boxRect.topLeft,
            boxRect.bottomLeft,
            [const Color(0xFF8B7A20), const Color(0xFFCCA830), const Color(0xFF9B8220)],
            [0.0, 0.45, 1.0],
          ),
      );
      // Side shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, Radius.circular(bh * 0.12)),
        Paint()
          ..color = const Color(0x44000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bh * 0.06,
      );
      // Label area (dark band in center)
      canvas.drawRect(
        Rect.fromCenter(center: Offset(sx, cy2 + bh * 0.15), width: bw * 0.85, height: bh * 0.28),
        Paint()..color = const Color(0xFF2A2200),
      );
      // Bullet tips visible across top of box (5 small ovals in a row)
      final bulletCount = 5;
      final spacing = bw * 0.75 / (bulletCount - 1);
      final tipStartX = sx - bw * 0.75 / 2;
      for (var i = 0; i < bulletCount; i++) {
        final bx = tipStartX + i * spacing;
        final ty = boxRect.top - bh * 0.05;
        // Brass case
        canvas.drawOval(
          Rect.fromCenter(center: Offset(bx, ty), width: bw * 0.10, height: bh * 0.30),
          Paint()
            ..shader = Gradient.linear(
              Offset(bx - bw * 0.04, ty),
              Offset(bx + bw * 0.04, ty),
              [const Color(0xFF7A5C10), const Color(0xFFDDAA44), const Color(0xFF7A5C10)],
              [0.0, 0.5, 1.0],
            ),
        );
        // Bullet tip (darker lead)
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(bx, ty - bh * 0.14),
              width: bw * 0.08, height: bh * 0.18),
          Paint()..color = const Color(0xFF888870),
        );
      }
      // Top highlight
      canvas.drawRect(
        Rect.fromLTWH(boxRect.left + bw * 0.08, boxRect.top + bh * 0.06, bw * 0.84, bh * 0.10),
        Paint()..color = const Color(0x44FFFFFF),
      );
    }
  }

  /// Renders a fading wall-impact decal at the given world position.
  /// [alpha] runs from 1.0 (fresh) to 0.0 (expired).
  void _drawWallDecal(
    Canvas canvas,
    v64.Vector2 screenSize,
    WorldState state,
    v64.Vector2 worldPos,
    double alpha,
    double planeLen,
  ) {
    if (alpha <= 0) return;
    final (sx, depth) = _projectPointToScreenX(worldPos, screenSize, state, planeLen);
    if (depth == null || depth < 0.05) return;

    final screenH = screenSize.y;
    final centerY = screenH / 2.0;
    final baseR = (screenH / depth * 0.016).clamp(2.0, 12.0);

    // Dark soot splat (multiply darkens what's behind it)
    canvas.drawCircle(
      Offset(sx, centerY),
      baseR * 2.0,
      Paint()
        ..color = Color.fromARGB((80 * alpha).round(), 0, 0, 0)
        ..blendMode = BlendMode.multiply,
    );
    // Scorched core (dark brown/orange)
    canvas.drawCircle(
      Offset(sx, centerY),
      baseR,
      Paint()
        ..color = Color.fromARGB((140 * alpha).round(), 80, 40, 10)
        ..blendMode = BlendMode.srcOver,
    );
    // Tiny bright spark center (fades quickly)
    final sparkAlpha = (alpha * 3.0 - 2.0).clamp(0.0, 1.0); // visible only first 33%
    if (sparkAlpha > 0) {
      canvas.drawCircle(
        Offset(sx, centerY),
        baseR * 0.35,
        Paint()
          ..color = Color.fromARGB((200 * sparkAlpha).round(), 255, 200, 100)
          ..blendMode = BlendMode.plus,
      );
    }
  }

  /// Projects [worldPos] to screen X using the standard raycaster transform.
  /// Returns `(screenX, depth)` — depth is `null` when behind the camera.
  (double, double?) _projectPointToScreenX(
    v64.Vector2 worldPos,
    v64.Vector2 screenSize,
    WorldState state,
    double planeLen,
  ) {
    final vec = worldPos - state.effectivePosition;
    final planeX = -_cachedDirY * planeLen;
    final planeY = _cachedDirX * planeLen;
    final invDet = 1.0 / (planeX * _cachedDirY - _cachedDirX * planeY);
    final transX =
        invDet * (_cachedDirY * vec.x - _cachedDirX * vec.y);
    final transY =
        invDet * (-planeY * vec.x + planeX * vec.y);
    if (transY <= 0.05) return (screenSize.x / 2, null);
    final screenX = (screenSize.x / 2) * (1 + transX / transY);
    return (screenX, transY);
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
  });
  final v64.Vector2 pos;
  final Image texture;
  final Rect srcRect;
  final double distSq;
  final double scale;
  final double opacity;
}
