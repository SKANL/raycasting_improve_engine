import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:raycasting_game/features/menu/menu_page.dart';

class MenuTransitionScreen extends StatefulWidget {
  const MenuTransitionScreen({super.key});

  @override
  State<MenuTransitionScreen> createState() => _MenuTransitionScreenState();
}

class _MenuTransitionScreenState extends State<MenuTransitionScreen> {
  String _statusText = 'TERMINANDO PROCESOS DEL MOTOR...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _executeShutdownSequence();
  }

  Future<void> _executeShutdownSequence() async {
    // Step 1: Simulate engine termination
    await Future<void>.delayed(const Duration(milliseconds: 600));
    Flame.images.clearCache();
    Flame.assets.clearCache();
    if (mounted) {
      setState(() {
        _statusText = 'PURGANDO MEMORIA CACHÉ...';
        _progress = 0.4;
      });
    }

    // Step 2: Clear memory (artificial delay for professional feel)
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() {
        _statusText = 'PREPARANDO ENTORNO ASEPTICO...';
        _progress = 0.8;
      });
    }

    // Step 3: Finalize and route
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _statusText = 'CONEXIÓN AL MENÚ ESTABLECIDA.';
        _progress = 1.0;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      // Use pushAndRemoveUntil to completely wipe the navigation stack and start fresh
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MenuPage()),
        (route) => false,
      );
    }
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
                color: const Color(
                  0xFF4DD0E1,
                ), // Clinical cyan matching the new theme
                fontSize: 18,
                letterSpacing: 3.0,
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
