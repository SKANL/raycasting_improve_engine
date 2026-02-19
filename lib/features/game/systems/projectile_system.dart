import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:raycasting_game/features/core/world/models/game_map.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';
import 'package:raycasting_game/features/game/models/projectile.dart';
import 'package:raycasting_game/features/core/ecs/components/transform_component.dart';

/// Result of a single projectile simulation tick.
class ProjectileUpdateResult {
  const ProjectileUpdateResult({
    required this.surviving,
    required this.entityHits,
    required this.playerHits,
  });

  /// Projectiles that are still alive after this tick.
  final List<Projectile> surviving;

  /// Map of entityId → total damage dealt this tick (enemy/entity hits).
  final Map<String, int> entityHits;

  /// Total damage dealt to the player this tick (from enemy projectiles).
  final int playerHits;
}

/// Simulates all active [Projectile] entities each game tick.
///
/// Algorithm per projectile (Doom-inspired):
///   1. Move: pos += velocity * dt
///   2. Wall hit (DDA):
///      - If bouncing, reflect velocity: R = V - 2(V·N)N, decrement bouncesLeft
///      - Else: destroy
///   3. Entity hit (circle sweep): damage + destroy
///   4. Range check: if distanceTraveled > maxRange → destroy
class ProjectileSystem {
  /// Energy retained after each bounce (70% speed kept).
  static const bounceFactor = 0.70;

  /// Collision hit radius for entity detection.
  static const hitRadius = 0.45;

