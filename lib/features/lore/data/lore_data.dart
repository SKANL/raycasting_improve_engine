import '../models/lore_model.dart';

class LoreData {
  static const List<LoreEntry> allEntries = [
    LoreEntry(
      id: 'video_intro',
      title: 'Archivo: Despertar',
      content: 'Registro visual del inicio de la consciencia del Sujeto 7.',
      mediaPath: 'assets/video/intro_despertar.mp4',
      isVideo: true,
    ),
    LoreEntry(
      id: 'video_flashback',
      title: 'Archivo: Núcleo',
      content: 'Fragmento de memoria recuperado: El origen del colapso.',
      mediaPath: 'assets/video/flashback_nucleo.mp4',
      isVideo: true,
    ),
    LoreEntry(
      id: 'video_final_good',
      title: 'Archivo: Ascensión',
      content: 'Proyección de un futuro posible: La superación del ciclo.',
      mediaPath: 'assets/video/final_bueno.mp4',
      isVideo: true,
    ),
    LoreEntry(
      id: 'video_final_bad',
      title: 'Archivo: Silencio',
      content: 'Proyección de un futuro posible: La asimilación total.',
      mediaPath: 'assets/video/final_malo.mp4',
      isVideo: true,
    ),
    LoreEntry(
      id: 'lore_1',
      title: '1. La Guerra Silenciosa',
      content:
          'En el apogeo de una guerra fría no declarada, las agencias de inteligencia globales buscaban la ventaja definitiva: la infiltración indetectable. El "Proyecto Casandra" nació de esta necesidad. Su nombre clave proviene de la profetisa mítica, condenada a ver el futuro sin que nadie le creyera; una metáfora de la arrogancia científica del proyecto.\n\nEl objetivo no era simplemente mejorar la percepción humana. El objetivo era convertir la percepción en un arma.',
    ),
    LoreEntry(
      id: 'lore_2',
      title: '2. Metodología Casandra',
      content:
          'Dirigido por la misteriosa organización "Aethel", el Proyecto Casandra reclutó a sujetos con sinestesia auditiva.\n\n1. La Privación: Ceguera inducida para recablear el cerebro.\n2. La Imbuición: Tratamientos químicos para desbloquear el potencial sónico.\n\nEl objetivo: Crear al "Infiltrado Sónico", un agente capaz de ver con el sonido y demoler estructuras con el "Grito de Ruptura".',
    ),
    LoreEntry(
      id: 'lore_3',
      title: '3. El Fracaso: Las Resonancias',
      content:
          'El proyecto fue un fracaso. La "Imbuición" fue demasiado. Los sobrevivientes se convirtieron en "Las Resonancias".\n\nAtrapados en una agonía sensorial constante, su poder sónico se manifiesta en explosiones incontroladas. Cazan cualquier sonido para silenciarlo y aliviar su propio tormento. No son malvados, son víctimas rotas.',
    ),
    LoreEntry(
      id: 'lore_4',
      title: '4. Sujeto 7 (Tú)',
      content:
          'Tú eres el Sujeto 7. El único éxito.\n\nTu ceguera es total, pero tu mente procesa los ecos con claridad perfecta. Tu cuerpo contiene la energía. Eres el prototipo funcional.\n\nEras el activo más valioso, mantenido en contención hasta que todo colapsó.',
    ),
    LoreEntry(
      id: 'lore_5',
      title: '5. El Incidente',
      content:
          'Nadie sabe qué lo desencadenó. Una Resonancia Alfa perdió el control, desatando un Grito de Ruptura que provocó una reacción en cadena.\n\nLas instalaciones se derrumbaron. El personal fue masacrado. El complejo se convirtió en una tumba de hormigón y silencio.',
    ),
    LoreEntry(
      id: 'lore_6',
      title: '6. Canibalismo Energético',
      content:
          'Te despiertas en el caos. Tu "Grito de Ruptura" es tu única arma, pero consume tu vida.\n\nPara sobrevivir, debes absorber los "Núcleos Resonantes" de tus hermanos caídos. Es un acto de canibalismo energético. Estás reabsorbiendo su esencia para recargar la tuya.',
    ),
    LoreEntry(
      id: 'lore_7',
      title: '7. Ecos Narrativos',
      content:
          'Al absorber un Núcleo, absorbes fragmentos de conciencia. Recuerdos, agonía, locura.\n\nEstos son los "Ecos Narrativos". Voces del pasado, memorias de otros sujetos... que empiezan a mezclarse con las tuyas.\n\nTu objetivo es escapar antes de que el "ruido" de tus hermanos ahogue tu propia mente.',
    ),
  ];

  static LoreEntry getById(String id) {
    return allEntries.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('LoreEntry not found: $id'),
    );
  }
}
