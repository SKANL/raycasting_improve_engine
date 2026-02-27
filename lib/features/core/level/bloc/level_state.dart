part of 'level_bloc.dart';

/// Status of the level progression.
enum LevelStatus {
  /// Not started yet.
  initial,

  /// Level is actively being played.
  playing,

  /// Player survived the time limit.
  victory,
}

class LevelState extends Equatable {
  const LevelState({
    this.status = LevelStatus.initial,
    this.timeRemaining = 120.0,
    this.enemiesKilled = 0,
    this.sessionSeed = 0,
  });

  /// Progression status.
  final LevelStatus status;

  /// Time remaining in seconds for survival mode.
  final double timeRemaining;

  /// Number of enemies killed during this session.
  final int enemiesKilled;

  /// Base seed for this play-through.
  final int sessionSeed;

  LevelState copyWith({
    LevelStatus? status,
    double? timeRemaining,
    int? enemiesKilled,
    int? sessionSeed,
  }) {
    return LevelState(
      status: status ?? this.status,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      enemiesKilled: enemiesKilled ?? this.enemiesKilled,
      sessionSeed: sessionSeed ?? this.sessionSeed,
    );
  }

  @override
  List<Object?> get props => [
    status,
    timeRemaining,
    enemiesKilled,
    sessionSeed,
  ];
}
