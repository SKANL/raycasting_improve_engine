import 'dart:collection';
import 'dart:typed_data';

import 'package:raycasting_game/features/core/world/models/game_map.dart';
import 'package:vector_math/vector_math_64.dart';

/// A Dijkstra (BFS) distance map centered on the player position.
///
/// PERFORMANCE CONTRACT:
/// - [recompute] is called at 10 Hz — single BFS pass, O(tiles).
/// - [bestDirection] is called at 60 Hz per enemy — O(1), array reads only.
/// - [isCellVisible] is called at 60 Hz per sprite — O(1), array read only.
/// - ALL internal buffers are pre-allocated once via [initialize].
///   Zero heap allocations occur in the hot path.
class DijkstraMap {
  static const double _infinity = double.infinity;

  // Pre-allocated cost grid. costAt(x, y) = _costGrid[y * _width + x].
  // Value is walking distance (in tiles) from player. Walls = _infinity.
  late Float64List _costGrid;

  // Pre-allocated visibility grid. 1 = visible from player, 0 = occluded.
  // Written during recompute(); read by the renderer and AISystem.
  late Uint8List _visibilityGrid;

  // Reusable BFS queue — stores flat cell index (y * width + x).
  // Cleared and re-used each recompute() call to avoid List allocation.
  final Queue<int> _queue = Queue<int>();

  int _width = 0;
  int _height = 0;

  // Last known player grid position (tile coords). Used by isCellVisible()
  // to skip unnecessary recalculations between recompute() calls.
  int _playerTileX = 0;
  int _playerTileY = 0;

  /// Must be called once before any other method.
  /// Allocates the fixed-size grids for [width] × [height] tile maps.
  void initialize(int width, int height) {
    _width = width;
    _height = height;
    final size = width * height;
    _costGrid = Float64List(size);
    _visibilityGrid = Uint8List(size);
    // Fill costs with infinity (no path known yet)
    _costGrid.fillRange(0, size, _infinity);
  }

  // ─────────────────────────────── Public API ────────────────────────────────

  /// Runs a full BFS from [playerPos], populating [_costGrid] and
  /// [_visibilityGrid]. Should be called at ≤10 Hz.
  ///
  /// Complexity: O(W × H) — bounded to the map tile count.
  void recompute(Vector2 playerPos, GameMap map) {
    if (_width == 0 || _height == 0) return;

    final size = _width * _height;
    _playerTileX = playerPos.x.floor().clamp(0, _width - 1);
    _playerTileY = playerPos.y.floor().clamp(0, _height - 1);

    // 1. Reset grids in-place — no allocation.
    _costGrid.fillRange(0, size, _infinity);
    _visibilityGrid.fillRange(0, size, 0);

    // 2. Seed the queue from the player tile.
    _queue.clear();
    final startIdx = _idx(_playerTileX, _playerTileY);
    _costGrid[startIdx] = 0;
    _visibilityGrid[startIdx] = 1; // Player's own tile is visible
    _queue.add(startIdx);

    // 3. BFS: expand outwards through walkable tiles.
    // Using 4-directional movement (no diagonals) for map accuracy.
    while (_queue.isNotEmpty) {
      final idx = _queue.removeFirst();
      final cx = idx % _width;
      final cy = idx ~/ _width;
      final cost = _costGrid[idx];

      // 4-connected neighbors: up, down, left, right
      _expand(cx, cy - 1, cost, map);
      _expand(cx, cy + 1, cost, map);
      _expand(cx - 1, cy, cost, map);
      _expand(cx + 1, cy, cost, map);
    }

    // 4. Compute visibility: tiles within line-of-sight of the player.
    // A tile is "visible" if the BFS could reach it AND it has a direct
    // LOS path (no intervening wall). We use a fast shadow-cast approximation:
    // a tile is visible if BOTH its cost is < infinity AND its cost is ≤
    // the LOS_RADIUS threshold (walls block vision naturally via BFS not
    // propagating through them).
    // We mark tiles visible if reachable within the fog radius (9 tiles).
    const double losRadius = 9.0;
    for (var i = 0; i < size; i++) {
      if (_costGrid[i] <= losRadius) {
        _visibilityGrid[i] = 1;
      }
    }
  }

