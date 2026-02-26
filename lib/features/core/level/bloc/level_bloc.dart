import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'level_event.dart';
part 'level_state.dart';

class LevelBloc extends Bloc<LevelEvent, LevelState> {
  LevelBloc() : super(const LevelState()) {
    on<LevelStarted>(_onLevelStarted);
    on<LevelCleared>(_onLevelCleared);
    on<ExitReached>(_onExitReached);
    on<LevelTransitionComplete>(_onLevelTransitionComplete);
    on<GameRestarted>(_onGameRestarted);
  }

  void _onLevelStarted(LevelStarted event, Emitter<LevelState> emit) {
    final seed = Random().nextInt(1 << 30);
    emit(
      state.copyWith(
        currentLevel: 1,
        status: LevelStatus.playing,
        sessionSeed: seed,
      ),
    );
  }

  void _onLevelCleared(LevelCleared event, Emitter<LevelState> emit) {
    if (state.status != LevelStatus.playing) return;
    emit(state.copyWith(status: LevelStatus.cleared));
  }

  void _onExitReached(ExitReached event, Emitter<LevelState> emit) {
    if (state.status != LevelStatus.cleared) return;
    emit(state.copyWith(status: LevelStatus.transitioning));
  }

  void _onLevelTransitionComplete(
    LevelTransitionComplete event,
    Emitter<LevelState> emit,
  ) {
    if (state.status != LevelStatus.transitioning) return;

    final nextLevel = state.currentLevel + 1;

    if (nextLevel > LevelState.maxLevel) {
      emit(state.copyWith(status: LevelStatus.victory));
    } else {
      emit(
        state.copyWith(
          currentLevel: nextLevel,
          status: LevelStatus.playing,
        ),
      );
    }
  }

  void _onGameRestarted(GameRestarted event, Emitter<LevelState> emit) {
    final seed = Random().nextInt(1 << 30);
    emit(
      state.copyWith(
        currentLevel: 1,
        status: LevelStatus.playing,
        sessionSeed: seed,
      ),
    );
  }
}
