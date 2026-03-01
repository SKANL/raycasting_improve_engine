import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  const FullScreenVideoPlayer({super.key, required this.assetPath});

  final String assetPath;

  static Route<void> route(String assetPath) {
    return MaterialPageRoute<void>(
      builder: (_) => FullScreenVideoPlayer(assetPath: assetPath),
    );
  }

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
        _controller.addListener(_checkVideoEnd);
      });
  }

  void _checkVideoEnd() {
    if (_isClosing) return;

    final value = _controller.value;
    // Usamos un umbral de 500ms para asegurar que detecte el final
    // incluso si hay pequeñas discrepancias en la duración reportada.
    if (value.position >= value.duration - const Duration(milliseconds: 500)) {
      _close();
    }
  }

  void _close() {
    if (_isClosing) return;
    _isClosing = true;

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkVideoEnd);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _close, // Permite cerrar tocando cualquier parte
        child: Stack(
          children: [
            Center(
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(color: Colors.cyan),
            ),
            // Botón para saltar/cerrar
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: _close,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
