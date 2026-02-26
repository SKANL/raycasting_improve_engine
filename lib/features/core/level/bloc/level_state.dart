part of 'level_bloc.dart';

/// Status of the level progression.
enum LevelStatus {
  /// Not started yet.
  initial,

  /// Level is actively being played.
  playing,

  /// All enemies killed — exit open, waiting for player to enter.
  cleared,

  /// Player entered exit — fade-out and world reload in progress.
  transitioning,

  /// Player completed level 6.
  victory,
}

class LevelState extends Equatable {
  const LevelState({
    this.status = LevelStatus.initial,
    this.currentLevel = 1,
    this.sessionSeed = 0,
  });

  /// Current level number (1–6).
  final int currentLevel;

  /// Progression status.
  final LevelStatus status;

  /// Base seed for this play-through. Each level uses (sessionSeed + currentLevel).
  final int sessionSeed;

  /// Total number of levels in the game.
  static const int maxLevel = 6;

  /// Seed to use for the current level generation.
  int get levelSeed => sessionSeed + currentLevel;

  LevelState copyWith({
    int? currentLevel,
    LevelStatus? status,
    int? sessionSeed,
  }) {
    return LevelState(
      currentLevel: currentLevel ?? this.currentLevel,
      status: status ?? this.status,
      sessionSeed: sessionSeed ?? this.sessionSeed,
    );
  }

  @override
  List<Object?> get props => [currentLevel, status, sessionSeed];
}