  static ProjectileUpdateResult update(
    List<Projectile> projectiles,
    List<GameEntity> entities,
    v64.Vector2 playerPosition,
    GameMap? map,
    double dt,
  ) {
    final surviving = <Projectile>[];
    final entityHits = <String, int>{};
    var playerHits = 0;

    for (final proj in projectiles) {
      final result = _step(proj, entities, playerPosition, map, dt);

      if (result.entityId != null) {
        entityHits[result.entityId!] =
            (entityHits[result.entityId!] ?? 0) + proj.damage;
      }
      if (result.hitPlayer) {
        playerHits += proj.damage;
      }
      if (result.updated != null) {
        surviving.add(result.updated!);
      }
    }

    return ProjectileUpdateResult(
      surviving: surviving,
      entityHits: entityHits,
      playerHits: playerHits,
    );
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  static _StepResult _step(
    Projectile proj,
    List<GameEntity> entities,
    v64.Vector2 playerPosition,
    GameMap? map,
    double dt,
  ) {
    final movement = proj.velocity * dt;
    final stepDist = movement.length;

    // --- 1. Range check (before moving, to avoid overshooting) ---
    if (proj.distanceTraveled + stepDist > proj.maxRange) {
      return const _StepResult(); // destroy: out of range
    }

    final newPos = proj.position + movement;

    // --- 2. Wall collision (DDA) ---
    final wallResult = _checkWall(proj.position, newPos, proj.velocity, map);
    if (wallResult != null) {
      // Hit a wall
      if (proj.isBouncing) {
        // Vector reflection: R = V - 2(V·N)N
        final n = wallResult.normal;
        final dot = proj.velocity.dot(n);
        final reflected = (proj.velocity - n * (2.0 * dot)) * bounceFactor;

        final bounced = proj.copyWith(
          position: wallResult.hitPoint,
          velocity: reflected,
          bouncesLeft: proj.bouncesLeft - 1,
          distanceTraveled: proj.distanceTraveled + stepDist,
        );
        // If we just used the last bounce, this projectile won't be marked as
        // bouncing anymore (isBouncing checks bouncesLeft > 0).
        return _StepResult(updated: bounced);
      } else {
        return const _StepResult(); // destroy: hit wall, no bounce
      }
    }

    // --- 3. Entity hit (Continuous - Ray/Circle) ---
    if (proj.isVisualOnly) {
      // Visual tracers don't hit entities
      final updated = proj.copyWith(
        position: newPos,
        distanceTraveled: proj.distanceTraveled + stepDist,
      );
      return _StepResult(updated: updated);
    }

    // Check Player
    if (proj.isEnemy) {
      if (_intersectCircle(proj.position, newPos, playerPosition, hitRadius)) {
        return const _StepResult(hitPlayer: true);
      }
    }

    // Check Entities
    final hitEntityId = _checkEntities(proj, newPos, entities);
    if (hitEntityId != null) {
      return _StepResult(entityId: hitEntityId); // destroy after hit
    }

    // --- 4. Survived this tick ---
    final updated = proj.copyWith(
      position: newPos,
      distanceTraveled: proj.distanceTraveled + stepDist,
    );
    return _StepResult(updated: updated);
  }

  // ─── Wall Check (DDA) ────────────────────────────────────────────────────

  static _WallHit? _checkWall(
    v64.Vector2 from,
    v64.Vector2 to,
    v64.Vector2 velocity,
    GameMap? map,
  ) {
    if (map == null) return null;

    final dir = to - from;
    final dist = dir.length;
    if (dist < 0.001) return null;

    final dirN = dir / dist;

    var mapX = from.x.floor();
    var mapY = from.y.floor();

    final deltaDistX = dirN.x == 0 ? 1e30 : (1.0 / dirN.x).abs();
    final deltaDistY = dirN.y == 0 ? 1e30 : (1.0 / dirN.y).abs();

    int stepX, stepY;
    double sideDistX, sideDistY;

    if (dirN.x < 0) {
      stepX = -1;
      sideDistX = (from.x - mapX) * deltaDistX;
    } else {
      stepX = 1;
      sideDistX = (mapX + 1.0 - from.x) * deltaDistX;
    }
    if (dirN.y < 0) {
      stepY = -1;
      sideDistY = (from.y - mapY) * deltaDistY;
    } else {
      stepY = 1;
      sideDistY = (mapY + 1.0 - from.y) * deltaDistY;
    }

    bool hitWall = false;
    bool hitSideY = false;
    var steps = 0;

    final destX = to.x.floor();
    final destY = to.y.floor();

    while (steps < 20) {
      if (sideDistX < sideDistY) {
        sideDistX += deltaDistX;
        mapX += stepX;
        hitSideY = false;
      } else {
        sideDistY += deltaDistY;
        mapY += stepY;
        hitSideY = true;
      }

      if (map.getCell(mapX, mapY).isSolid) {
        hitWall = true;
        break;
      }

      // Reached destination cell without hitting a wall
      if (mapX == destX && mapY == destY) break;

      steps++;
    }

    if (!hitWall) return null;

    // Wall normal: axis perpendicular to the face we hit
    final normal = hitSideY
        ? v64.Vector2(0, -stepY.toDouble())
        : v64.Vector2(-stepX.toDouble(), 0);

    // Approximate hit point on wall face
    final hitDist = hitSideY ? sideDistY - deltaDistY : sideDistX - deltaDistX;
    final hitPoint = from + dirN * hitDist;

    return _WallHit(hitPoint: hitPoint, normal: normal);
  }

  // ─── Entity Check ────────────────────────────────────────────────────────

  static String? _checkEntities(
    Projectile proj,
    v64.Vector2 newPos,
    List<GameEntity> entities,
  ) {
    for (final entity in entities) {
      if (entity.id == proj.ownerId || !entity.isActive) continue;
      // Enemy projectiles only hit player, not other enemies
      // Player projectiles hit all enemy entities
      if (proj.isEnemy) continue;

      final transform = entity.getComponent<TransformComponent>();
      if (transform == null) continue;

      if (_intersectCircle(
        proj.position,
        newPos,
        transform.position,
        hitRadius,
      )) {
        return entity.id;
      }
    }
    return null;
  }

  /// Checks if the segment [start]-[end] intersects a circle at [center] with [radius].
  static bool _intersectCircle(
    v64.Vector2 start,
    v64.Vector2 end,
    v64.Vector2 center,
    double radius,
  ) {
    final d = end - start;
    final f = start - center;

    final a = d.dot(d);
    final b = 2 * f.dot(d);
    final c = f.dot(f) - radius * radius;

    double discriminant = b * b - 4 * a * c;
    if (discriminant < 0) {
      return false;
    } else {
      discriminant = math.sqrt(discriminant);

      final t1 = (-b - discriminant) / (2 * a);
      final t2 = (-b + discriminant) / (2 * a);

      if (t1 >= 0 && t1 <= 1) return true;
      if (t2 >= 0 && t2 <= 1) return true;
      return false;
    }
  }
}

// ─── Private Data Classes ────────────────────────────────────────────────────

class _WallHit {
  const _WallHit({required this.hitPoint, required this.normal});
  final v64.Vector2 hitPoint;
  final v64.Vector2 normal;
}

class _StepResult {
  const _StepResult({
    this.updated,
    this.entityId,
    this.hitPlayer = false,
  });

  /// Non-null if the projectile survived this tick.
  final Projectile? updated;

  /// Non-null if an entity was hit (projectile is destroyed).
  final String? entityId;

  /// True if the player was hit by an enemy projectile (destroyed).
  final bool hitPlayer;
}