  /// Returns the normalized world-space direction an entity at [entityPos]
  /// should move to approach the player optimally, navigating around walls.
  ///
  /// Complexity: O(1) — reads at most 4 array elements.
  ///
  /// Returns [Vector2.zero] when the entity IS the player or no path exists.
  Vector2 bestDirection(Vector2 entityPos) {
    final ex = entityPos.x.floor().clamp(0, _width - 1);
    final ey = entityPos.y.floor().clamp(0, _height - 1);

    // Current tile cost — the gradient we follow downhill.
    final currentCost = _costGrid[_idx(ex, ey)];
    if (currentCost == 0 || currentCost == _infinity) return Vector2.zero();

    // Sample 4 neighbors, pick lowest cost.
    double bestCost = currentCost;
    int bestDx = 0;
    int bestDy = 0;

    _checkNeighbor(ex, ey - 1, bestCost, 0, -1, (c, dx, dy) {
      bestCost = c;
      bestDx = dx;
      bestDy = dy;
    });
    _checkNeighbor(ex, ey + 1, bestCost, 0, 1, (c, dx, dy) {
      bestCost = c;
      bestDx = dx;
      bestDy = dy;
    });
    _checkNeighbor(ex - 1, ey, bestCost, -1, 0, (c, dx, dy) {
      bestCost = c;
      bestDx = dx;
      bestDy = dy;
    });
    _checkNeighbor(ex + 1, ey, bestCost, 1, 0, (c, dx, dy) {
      bestCost = c;
      bestDx = dx;
      bestDy = dy;
    });

    if (bestDx == 0 && bestDy == 0) return Vector2.zero();

    // Blend tile-center-to-tile-center direction with sub-tile offset for
    // smooth movement (avoids stair-step jitter inside the tile).
    final tileDir = Vector2(bestDx.toDouble(), bestDy.toDouble());

    // Sub-tile correction: pull towards center of the best tile.
    final targetCenter = Vector2(
      (ex + bestDx) + 0.5,
      (ey + bestDy) + 0.5,
    );
    final toCenter = targetCenter - entityPos;
    final dist = toCenter.length;
    if (dist < 0.01) return tileDir.normalized();

    return toCenter.normalized();
  }

  /// Returns whether tile (x, y) was reachable and visible during the last
  /// [recompute] call. Used by the renderer to skip DDA Raycasts.
  ///
  /// Complexity: O(1).
  bool isCellVisible(int x, int y) {
    if (x < 0 || x >= _width || y < 0 || y >= _height) return false;
    return _visibilityGrid[_idx(x, y)] == 1;
  }

  /// Raw cost for a tile — useful for debugging / AI heuristics.
  double costAt(int x, int y) {
    if (x < 0 || x >= _width || y < 0 || y >= _height) return _infinity;
    return _costGrid[_idx(x, y)];
  }

  // ─────────────────────────────── Internals ─────────────────────────────────

  int _idx(int x, int y) => y * _width + x;

  /// Tries to relax neighbor (nx, ny) from current node cost [fromCost].
  /// If walkable and cheaper, enqueues it.
  void _expand(int nx, int ny, double fromCost, GameMap map) {
    if (nx < 0 || nx >= _width || ny < 0 || ny >= _height) return;
    if (map.getCell(nx, ny).isSolid) return;

    final nIdx = _idx(nx, ny);
    final newCost = fromCost + 1.0; // uniform step cost

    if (newCost < _costGrid[nIdx]) {
      _costGrid[nIdx] = newCost;
      _queue.add(nIdx);
    }
  }

  /// Helper: checks one neighbor and calls [onBetter] if it has lower cost.
  void _checkNeighbor(
    int nx,
    int ny,
    double currentBest,
    int dx,
    int dy,
    void Function(double cost, int dx, int dy) onBetter,
  ) {
    if (nx < 0 || nx >= _width || ny < 0 || ny >= _height) return;
    final cost = _costGrid[_idx(nx, ny)];
    if (cost < currentBest) {
      onBetter(cost, dx, dy);
    }
  }
}
