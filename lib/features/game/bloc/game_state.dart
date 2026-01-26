import 'package:equatable/equatable.dart';

enum GameStatus { initial, loading, playing, paused, gameOver }

/// Simplified GameState for UI only.
/// World data (map, entities, etc.) is now in WorldBloc.
class GameState extends Equatable {
  const GameState({
    this.status = GameStatus.initial,
    this.score = 0,
    this.health = 100,
  });

  final GameStatus status;
  final int score;
  final int health;

  GameState copyWith({
    GameStatus? status,
    int? score,
    int? health,
  }) {
    return GameState(
      status: status ?? this.status,
      score: score ?? this.score,
      health: health ?? this.health,
    );
  }

  @override
  List<Object?> get props => [status, score, health];
}
