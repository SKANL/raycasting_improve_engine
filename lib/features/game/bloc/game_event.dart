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
