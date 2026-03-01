import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cubit/lore_bloc.dart';
import '../cubit/lore_state.dart';
import '../data/lore_data.dart';
import 'video_player_screen.dart';

class JourneyPage extends StatelessWidget {
  const JourneyPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const JourneyPage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ECOS DE LA MEMORIA',
              style: GoogleFonts.courierPrime(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            BlocBuilder<LoreBloc, LoreState>(
              builder: (context, loreState) {
                final fragmentos = loreState.fragmentosMemoria;
                final paraProximo = 5 - (fragmentos % 5);
                return Text(
                  'Fragmentos: $fragmentos/20 ($paraProximo para el siguiente)',
                  style: GoogleFonts.robotoMono(
                    color: Colors.cyan.withOpacity(0.7),
                    fontSize: 12,
                  ),
                );
              },
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocBuilder<LoreBloc, LoreState>(
        builder: (context, state) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: LoreData.allEntries.length,
            itemBuilder: (context, index) {
              final entry = LoreData.allEntries[index];
              final isUnlocked =
                  true; // state.ecosDesbloqueados.contains(entry.id);

              return Card(
                color: Colors.black.withAlpha((0.5 * 255).round()),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: isUnlocked ? Colors.cyan : Colors.grey.shade800,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    enabled: isUnlocked,
                    leading: Icon(
                      isUnlocked ? Icons.record_voice_over : Icons.lock,
                      color: isUnlocked ? Colors.cyanAccent : Colors.grey,
                    ),
                    title: Text(
                      isUnlocked ? entry.title : '???',
                      style: GoogleFonts.courierPrime(
                        color: isUnlocked ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: [
                      if (isUnlocked)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.content,
                                style: GoogleFonts.robotoMono(
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                              if (entry.mediaPath != null) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    if (entry.isVideo &&
                                        entry.mediaPath != null) {
                                      Navigator.of(context).push(
                                        FullScreenVideoPlayer.route(
                                          entry.mediaPath!,
                                        ),
                                      );
                                    } else {
                                      // TODO: Implement audio playback
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Reproduciendo archivo de audio...',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    entry.isVideo
                                        ? Icons.play_circle
                                        : Icons.audiotrack,
                                  ),
                                  label: const Text('REPRODUCIR ARCHIVO'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyan.withAlpha(
                                      (0.2 * 255).round(),
                                    ),
                                    foregroundColor: Colors.cyanAccent,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
