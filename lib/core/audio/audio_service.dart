import 'package:audioplayers/audioplayers.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:raycasting_game/core/logging/log_service.dart';

/// Centralized Audio Management Service (Singleton)
///
/// Handles background music and SFX playback with proper lifecycle management.
/// Supports volume control, fade in/out, and resource pooling.
class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() => _instance;

  AudioService._internal();

  // Background music player (always single instance)
  AudioPlayer? _backgroundMusic;

  // Volume settings (0.0 = silent, 1.0 = loud)
  double _masterVolume = 1.0;
  // Music is intentionally quieter so SFX (weapons, hits) are always audible.
  double _musicVolume = 0.3;
  // SFX at full volume — must punch through background music clearly.
  double _sfxVolume = 1.0;

  // Initialization flag
  bool _isInitialized = false;

  /// Initialize audio service and preload all SFX assets.
  ///
  /// On Flutter Web, `AssetSource` is served without a `Content-Type` header,
  /// causing Chrome to reject `.wav` files (`Format error Code 4`).
  /// Pre-loading via `FlameAudio.audioCache` downloads the file using XHR
  /// and stores it as a Blob URL with the correct MIME type, which the browser
  /// accepts without issues.
  Future<void> init() async {
    if (_isInitialized) {
      LogService.info('AUDIO', 'ALREADY_INITIALIZED', {});
      return;
    }

    // Pre-cache all SFX so FlameAudio.play() uses Blob URLs instead of
    // raw asset paths (which Chrome rejects without Content-Type header).
    await FlameAudio.audioCache.loadAll([
      'audio/weapons/pistol_fire.wav',
      'audio/weapons/shotgun_fire.wav',
      'audio/weapons/reload.wav',
      'audio/weapons/empty_clip.wav',
      'audio/weapons/weapon_switch.wav',
      'audio/weapons/change-weapon-sound.wav',
    ]);

    _isInitialized = true;
    LogService.info('AUDIO', 'SERVICE_INITIALIZED', {});
  }

  /// Play background music with fade-in effect
  ///
  /// Stops current music and starts the new one.
  /// [assetPath] = path relative to assets/ (e.g., 'audio/background.mp3')
  /// [volume] = 0.0-1.0 (default uses _musicVolume setting)
  /// [fadeInDuration] = fade-in time in milliseconds (default 1000ms)
  Future<void> playBackgroundMusic(
    String assetPath, {
    double? volume,
    int fadeInDuration = 1000,
  }) async {
    try {
      // Stop and dispose old music
      await _backgroundMusic?.stop();
      await _backgroundMusic?.dispose();

      // Create new player
      _backgroundMusic = AudioPlayer();

      final effectiveVolume = volume ?? _musicVolume;
      final finalVolume = effectiveVolume * _masterVolume;

      // Set to silent first
      await _backgroundMusic!.setVolume(0.0);

      // Load and play
      await _backgroundMusic!.setSource(AssetSource(assetPath));
      await _backgroundMusic!.setReleaseMode(ReleaseMode.loop);
      await _backgroundMusic!.resume();

      // Fade in
      await _fadeInVolume(
        _backgroundMusic!,
        finalVolume,
        fadeInDuration,
      );

      LogService.info('AUDIO', 'BACKGROUND_MUSIC_STARTED', {
        'asset': assetPath,
        'volume': finalVolume.toStringAsFixed(2),
      });
    } catch (e) {
      LogService.error('AUDIO', 'BACKGROUND_MUSIC_LOAD_ERROR', e);
    }
  }

  /// Play sound effect using FlameAudio (Web-safe).
  ///
  /// FlameAudio manages player lifecycle correctly on Flutter Web,
  /// avoiding the `MEDIA_ELEMENT_ERROR: Format error` that occurs
  /// when manually reusing AudioPlayers with released sources.
  /// [assetPath] = path relative to assets/ (e.g., 'audio/weapons/pistol_fire.wav')
  /// [volume] = 0.0-1.0 (default uses _sfxVolume setting)
  Future<void> playSFX(
    String assetPath, {
    double? volume,
  }) async {
    try {
      final finalVolume = (volume ?? _sfxVolume) * _masterVolume;
      // FlameAudio.play() creates a fresh player each time,
      // properly loading the asset from cache and releasing on completion.
      await FlameAudio.play(assetPath, volume: finalVolume);

      LogService.info('AUDIO', 'SFX_PLAYED', {
        'asset': assetPath,
        'volume': finalVolume.toStringAsFixed(2),
      });
    } catch (e) {
      LogService.error('AUDIO', 'SFX_PLAY_ERROR', e);
    }
  }

  /// Stop background music with fade-out effect
  ///
  /// [fadeOutDuration] = fade-out time in milliseconds (default 500ms)
  Future<void> stopBackgroundMusic({int fadeOutDuration = 500}) async {
    if (_backgroundMusic == null) return;

    try {
      await _fadeOutVolume(_backgroundMusic!, fadeOutDuration);
      await _backgroundMusic!.stop();
      await _backgroundMusic!.dispose();
      _backgroundMusic = null;

      LogService.info('AUDIO', 'BACKGROUND_MUSIC_STOPPED', {});
    } catch (e) {
      LogService.error('AUDIO', 'BACKGROUND_MUSIC_STOP_ERROR', e);
    }
  }

  /// Update master volume (affects all audio)
  ///
  /// [volume] = 0.0-1.0
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);

    // Apply to current background music
    if (_backgroundMusic != null) {
      final musicVol = _musicVolume * _masterVolume;
      _backgroundMusic!.setVolume(musicVol).ignore();
    }

    LogService.info('AUDIO', 'MASTER_VOLUME_CHANGED', {
      'volume': _masterVolume.toStringAsFixed(2),
    });
  }

  /// Update music volume (only affects new music)
  ///
  /// [volume] = 0.0-1.0
  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
    LogService.info('AUDIO', 'MUSIC_VOLUME_CHANGED', {
      'volume': _musicVolume.toStringAsFixed(2),
    });
  }

  /// Update SFX volume (only affects new SFX)
  ///
  /// [volume] = 0.0-1.0
  void setSFXVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
    LogService.info('AUDIO', 'SFX_VOLUME_CHANGED', {
      'volume': _sfxVolume.toStringAsFixed(2),
    });
  }

  /// Get current master volume
  double get masterVolume => _masterVolume;

  /// Get current music volume
  double get musicVolume => _musicVolume;

  /// Get current SFX volume
  double get sfxVolume => _sfxVolume;

  /// Dispose all audio resources (call on app shutdown).
  Future<void> dispose() async {
    try {
      await _backgroundMusic?.stop();
      await _backgroundMusic?.dispose();
      _backgroundMusic = null;

      // FlameAudio manages its own player lifecycle — no manual cleanup needed.
      await FlameAudio.audioCache.clearAll();

      _isInitialized = false;
      LogService.info('AUDIO', 'SERVICE_DISPOSED', {});
    } catch (e) {
      LogService.error('AUDIO', 'DISPOSE_ERROR', e);
    }
  }

  /// Helper: Fade in volume smoothly
  Future<void> _fadeInVolume(
    AudioPlayer player,
    double targetVolume,
    int durationMs,
  ) async {
    const steps = 20;
    final stepDuration = Duration(milliseconds: durationMs ~/ steps);
    final volumeStep = targetVolume / steps;

    for (var i = 1; i <= steps; i++) {
      await Future.delayed(stepDuration);
      final vol = (volumeStep * i).clamp(0.0, 1.0);
      await player.setVolume(vol);
    }
  }

  /// Helper: Fade out volume smoothly
  Future<void> _fadeOutVolume(
    AudioPlayer player,
    int durationMs,
  ) async {
    const steps = 10;
    final stepDuration = Duration(milliseconds: durationMs ~/ steps);
    final currentVolume = 1.0; // Assume was at full volume
    final volumeStep = currentVolume / steps;

    for (var i = steps - 1; i >= 0; i--) {
      await Future.delayed(stepDuration);
      final vol = (volumeStep * i).clamp(0.0, 1.0);
      await player.setVolume(vol);
    }
  }
}
