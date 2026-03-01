import 'package:equatable/equatable.dart';

/// Estado del lore desbloqueado por el jugador.
/// Persiste via HydratedBloc para mantener progreso entre sesiones.
class LoreState extends Equatable {
  const LoreState({
    required this.ecosDesbloqueados,
    required this.primeraSesion,
    required this.fragmentosMemoria,
  });

  factory LoreState.initial() {
    return const LoreState(
      ecosDesbloqueados: {},
      primeraSesion: true,
      fragmentosMemoria: 0,
    );
  }

  /// Reconstruye el estado desde JSON
  factory LoreState.fromJson(Map<String, dynamic> json) {
    return LoreState(
      ecosDesbloqueados: Set<String>.from(json['ecosDesbloqueados'] as List),
      primeraSesion: json['primeraSesion'] as bool,
      fragmentosMemoria: json['fragmentosMemoria'] as int? ?? 0,
    );
  }

  /// IDs de Ecos Narrativos que el jugador ha descubierto
  final Set<String> ecosDesbloqueados;

  /// Flag para saber si debe mostrarse la intro
  final bool primeraSesion;

  /// Cantidad de fragmentos de memoria recolectados
  final int fragmentosMemoria;

  LoreState copyWith({
    Set<String>? ecosDesbloqueados,
    bool? primeraSesion,
    int? fragmentosMemoria,
  }) {
    return LoreState(
      ecosDesbloqueados: ecosDesbloqueados ?? this.ecosDesbloqueados,
      primeraSesion: primeraSesion ?? this.primeraSesion,
      fragmentosMemoria: fragmentosMemoria ?? this.fragmentosMemoria,
    );
  }

  /// Convierte el estado a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'ecosDesbloqueados': ecosDesbloqueados.toList(),
      'primeraSesion': primeraSesion,
      'fragmentosMemoria': fragmentosMemoria,
    };
  }

  @override
  List<Object?> get props => [
    ecosDesbloqueados,
    primeraSesion,
    fragmentosMemoria,
  ];
}
