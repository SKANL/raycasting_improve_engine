import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:raycasting_game/features/core/input/models/game_action.dart';

part 'input_event.dart';
part 'input_state.dart';

/// Manages input state by listening to abstract Action events.
/// This allows multiple sources (keyboard, gamepad, touch) to trigger the same logic.
class InputBloc extends Bloc<InputEvent, InputState> {
  InputBloc() : super(const InputState()) {
    on<ActionStarted>(_onActionStarted);
    on<ActionEnded>(_onActionEnded);
    on<AnalogInputChanged>(_onAnalogInputChanged);
  }

  void _onActionStarted(ActionStarted event, Emitter<InputState> emit) {
    if (state.activeActions.contains(event.action)) return;

    final updatedActions = Set<GameAction>.from(state.activeActions)
      ..add(event.action);

    emit(state.copyWith(activeActions: updatedActions));
  }

  void _onActionEnded(ActionEnded event, Emitter<InputState> emit) {
    if (!state.activeActions.contains(event.action)) return;

    final updatedActions = Set<GameAction>.from(state.activeActions)
      ..remove(event.action);

    emit(state.copyWith(activeActions: updatedActions));
  }

  void _onAnalogInputChanged(
    AnalogInputChanged event,
    Emitter<InputState> emit,
  ) {
    emit(state.copyWith(axisX: event.axisX, axisY: event.axisY));
  }
}
