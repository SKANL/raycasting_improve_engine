import 'package:audioplayers/audioplayers.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:raycasting_game/core/logging/log_service.dart';

/// Centralized Audio Management Service (Singleton)
///
/// Architecture:
/// - BGM  → Dedicated AudioPlayer with ReleaseMode.loop + AudioContext
///           set to duckOthers=false / mixWithOthers on every platform.
/// - SFX  → AudioPool per sound (pre-warmed, shares same AudioContext).
///
/// Key insight: On Android, any AudioPlayer that requests
/// AudioFocus.GAIN will pause other players.  We avoid this by:
///   1. Setting a global AudioContext that uses AndroidAudioFocus.gainTransientMayDuck
///      (never GAIN) for the BGM player.
///   2. Creating every AudioPool *after* the global context is set so
///      they inherit it.
class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() => _instance;

  AudioService._internal();

  // Dedicated BGM player (never shares pool logic)
  AudioPlayer? _bgmPlayer;

  // SFX pools — one AudioPool per frequently-fired sound
  AudioPool? _pistolFirePool;
  AudioPool? _shotgunFirePool;
  AudioPool? _reloadPool;
  AudioPool? _emptyClipPool;
  AudioPool? _weaponSwitchPool;

  // Volume settings
  double _masterVolume = 1;
  double _musicVolume = 0.3;
  double _sfxVolume = 1;

  bool _isInitialized = false;

  /// Initialize service: configure AudioContext globally, create BGM player
  /// and pre-warm all SFX pools.
  Future<void> init() async {
    if (_isInitialized) {
      LogService.info('AUDIO', 'ALREADY_INITIALIZED', {});
      return;
    }

    try {
      // ── 1. Configure global AudioContext ──────────────────────────────
      // This affects EVERY AudioPlayer created after this point,
      // including the internals of AudioPool.
      //
      // Android: gainTransientMayDuck → allows background music to keep
      //          playing at reduced volume; we bump it back immediately.
      //          isSpeakerphoneOn / staysActiveAfterStop keep the session alive.
      // iOS    : mixWithOthers → never interrupts other audio.
      AudioPlayer.global.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.music,
            isSpeakerphoneOn: false,
          ),
          iOS: AudioContextIOS(
            options: {
              AVAudioSessionOptions.mixWithOthers,
            },
            category: AVAudioSessionCategory.playback,
          ),
        ),
      );

      // ── 2. Create dedicated BGM player ────────────────────────────────
      _bgmPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.setVolume(_musicVolume * _masterVolume);

      // ── 3. Pre-warm SFX AudioPools ────────────────────────────────────
      _pistolFirePool = await AudioPool.create(
        source: AssetSource('audio/weapons/pistol_fire.wav'),
        maxPlayers: 4,
      );
      _shotgunFirePool = await AudioPool.create(
        source: AssetSource('audio/weapons/shotgun_fire.wav'),
        maxPlayers: 2,
      );
      _reloadPool = await AudioPool.create(
        source: AssetSource('audio/weapons/reload.wav'),
        maxPlayers: 2,
      );
      _emptyClipPool = await AudioPool.create(
        source: AssetSource('audio/weapons/empty_clip.wav'),
        maxPlayers: 2,
      );
      _weaponSwitchPool = await AudioPool.create(
        source: AssetSource('audio/weapons/weapon_switch.wav'),
        maxPlayers: 2,
      );

      _isInitialized = true;
      LogService.info('AUDIO', 'SERVICE_INITIALIZED', {});
    } on Exception catch (e) {
      LogService.error('AUDIO', 'INIT_FAILED', e);
      _isInitialized = true; // allow game to continue without audio
    }
  }

  /// Play background music (looping).
  /// [assetPath] is relative to assets/ (e.g. 'audio/musica_fondo/Vertical_Layering.mp3')
  Future<void> playBackgroundMusic(
    String assetPath, {
    double? volume,
    int fadeInDuration = 1000,
  }) async {
    if (_bgmPlayer == null) return;
    try {
      final finalVolume = (volume ?? _musicVolume) * _masterVolume;
      await _bgmPlayer!.setVolume(finalVolume);
      await _bgmPlayer!.setSource(AssetSource(assetPath));
      await _bgmPlayer!.resume();
      LogService.info('AUDIO', 'BACKGROUND_MUSIC_STARTED', {
        'asset': assetPath,
        'volume': finalVolume.toStringAsFixed(2),
      });
    } on Exception catch (e) {
      LogService.error('AUDIO', 'BACKGROUND_MUSIC_LOAD_ERROR', e);
    }
  }

  /// Play a weapon sound effect using the per-sound AudioPool.
  /// [assetPath] relative to assets/audio/ (e.g. 'weapons/pistol_fire.wav')
  Future<void> playSFX(
    String assetPath, {
    double? volume,
  }) async {
    if (!_isInitialized) return;

    try {
      final finalVolume = (volume ?? _sfxVolume) * _masterVolume;

      final pool = _poolForPath(assetPath);
      if (pool != null) {
        await pool.start(volume: finalVolume);
      } else {
        // Fallback for any unregistered sound
        await FlameAudio.play(assetPath, volume: finalVolume);
      }

      LogService.info('AUDIO', 'SFX_PLAYED', {
        'asset': assetPath,
        'volume': finalVolume.toStringAsFixed(2),
      });
    } on Exception catch (e) {
      LogService.error('AUDIO', 'SFX_PLAY_ERROR', e);
    }
  }

  AudioPool? _poolForPath(String path) {
    if (path.contains('pistol_fire')) return _pistolFirePool;
    if (path.contains('shotgun_fire')) return _shotgunFirePool;
    if (path.contains('reload')) return _reloadPool;
    if (path.contains('empty_clip')) return _emptyClipPool;
    if (path.contains('weapon_switch') || path.contains('change-weapon')) {
      return _weaponSwitchPool;
    }
    return null;
  }

  /// Stop the background music.
  Future<void> stopBackgroundMusic({int fadeOutDuration = 500}) async {
    try {
      await _bgmPlayer?.stop();
      LogService.info('AUDIO', 'BACKGROUND_MUSIC_STOPPED', {});
    } on Exception catch (e) {
      LogService.error('AUDIO', 'BACKGROUND_MUSIC_STOP_ERROR', e);
    }
  }

  /// Update master volume.
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
    _bgmPlayer?.setVolume(_musicVolume * _masterVolume).ignore();
    LogService.info('AUDIO', 'MASTER_VOLUME_CHANGED', {
      'volume': _masterVolume.toStringAsFixed(2),
    });
  }

  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
    _bgmPlayer?.setVolume(_musicVolume * _masterVolume).ignore();
    LogService.info('AUDIO', 'MUSIC_VOLUME_CHANGED', {
      'volume': _musicVolume.toStringAsFixed(2),
    });
  }

  void setSFXVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
    LogService.info('AUDIO', 'SFX_VOLUME_CHANGED', {
      'volume': _sfxVolume.toStringAsFixed(2),
    });
  }

  double get masterVolume => _masterVolume;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  /// Release all audio resources.
  Future<void> dispose() async {
    try {
      await _bgmPlayer?.stop();
      await _bgmPlayer?.dispose();
      _bgmPlayer = null;
      await _pistolFirePool?.dispose();
      await _shotgunFirePool?.dispose();
      await _reloadPool?.dispose();
      await _emptyClipPool?.dispose();
      await _weaponSwitchPool?.dispose();
      await FlameAudio.audioCache.clearAll();
      _isInitialized = false;
      LogService.info('AUDIO', 'SERVICE_DISPOSED', {});
    } on Exception catch (e) {
      LogService.error('AUDIO', 'DISPOSE_ERROR', e);
    }
  }
}
