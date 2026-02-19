import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:raycasting_game/features/core/world/models/game_map.dart';
import 'package:raycasting_game/features/core/world/models/game_entity.dart';
import 'package:raycasting_game/features/core/ecs/components/transform_component.dart';

/// Centralized logic for movement and collision detection.
/// Used by both Player (via standard input) and AI.
class PhysicsSystem {
  /// Raycast to check visibility between two points.
  /// Returns true if there is a clear line of sight (no walls).
  static bool hasLineOfSight(v64.Vector2 start, v64.Vector2 end, GameMap? map) {
    if (map == null) return true;

    final direction = end - start;
    final dist = direction.length;
    if (dist < 0.1) return true;

    // Fast check: Same cell is always visible
    if (start.x.floor() == end.x.floor() && start.y.floor() == end.y.floor()) {
      return true;
    }

    final dirX = direction.x / dist;
    final dirY = direction.y / dist;

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

    var hit = false;
    var steps = 0;
    const maxSteps = 20; // Vision range limit

    while (!hit && steps < maxSteps) {
      if (sideDistX < sideDistY) {
        sideDistX += deltaDistX;
        mapX += stepX;
      } else {
        sideDistY += deltaDistY;
        mapY += stepY;
      }

      // Check wall
      if (map.getCell(mapX, mapY).isSolid) {
        hit = true;
      }

      // Visited target cell?
      if (mapX == end.x.floor() && mapY == end.y.floor()) {
        return true;
      }

      steps++;
    }

    return !hit;
  }

  /// Attempt to move an entity by [velocity] * [dt].
  ///
  /// specificEntityId: ID of the entity moving (to avoid self-collision).
  /// currentPos: Current position of the entity.
  /// velocity: Movement vector (direction * speed).
  /// dt: Delta time in seconds.
  /// map: The game map for wall collisions.
  /// entities: List of all active entities for bounding box checks.
  /// radius: Collision radius of the moving entity (default 0.3).
  static v64.Vector2 tryMove(
    String specificEntityId,
    v64.Vector2 currentPos,
    v64.Vector2 velocity,
    double dt,
    GameMap? map,
    List<GameEntity> entities, {
    double radius = 0.3,
  }) {
    // 0. Validation Guards
    if (currentPos.x.isNaN || currentPos.y.isNaN) return currentPos;
    if (velocity.x.isNaN || velocity.y.isNaN) return currentPos;
    if (velocity.x.isInfinite || velocity.y.isInfinite) return currentPos;
    if (velocity.length == 0) return currentPos;

    // 1. Calculate intended movement
    var movement = velocity * dt;

    // Sub-stepping to prevent tunneling
    // If movement is larger than the radius (or a safe fraction of tile size), break it down.
    // Safe step size = radius (since we check radius borders)
    final dist = movement.length;
    if (dist > radius) {
      final steps = (dist / radius).ceil();
      final stepDir = movement / dist; // normalized
      final stepVec = stepDir * radius;

      var pendingPos = currentPos;

      for (var i = 0; i < steps; i++) {
        // Last step might be smaller
        var currentStep = stepVec;
        if (i == steps - 1) {
          final remaining = dist - (i * radius);
          currentStep = stepDir * remaining;
        }

        pendingPos = _performSingleStep(
          specificEntityId,
          pendingPos,
          currentStep,
          map,
          entities,
          radius,
        );
      }
      return pendingPos;
    } else {
      return _performSingleStep(
        specificEntityId,
        currentPos,
        movement,
        map,
        entities,
        radius,
      );
    }
  }

