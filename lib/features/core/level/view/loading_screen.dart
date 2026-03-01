import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:raycasting_game/features/core/world/bloc/world_bloc.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _statusText = 'CARGANDO MÓDULOS...';
  double _progress = 0.0;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _startLoadingSequence();
    }
  }

  Future<void> _startLoadingSequence() async {
    // 1. Wait for Flutter route transition animation to finish
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() {
      _statusText = 'PURGANDO MEMORIA CACHÉ...';
      _progress = 0.3;
    });

    Flame.images.clearCache();
    Flame.assets.clearCache();

    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() {
      _statusText = 'INICIALIZANDO ENTORNO CLÍNICO...';
      _progress = 0.7;
    });

    // 2. Trigger heavy world initialization
    if (mounted) {
      context.read<WorldBloc>().add(
        const WorldInitialized(width: 32, height: 32),
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;
    setState(() {
      _statusText = 'SINTETIZANDO EL MAPA MENTAL...';
      _progress = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _statusText,
              style: GoogleFonts.courierPrime(
                color: const Color(0xFF4DD0E1), // Clinical cyan
                fontSize: 18,
                letterSpacing: 2.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            // Minimalist sci-fi loading indicator
            SizedBox(
              width: 300,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: const Color(0xFF111111),
                color: const Color(0xFF4DD0E1),
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
