import 'dart:math';
import 'package:raycasting_game/features/core/world/models/game_map.dart';

class MapGenerator {
  static const int minRoomSize = 6;
  static const int maxRoomSize = 12;

  /// Generates a randomized dungeon using BSP (Binary Space Partitioning).
  ///
  /// [seed] makes the map reproducible. Pass the level seed for consistency.
  static GameMap generate(int width, int height, {int? seed}) {
    final rng = seed != null ? Random(seed) : Random();

    // 1. Initialize map with walls
    final grid = List.generate(
      height,
      (_) => List.generate(width, (_) => Cell.wall),
    );

    // 2. Create the root leaf
    final root = _Leaf(0, 0, width, height, rng);
    final leafs = <_Leaf>[root];

    // 3. Split recursively
    var didSplit = true;
    while (didSplit) {
      didSplit = false;
      for (final l in List<_Leaf>.from(leafs)) {
        if (l.leftChild == null && l.rightChild == null) {
          if (l.width > maxRoomSize ||
              l.height > maxRoomSize ||
              rng.nextBool()) {
            if (l.split()) {
              leafs.add(l.leftChild!);
              leafs.add(l.rightChild!);
              didSplit = true;
            }
          }
        }
      }
    }

    // 4. Create Rooms inside leaves
    root.createRooms();

    // 5. Carve Rooms into Grid
    void carveLeaf(_Leaf l) {
      if (l.room != null) {
        final r = l.room!;
        for (var y = r.y; y < r.y + r.height; y++) {
          for (var x = r.x; x < r.x + r.width; x++) {
            if (y >= 0 && y < height && x >= 0 && x < width) {
              grid[y][x] = Cell.empty;
            }
          }
        }
      }
      if (l.leftChild != null) carveLeaf(l.leftChild!);
      if (l.rightChild != null) carveLeaf(l.rightChild!);
    }

    void connect(_Leaf l) {
      if (l.leftChild != null && l.rightChild != null) {
        _createHall(l.leftChild!, l.rightChild!, grid);
        connect(l.leftChild!);
        connect(l.rightChild!);
      }
    }

    carveLeaf(root);
    connect(root);

    // Add Borders (Bedrock)
    for (var x = 0; x < width; x++) {
      grid[0][x] = Cell.wall;
      grid[height - 1][x] = Cell.wall;
    }
    for (var y = 0; y < height; y++) {
      grid[y][0] = Cell.wall;
      grid[y][width - 1] = Cell.wall;
    }

    // Assign varying wall textures
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (grid[y][x].isSolid) {
          // Mix Bricks (1) and Stone (2)
          final type = rng.nextInt(10) > 7 ? 2 : 1;
          grid[y][x] = Cell(type: type, isSolid: true, textureId: type);
        }
      }
    }

    // 6. Collect room rects from all leaves for spawn placement
    final rooms = <RoomRect>[];
    void collectRooms(_Leaf l) {
      if (l.room != null) rooms.add(l.room!);
      if (l.leftChild != null) collectRooms(l.leftChild!);
      if (l.rightChild != null) collectRooms(l.rightChild!);
    }

    collectRooms(root);

    // 7. Place Exit Door in the most border-adjacent room.
    //    Player spawns in rooms.first, so skip it when picking the exit room.
    ({int x, int y})? exitPos;

    if (rooms.length > 1) {
      final candidates = rooms.skip(1).toList();

      RoomRect? exitRoom;
      var minBorderDist = double.infinity;

      for (final r in candidates) {
        final distLeft = r.x.toDouble();
        final distTop = r.y.toDouble();
        final distRight = (width - (r.x + r.width)).toDouble();
        final distBottom = (height - (r.y + r.height)).toDouble();
        final minDist = [
          distLeft,
          distTop,
          distRight,
          distBottom,
        ].reduce((a, b) => a < b ? a : b);

        if (minDist < minBorderDist) {
          minBorderDist = minDist;
          exitRoom = r;
        }
      }

      if (exitRoom != null) {
        final ex = exitRoom.x + exitRoom.width ~/ 2;
        final ey = exitRoom.y + exitRoom.height ~/ 2;
        grid[ey][ex] = cellExit;
        exitPos = (x: ex, y: ey);
      }
    }

    return GameMap(
      width: width,
      height: height,
      grid: grid,
      roomRects: rooms,
      seed: seed,
      exitCellPosition: exitPos,
    );
  }

  static void _createHall(_Leaf l, _Leaf r, List<List<Cell>> grid) {
    var x1 = l.x + l.width ~/ 2;
    var y1 = l.y + l.height ~/ 2;
    final x2 = r.x + r.width ~/ 2;
    final y2 = r.y + r.height ~/ 2;

    while (x1 != x2) {
      grid[y1][x1] = Cell.empty;
      x1 += (x2 - x1).sign;
    }
    while (y1 != y2) {
      grid[y1][x1] = Cell.empty;
      y1 += (y2 - y1).sign;
    }
  }
}

class _Leaf {
  _Leaf(this.x, this.y, this.width, this.height, this._rng);

  final int x;
  final int y;
  final int width;
  final int height;
  final Random _rng;
  _Leaf? leftChild;
  _Leaf? rightChild;
  RoomRect? room;

  bool split() {
    if (leftChild != null || rightChild != null) return false;

    var splitH = _rng.nextBool();
    if (width > height && width / height >= 1.25) {
      splitH = false;
    } else if (height > width && height / width >= 1.25) {
      splitH = true;
    }

    final max = (splitH ? height : width) - MapGenerator.minRoomSize;
    if (max <= MapGenerator.minRoomSize) return false;

    final split =
        _rng.nextInt(max - MapGenerator.minRoomSize) + MapGenerator.minRoomSize;

    if (splitH) {
      leftChild = _Leaf(x, y, width, split, _rng);
      rightChild = _Leaf(x, y + split, width, height - split, _rng);
    } else {
      leftChild = _Leaf(x, y, split, height, _rng);
      rightChild = _Leaf(x + split, y, width - split, height, _rng);
    }
    return true;
  }

  void createRooms() {
    if (leftChild != null || rightChild != null) {
      leftChild?.createRooms();
      rightChild?.createRooms();
    } else {
      room = RoomRect(x + 1, y + 1, width - 2, height - 2);
    }
  }
}
