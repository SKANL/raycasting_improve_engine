import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'level_event.dart';
part 'level_state.dart';

class LevelBloc extends Bloc<LevelEvent, LevelState> {
  LevelBloc() : super(const LevelState()) {
    on<LevelStarted>(_onSurvivalStarted);
    on<SurvivalTick>(_onSurvivalTick);
    on<EnemyKilledRegistered>(_onEnemyKilledRegistered);
    on<SurvivalRestarted>(_onSurvivalRestarted);
  }

  void _onSurvivalStarted(LevelStarted event, Emitter<LevelState> emit) {
    final seed = Random().nextInt(1 << 30);
    emit(
      state.copyWith(
        status: LevelStatus.playing,
        timeRemaining: 120.0,
        enemiesKilled: 0,
        sessionSeed: seed,
      ),
    );
  }

  void _onSurvivalTick(SurvivalTick event, Emitter<LevelState> emit) {
    if (state.status != LevelStatus.playing) return;

    final newTime = (state.timeRemaining - event.dt).clamp(0.0, 120.0);

    // Victoria: timer llegó a 0
    if (newTime <= 0) {
      emit(
        state.copyWith(
          timeRemaining: 0,
          status: LevelStatus.victory,
        ),
      );
      return;
    }

    emit(state.copyWith(timeRemaining: newTime));
  }

  void _onEnemyKilledRegistered(
    EnemyKilledRegistered event,
    Emitter<LevelState> emit,
  ) {
    if (state.status != LevelStatus.playing) return;
    emit(state.copyWith(enemiesKilled: state.enemiesKilled + 1));
  }

  void _onSurvivalRestarted(SurvivalRestarted event, Emitter<LevelState> emit) {
    final seed = Random().nextInt(1 << 30);
    emit(
      state.copyWith(
        status: LevelStatus.playing,
        timeRemaining: 120.0,
        enemiesKilled: 0,
        sessionSeed: seed,
      ),
    );
  }
}
