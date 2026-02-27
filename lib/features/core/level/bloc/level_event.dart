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

/// Fired every frame to decrement the survival timer.
final class SurvivalTick extends LevelEvent {
  const SurvivalTick(this.dt);
  final double dt;

  @override
  List<Object?> get props => [dt];
}

/// Fired by WorldBloc listener when an enemy dies.
final class EnemyKilledRegistered extends LevelEvent {
  const EnemyKilledRegistered();
}

/// Fired from the victory or death screen — resets the game.
final class SurvivalRestarted extends LevelEvent {
  const SurvivalRestarted();
}
