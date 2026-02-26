part of 'level_bloc.dart';

/// Events that drive the level progression system.
sealed class LevelEvent extends Equatable {
  const LevelEvent();

  @override
  List<Object?> get props => [];
}

/// Starts the game from level 1.
final class LevelStarted extends LevelEvent {
  const LevelStarted();
}

/// Fired by WorldBloc listener when all enemies are dead.
final class LevelCleared extends LevelEvent {
  const LevelCleared();
}

/// Fired when the player physically enters the exit cell.
final class ExitReached extends LevelEvent {
  const ExitReached();
}

/// Fired by [LevelTransitionOverlay] once the new world is loaded.
final class LevelTransitionComplete extends LevelEvent {
  const LevelTransitionComplete();
}

/// Fired from the victory screen — resets to level 1.
final class GameRestarted extends LevelEvent {
  const GameRestarted();
}
