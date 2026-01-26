import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:raycasting_game/features/core/perspective/models/perspective.dart';

part 'perspective_event.dart';
part 'perspective_state.dart';

/// Manages the game's viewing perspective and transitions.
class PerspectiveBloc extends Bloc<PerspectiveEvent, PerspectiveState> {
  PerspectiveBloc() : super(PerspectiveState.initial()) {
    on<PerspectiveToggled>(_onToggled);
    on<PerspectiveChanged>(_onChanged);
  }

  void _onToggled(PerspectiveToggled event, Emitter<PerspectiveState> emit) {
    // Cycle: 3D -> 2D -> Iso -> 3D
    final nextIndex = (state.current.index + 1) % Perspective.values.length;
    final nextPerspective = Perspective.values[nextIndex];

    add(PerspectiveChanged(nextPerspective));
  }

  void _onChanged(PerspectiveChanged event, Emitter<PerspectiveState> emit) {
    if (state.current == event.perspective) return;

    // In a real implementation with animations, we would:
    // 1. emit(state.copyWith(previous: state.current, current: event.perspective, isTransitioning: true, transitionProgress: 0.0));
    // 2. Start a ticker to update transitionProgress
    // 3. When done, emit(state.copyWith(isTransitioning: false, transitionProgress: 1.0));

    // For now, instant switch:
    emit(
      state.copyWith(
        previous: state.current,
        current: event.perspective,
        isTransitioning: false,
        transitionProgress: 1,
      ),
    );
  }
}
