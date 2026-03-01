import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:raycasting_game/features/game/view/game_page.dart';
import 'menu_game.dart';

/// Main menu page: Stack of video background + Flame game overlay.
///
/// The video contains the title "BLACK ECHO", subtitle "PROJECT CASSANDRA",
/// sonar waves, and HUD decorations. The Flame overlay renders the
/// menu items (INICIAR, CONTINUAR, OPCIONES, CRÉDITOS) and ambient particles.
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with TickerProviderStateMixin {
  late VideoPlayerController _videoControllerMain;
  late VideoPlayerController _videoControllerStatic;
  late AudioPlayer _audioPlayer;
  late MenuGame _menuGame;
  Timer? _fallbackTimer;
  bool _isPlayingMain = true;

  bool _showMenuUI = false; // Controls exactly when the Flame Game is mounted

  @override
  void initState() {
    super.initState();
    _menuGame = MenuGame(onMenuAction: _handleMenuAction);
    _initVideo();
    _initAudio();

    // Safety fallback: Force show UI after 2.5 seconds if video fails/stalls
    // This ensures the user is never stuck on a black screen without buttons
    _fallbackTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && !_showMenuUI) {
        debugPrint('⚠️ Video load timeout: Forcing menu UI visibility');
        setState(() {
          _showMenuUI = true;
          // Set videoReady to true so we don't show the loading spinner anymore
          // (implicit via showMenuUI)
        });
      }
    });
  }

  Future<void> _initVideo() async {
    // 1. Initialize Main Video
    _videoControllerMain = VideoPlayerController.asset(
      'assets/video/menu_bg.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    // 2. Initialize Static Effect Video
    _videoControllerStatic = VideoPlayerController.asset(
      'assets/video/efect_static.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await Future.wait([
        _videoControllerMain.initialize(),
        _videoControllerStatic.initialize(),
      ]);

      // Video configuration
      _videoControllerMain.setVolume(0);
      _videoControllerStatic.setVolume(0);

      // Add listeners for loop logic and UI mounting
      _videoControllerMain.addListener(_mainVideoListener);
      _videoControllerStatic.addListener(_staticVideoListener);

      // Start ping-pong loop
      await _videoControllerMain.play();
    } catch (e) {
      debugPrint('Video init error: $e');
      // Fallback timer will catch this case and show the menu
    }
  }

  void _mainVideoListener() {
    // UI mounting logic once first frame is verified
    if (_videoControllerMain.value.isPlaying &&
        _videoControllerMain.value.position > Duration.zero &&
        !_showMenuUI) {
      debugPrint('🎬 Main video rendering confirmed. Mounting Menu UI.');
      if (mounted) {
        setState(() => _showMenuUI = true);
        _fallbackTimer?.cancel();
      }
    }

    // Loop transition logic (Main -> Static)
    if (_videoControllerMain.value.position >=
            _videoControllerMain.value.duration &&
        _videoControllerMain.value.duration > Duration.zero) {
      debugPrint('Main video ended. Switching to Static.');
      _videoControllerMain.pause();
      _videoControllerMain.seekTo(Duration.zero);
      setState(() => _isPlayingMain = false);
      _videoControllerStatic.play();
    }
  }

  void _staticVideoListener() {
    // Loop transition logic (Static -> Main)
    if (_videoControllerStatic.value.position >=
            _videoControllerStatic.value.duration &&
        _videoControllerStatic.value.duration > Duration.zero) {
      debugPrint('Static video ended. Switching to Main.');
      _videoControllerStatic.pause();
      _videoControllerStatic.seekTo(Duration.zero);
      setState(() => _isPlayingMain = true);
      _videoControllerMain.play();
    }
  }

  Future<void> _initAudio() async {
    _audioPlayer = AudioPlayer();

    try {
      await _audioPlayer.setSource(AssetSource('audio/menu_music.ogg'));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0);
      await _audioPlayer.resume();

      // Fade in over 2 seconds
      _fadeInAudio();
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  Future<void> _fadeInAudio() async {
    const steps = 20;
    const duration = Duration(milliseconds: 100); // 20 steps × 100ms = 2s

    for (var i = 1; i <= steps; i++) {
      await Future.delayed(duration);
      if (!mounted) return;
      await _audioPlayer.setVolume((i / steps) * 0.5); // Max volume 0.5
    }
  }

  void _handleMenuAction(int index) {
    if (index == 0) {
      // INICIAR -> Navigation to Loading/Game Stream
      _audioPlayer.stop(); // Ensure menu music stops immediately
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (context) => const GamePage()),
      );
    } else if (index == 1) {
      // CRÉDITOS
      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.black.withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFFFFFFF), width: 1.5),
            ),
            title: const Text(
              'CRÉDITOS',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontFamily: 'Courier Prime',
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Desarrolladores:\nJose Gaspar Anguas Ku\nIsaias Bernal Padron\n\nAudio y Videos:\nJuan Manuel Duarte Tah\nJoel Antonio Pool Martinez',
              style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontFamily: 'Courier Prime',
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'CERRAR',
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      // SALIR
      final labels = ['INICIAR', 'CRÉDITOS', 'SALIR'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${labels[index]} (No disponible)',
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFF0A0E14),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _videoControllerMain.removeListener(_mainVideoListener);
    _videoControllerMain.dispose();
    _videoControllerStatic.removeListener(_staticVideoListener);
    _videoControllerStatic.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 0: Black fallback (always present)
          const ColoredBox(color: Colors.black),

          // Layer 1.1: Main Video background
          if (_videoControllerMain.value.isInitialized)
            AnimatedOpacity(
              opacity: _isPlayingMain ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoControllerMain.value.size.width,
                    height: _videoControllerMain.value.size.height,
                    child: VideoPlayer(_videoControllerMain),
                  ),
                ),
              ),
            ),

          // Layer 1.2: Static Effect Video background
          if (_videoControllerStatic.value.isInitialized)
            AnimatedOpacity(
              opacity: _isPlayingMain ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoControllerStatic.value.size.width,
                    height: _videoControllerStatic.value.size.height,
                    child: VideoPlayer(_videoControllerStatic),
                  ),
                ),
              ),
            ),

          // Layer 2: Menu UI (Gradient + Flame)
          // STRICTLY SEQUENTIAL: Only build this subtree if _showMenuUI is true
          if (_showMenuUI) ...[
            // Layer 2.1: Dark gradient vignette
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 0.7, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),

            // Layer 2.2: Flame game overlay
            // Built only after video is ready (or fallback timeout)
            SizedBox.expand(
              child: GameWidget(
                game: _menuGame,
                backgroundBuilder: (context) => const SizedBox.shrink(),
                loadingBuilder: (context) => const SizedBox.shrink(),
              ),
            ),
          ],

          // Loading indicator (while waiting for video or timeout)
          if (!_showMenuUI)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00E5FF),
                strokeWidth: 2.0,
              ),
            ),
        ],
      ),
    );
  }
}
