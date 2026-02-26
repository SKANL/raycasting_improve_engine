import 'package:equatable/equatable.dart';

sealed class GameEvent extends Equatable {
  const GameEvent();

  @override
  List<Object?> get props => [];
}

class GameStarted extends GameEvent {
  const GameStarted();
}

class GamePaused extends GameEvent {
  const GamePaused();
}

class ScoreChanged extends GameEvent {
  const ScoreChanged(this.score);
  final int score;

  @override
  List<Object> get props => [score];
}

class PlayerDamaged extends GameEvent {
  const PlayerDamaged(this.amount);
  final int amount;

  @override
  List<Object> get props => [amount];
}

/// Fired during level transition to restore health (+10 HP per level).
class HealthRestored extends GameEvent {
  const HealthRestored(this.amount);
  final int amount;

  @override
  List<Object> get props => [amount];
}
