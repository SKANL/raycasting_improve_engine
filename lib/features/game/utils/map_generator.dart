import 'dart:math';
import 'package:raycasting_game/features/core/world/models/game_map.dart';

class MapGenerator {
  static const int minRoomSize = 6;
  static const int maxRoomSize = 12;

  /// Generates a randomized dungeon using BSP (Binary Space Partitioning).
  static GameMap generate(int width, int height) {
    // 1. Initialize map with walls
    final grid = List.generate(
      height,
      (_) => List.generate(width, (_) => Cell.wall),
    );

    // 2. Create the root leaf
    final root = _Leaf(0, 0, width, height);
    final leafs = <_Leaf>[root];

    // 3. Split recursively
    var didSplit = true;
    while (didSplit) {
      didSplit = false;
      for (final l in List<_Leaf>.from(leafs)) {
        if (l.leftChild == null && l.rightChild == null) {
          // Attempt split
          if (l.width > maxRoomSize ||
              l.height > maxRoomSize ||
              Random().nextBool()) {
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
      if (l.leftChild != null) {
        carveLeaf(l.leftChild!);
      }
      if (l.rightChild != null) {
        carveLeaf(l.rightChild!);
      }
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
    final rng = Random();
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (grid[y][x].isSolid) {
          // Mix Bricks (1) and Stone (2)
          final type = rng.nextInt(10) > 7 ? 2 : 1;
          grid[y][x] = Cell(type: type, isSolid: true, textureId: type);
        }
      }
    }

    return GameMap(width: width, height: height, grid: grid);
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

class _Rect {
  _Rect(this.x, this.y, this.width, this.height);
  final int x;
  final int y;
  final int width;
  final int height;
}

class _Leaf {
  _Leaf(this.x, this.y, this.width, this.height);
  final int x;
  final int y;
  final int width;
  final int height;
  _Leaf? leftChild;
  _Leaf? rightChild;
  _Rect? room;

  bool split() {
    if (leftChild != null || rightChild != null) {
      return false;
    }

    // Determine direction
    var splitH = Random().nextBool();
    if (width > height && width / height >= 1.25) {
      splitH = false; // vertical split
    } else if (height > width && height / width >= 1.25) {
      splitH = true; // horizontal split
    }

    final max = (splitH ? height : width) - MapGenerator.minRoomSize;
    if (max <= MapGenerator.minRoomSize) {
      return false;
    }

    final split =
        Random().nextInt(max - MapGenerator.minRoomSize) +
        MapGenerator.minRoomSize; // simple random

    if (splitH) {
      leftChild = _Leaf(x, y, width, split);
      rightChild = _Leaf(x, y + split, width, height - split);
    } else {
      leftChild = _Leaf(x, y, split, height);
      rightChild = _Leaf(x + split, y, width - split, height);
    }
    return true;
  }

  void createRooms() {
    if (leftChild != null || rightChild != null) {
      leftChild?.createRooms();
      rightChild?.createRooms();
    } else {
      // Create a room with some padding inside the leaf
      // Padding of 1 to ensure walls between rooms
      room = _Rect(x + 1, y + 1, width - 2, height - 2);
    }
  }
}
