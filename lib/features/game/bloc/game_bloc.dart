import 'package:bloc/bloc.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';
import 'package:raycasting_game/features/game/bloc/bloc.dart';

class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc({required this.worldBloc}) : super(const GameState()) {
    on<GameStarted>(_onGameStarted);
    on<PlayerDamaged>(_onPlayerDamaged);
    on<HealthRestored>(_onHealthRestored);
  }

  final WorldBloc worldBloc;

  void _onPlayerDamaged(PlayerDamaged event, Emitter<GameState> emit) {
    var newHealth = state.health - event.amount;
    if (newHealth < 0) newHealth = 0;

    // Check game over
    // var status = state.status;
    // if (newHealth == 0) {
    //   status = GameStatus.gameOver;
    // }

    emit(state.copyWith(health: newHealth));
  }

  void _onGameStarted(
    GameStarted event,
    Emitter<GameState> emit,
  ) {
    emit(state.copyWith(status: GameStatus.playing));
  }

  void _onHealthRestored(HealthRestored event, Emitter<GameState> emit) {
    final newHealth = (state.health + event.amount).clamp(0, 100);
    emit(state.copyWith(health: newHealth));
  }
}
