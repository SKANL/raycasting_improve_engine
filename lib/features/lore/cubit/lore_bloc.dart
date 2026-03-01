import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'lore_state.dart';

/// Eventos para gestionar el lore
abstract class LoreEvent {}

/// Desbloquear un eco narrativo específico
class DesbloquearEco extends LoreEvent {
  DesbloquearEco(this.ecoId);
  final String ecoId;
}

/// Marcar que ya no es primera sesión (intro vista)
class MarcarIntroVista extends LoreEvent {}

/// Evento cuando se obtiene un fragmento de memoria
class FragmentoObtenido extends LoreEvent {}

/// BLoC persistente que gestiona el progreso del lore
class LoreBloc extends HydratedBloc<LoreEvent, LoreState> {
  LoreBloc() : super(LoreState.initial()) {
    on<DesbloquearEco>(_onDesbloquearEco);
    on<MarcarIntroVista>(_onMarcarIntroVista);
    on<FragmentoObtenido>(_onFragmentoObtenido);
  }

  void _onFragmentoObtenido(FragmentoObtenido event, Emitter<LoreState> emit) {
    final nuevosFragmentos = state.fragmentosMemoria + 1;
    final Set<String> nuevosEcos = Set.from(state.ecosDesbloqueados);

    // Lógica de desbloqueo progresivo
    if (nuevosFragmentos >= 5) nuevosEcos.add('video_intro');
    if (nuevosFragmentos >= 10) nuevosEcos.add('video_flashback');
    if (nuevosFragmentos >= 15) nuevosEcos.add('video_final_good');
    if (nuevosFragmentos >= 20) nuevosEcos.add('video_final_bad');

    emit(
      state.copyWith(
        fragmentosMemoria: nuevosFragmentos,
        ecosDesbloqueados: nuevosEcos,
      ),
    );
  }

  void _onDesbloquearEco(DesbloquearEco event, Emitter<LoreState> emit) {
    if (state.ecosDesbloqueados.contains(event.ecoId)) {
      return; // Ya desbloqueado
    }

    emit(
      state.copyWith(
        ecosDesbloqueados: {...state.ecosDesbloqueados, event.ecoId},
      ),
    );
  }

  void _onMarcarIntroVista(MarcarIntroVista event, Emitter<LoreState> emit) {
    emit(state.copyWith(primeraSesion: false));
  }

  @override
  LoreState? fromJson(Map<String, dynamic> json) {
    try {
      return LoreState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(LoreState state) {
    try {
      return state.toJson();
    } catch (_) {
      return null;
    }
  }
}