  static v64.Vector2 _performSingleStep(
    String appEntityId,
    v64.Vector2 currentPos,
    v64.Vector2 movement,
    GameMap? map,
    List<GameEntity> entities,
    double radius,
  ) {
    var newPos = currentPos + movement;
    if (map == null) return newPos;

    // 2. Wall Collision (Sliding)
    var testX = currentPos + v64.Vector2(movement.x, 0);
    if (_isWall(map, testX.x, testX.y, radius)) {
      movement.x = 0;
    }

    var testY = currentPos + v64.Vector2(0, movement.y);
    if (_isWall(map, testY.x, testY.y, radius)) {
      movement.y = 0;
    }

    // Re-calculate based on sliding
    newPos = currentPos + movement;

    // 3. Entity Collision
    if (movement.length > 0) {
      // Check X
      var posX = currentPos + v64.Vector2(movement.x, 0);
      if (_isCollidingWithEntity(appEntityId, posX, entities, radius)) {
        movement.x = 0;
      }
      // Check Y
      var posY = currentPos + v64.Vector2(0, movement.y);
      if (_isCollidingWithEntity(appEntityId, posY, entities, radius)) {
        movement.y = 0;
      }
      newPos = currentPos + movement;
    }

    return newPos;
  }

  /// Internal helper to check wall collision with a radius padding.
  /// Checks corners/edges of the bounding box.
  static bool _isWall(GameMap map, double x, double y, double radius) {
    // Check center (optional, but good for small walls) and 4 corners
    // actually, checking 4 corners of the box is usually enough.
    // box: [x-r, y-r] to [x+r, y+r]

    final minX = (x - radius).floor();
    final maxX = (x + radius).floor();
    final minY = (y - radius).floor();
    final maxY = (y + radius).floor();

    for (var cy = minY; cy <= maxY; cy++) {
      for (var cx = minX; cx <= maxX; cx++) {
        if (map.getCell(cx, cy).isSolid) return true;
      }
    }
    return false;
  }

  static bool _isCollidingWithEntity(
    String selfId,
    v64.Vector2 targetPos,
    List<GameEntity> entities,
    double radius,
  ) {
    // Basic Circle-Circle collision
    for (final other in entities) {
      if (other.id == selfId || !other.isActive) continue;

      final otherTransform = other.getComponent<TransformComponent>();
      if (otherTransform == null) continue;

      // We assume all entities have roughly same radius for now (0.3)
      // or we could add a CollisionComponent later.
      const otherRadius = 0.3;
      final minDist = radius + otherRadius;

      final distSq = targetPos.distanceToSquared(otherTransform.position);
      if (distSq < minDist * minDist) {
        return true;
      }
    }
    return false;
  }

  /// Perform a raycast against entities to find the first one hit.
  /// Used for hitscan weapons.
  static String? raycastEntities(
    v64.Vector2 start,
    v64.Vector2 direction,
    List<GameEntity> entities,
    GameMap? map, {
    double maxDistance = 100.0,
    String? excludeId,
  }) {
    String? closestId;
    var closestDistSq = maxDistance * maxDistance;

    for (final entity in entities) {
      if (entity.id == excludeId || !entity.isActive) continue;

      final transform = entity.getComponent<TransformComponent>();
      if (transform == null) continue;

      // 1. Basic distance check (optimization)
      final toEntity = transform.position - start;
      final distSq = toEntity.length2;
      if (distSq > maxDistance * maxDistance) continue;

      // 2. Circle/Sphere intersection check (simplified BBox)
      // Project entity position onto ray
      final rayDir = direction.normalized();
      final t = toEntity.dot(rayDir);

      // Entity is behind ray
      if (t < 0) continue;

      // Closest point on ray to entity center
      final closestPoint = start + (rayDir * t);
      final distFromRaySq = closestPoint.distanceToSquared(transform.position);

      const hitRadius =
          0.4; // Slightly larger than collision radius for easier aiming
      if (distFromRaySq < hitRadius * hitRadius) {
        // We have a specialized hit, but is it the closest?
        // Also need to check if a WALL blocks this hit.
        // Distance to the hit point on ray
        final hitDistSq = (closestPoint - start).length2;

        if (hitDistSq < closestDistSq) {
          // Check wall occlusion
          if (hasLineOfSight(start, transform.position, map)) {
            closestDistSq = hitDistSq;
            closestId = entity.id;
          }
        }
      }
    }

    return closestId;
  }
}
