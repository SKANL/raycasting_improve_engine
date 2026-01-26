import 'package:equatable/equatable.dart';

/// Types of cells in the game map.
enum CellType {
  /// Empty walkable space.
  empty, // 0
  /// Solid wall.
  wall, // 1
  /// Openable door (future expansion).
  door, // 2
  /// Destructible wall (future expansion).
  destructible, // 3
  /// Secret wall that can be pushed (future expansion).
  secret, // 4
}

/// Represents a single grid cell in the game world.
///
/// Packed with data to be eventually sent to the Shader.
/// Each cell maps to one pixel in the map texture.
class Cell extends Equatable {
  const Cell({
    required this.type,
    this.floorHeight = 0.0,
    this.ceilingHeight = 1.0,
    this.textureId = 0,
    this.isSolid = false,
    this.lightLevel = 1.0,
    this.metadata = 0,
  });

  /// Cell type (0 = Empty, 1 = Wall, etc.).
  final int type;

  /// Floor height (0.0 = bottom to 1.0 = top) for isometric.
  final double floorHeight;

  /// Ceiling height for variable height walls.
  final double ceilingHeight;

  /// Index in the Texture Atlas (0-255).
  final int textureId;

  /// Physics collision flag.
  final bool isSolid;

  /// Ambient light level (0.0 = dark, 1.0 = fully lit).
  /// Used for baked lighting in static areas.
  final double lightLevel;

  /// Extra metadata (door state, breakable health, etc.).
  /// Packed as single int for shader efficiency.
  final int metadata;

  /// Creates a standard empty air cell.
  static const empty = Cell(type: 0);

  /// Creates a standard solid wall.
  static const wall = Cell(type: 1, isSolid: true, textureId: 1);

  /// Creates a copy with optional overrides.
  Cell copyWith({
    int? type,
    double? floorHeight,
    double? ceilingHeight,
    int? textureId,
    bool? isSolid,
    double? lightLevel,
    int? metadata,
  }) {
    return Cell(
      type: type ?? this.type,
      floorHeight: floorHeight ?? this.floorHeight,
      ceilingHeight: ceilingHeight ?? this.ceilingHeight,
      textureId: textureId ?? this.textureId,
      isSolid: isSolid ?? this.isSolid,
      lightLevel: lightLevel ?? this.lightLevel,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
    type,
    floorHeight,
    ceilingHeight,
    textureId,
    isSolid,
    lightLevel,
    metadata,
  ];
}

/// The entire game map container.
///
/// Limited to 128x128 as per performance budget.
/// This is the source of truth for world geometry.
class GameMap extends Equatable {
  const GameMap({
    required this.width,
    required this.height,
    required this.grid,
    this.seed,
  });

  /// Factory for empty map filled with air.
  factory GameMap.empty({required int width, required int height}) {
    return GameMap(
      width: width,
      height: height,
      grid: List.generate(
        height,
        (_) => List.generate(
          width,
          (_) => Cell.empty,
        ),
      ),
    );
  }

  /// Map width in cells.
  final int width;

  /// Map height in cells.
  final int height;

  /// 2D grid of cells (row-major: grid(y, x)).
  final List<List<Cell>> grid;

  /// Seed used for generation (for reproducibility).
  final int? seed;

  /// Gets a cell safely, returning wall for out-of-bounds.
  Cell getCell(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return Cell.wall;
    }
    return grid[y][x];
  }

  /// Creates a new map with a single cell changed.
  GameMap withCellAt(int x, int y, Cell cell) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return this;
    }

    final newGrid = List<List<Cell>>.from(
      grid.map(List<Cell>.from),
    );
    newGrid[y][x] = cell;

    return GameMap(
      width: width,
      height: height,
      grid: newGrid,
      seed: seed,
    );
  }

  @override
  List<Object?> get props => [width, height, grid, seed];
}
