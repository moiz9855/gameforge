import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum SoundType {
  coin,
  gameStart,
  scoreUp,
  flap,
  paddleHit,
  wallHit,
  tetrisMove,
  tetrisClear,
  gameOver,
  achievement,
  // New game sounds
  snakeEat,
  snakeMove,
  snakeSpeedUp,
  buttonTap,
  buttonBack,
  difficultySelect,
  countdownTick,
  countdownGo,
  winFanfare,
  loseSound,
  drawSound,
  aiReveal,
  placeO,
  lineHighlight,
  ropePull,
  ropeSnap,
  runnerStep,
  runnerJump,
  runnerSlide,
  runnerHit,
  powerupCollect,
  shieldActivate,
  magnetActivate,
  speedBoost,
}

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final Map<SoundType, String> _cachedPaths = {};
  final List<AudioPlayer> _pool = [];
  bool _initialized = false;
  bool _muted = false;

  bool get isMuted => _muted;
  void toggleMute() {
    _muted = !_muted;
  }

  /// Pre-generates and caches all WAV sound effects in the temp directory.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final soundDir = Directory('${tempDir.path}/gameforge_sounds');
      if (!await soundDir.exists()) {
        await soundDir.create(recursive: true);
      }

      for (final type in SoundType.values) {
        final file = File('${soundDir.path}/${type.name}.wav');
        if (!await file.exists()) {
          final data = _generateSoundBytes(type);
          await file.writeAsBytes(data);
        }
        _cachedPaths[type] = file.path;
      }
      
      // Initialize a pool of 8 AudioPlayers for overlapping playbacks
      for (int i = 0; i < 8; i++) {
        _pool.add(AudioPlayer());
      }

      _initialized = true;
    } catch (e) {
      // Fallback: print error, but don't crash app
      debugPrint('SoundService initialization error: $e');
    }
  }

  /// Plays the requested sound type from cache.
  Future<void> play(SoundType type) async {
    if (_muted) return;
    if (!_initialized) {
      await init();
    }
    final path = _cachedPaths[type];
    if (path == null) return;

    try {
      // Find an idle player or use the first one
      AudioPlayer? player;
      for (final p in _pool) {
        if (p.state != PlayerState.playing) {
          player = p;
          break;
        }
      }
      player ??= _pool.first;

      await player.stop();
      await player.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('Error playing sound $type: $e');
    }
  }

  /// Generates raw WAV bytes for the specified sound type.
  Uint8List _generateSoundBytes(SoundType type) {
    const int sampleRate = 22050;
    late final List<int> samples;

    switch (type) {
      case SoundType.coin:
        // Double beep (Square wave): B5 (988Hz) for 0.08s, then E6 (1319Hz) for 0.25s
        final part1 = _synthSquare(frequency: 987.77, duration: 0.08, sampleRate: sampleRate, volume: 0.5);
        final part2 = _synthSquare(frequency: 1318.51, duration: 0.25, sampleRate: sampleRate, volume: 0.5);
        samples = [...part1, ...part2];
        break;

      case SoundType.gameStart:
        // Arpeggio: C5 (523Hz), E5 (659Hz), G5 (784Hz), C6 (1047Hz)
        final p1 = _synthSquare(frequency: 523.25, duration: 0.07, sampleRate: sampleRate, volume: 0.4);
        final p2 = _synthSquare(frequency: 659.25, duration: 0.07, sampleRate: sampleRate, volume: 0.4);
        final p3 = _synthSquare(frequency: 783.99, duration: 0.07, sampleRate: sampleRate, volume: 0.4);
        final p4 = _synthSquare(frequency: 1046.50, duration: 0.25, sampleRate: sampleRate, volume: 0.5);
        samples = [...p1, ...p2, ...p3, ...p4];
        break;

      case SoundType.scoreUp:
        // Point scored: Short high pitch beep (Square)
        samples = _synthSquare(frequency: 1100.0, duration: 0.09, sampleRate: sampleRate, volume: 0.5);
        break;

      case SoundType.flap:
        // Upward sweep: Triangle wave from 350Hz to 850Hz in 0.12s
        samples = _synthSweep(startFreq: 350.0, endFreq: 850.0, duration: 0.12, sampleRate: sampleRate, isTriangle: true, volume: 0.6);
        break;

      case SoundType.paddleHit:
        // Pong paddle bounce: Short square beep
        samples = _synthSquare(frequency: 440.0, duration: 0.08, sampleRate: sampleRate, volume: 0.5);
        break;

      case SoundType.wallHit:
        // Pong wall bounce: Lower short beep
        samples = _synthSquare(frequency: 220.0, duration: 0.09, sampleRate: sampleRate, volume: 0.5);
        break;

      case SoundType.tetrisMove:
        // Tetris slide block: Very brief low blip
        samples = _synthSquare(frequency: 140.0, duration: 0.04, sampleRate: sampleRate, volume: 0.3);
        break;

      case SoundType.tetrisClear:
        // Tetris line clear chime: 3 quick rising chimes
        final c1 = _synthSquare(frequency: 880.0, duration: 0.07, sampleRate: sampleRate, volume: 0.4);
        final c2 = _synthSquare(frequency: 1046.50, duration: 0.07, sampleRate: sampleRate, volume: 0.4);
        final c3 = _synthSquare(frequency: 1318.51, duration: 0.18, sampleRate: sampleRate, volume: 0.5);
        samples = [...c1, ...c2, ...c3];
        break;

      case SoundType.gameOver:
        // Descending sad melody: C5 (0.15s), B4 (0.15s), A4 (0.15s), F4 (0.4s)
        final n1 = _synthSquare(frequency: 523.25, duration: 0.15, sampleRate: sampleRate, volume: 0.4);
        final n2 = _synthSquare(frequency: 493.88, duration: 0.15, sampleRate: sampleRate, volume: 0.4);
        final n3 = _synthSquare(frequency: 440.00, duration: 0.15, sampleRate: sampleRate, volume: 0.4);
        final n4 = _synthSweep(startFreq: 349.23, endFreq: 250.00, duration: 0.45, sampleRate: sampleRate, isTriangle: false, volume: 0.4);
        samples = [...n1, ...n2, ...n3, ...n4];
        break;

      case SoundType.achievement:
        // Fanfare: C5 (0.07s), E5 (0.07s), G5 (0.07s), C6 (0.12s), G5 (0.07s), C6 (0.35s)
        final f1 = _synthSquare(frequency: 523.25, duration: 0.07, sampleRate: sampleRate, volume: 0.4);
        final f2 = _synthSquare(frequency: 659.25, duration: 0.07, sampleRate: sampleRate, volume: 0.4);
        final f3 = _synthSquare(frequency: 783.99, duration: 0.07, sampleRate: sampleRate, volume: 0.4);
        final f4 = _synthSquare(frequency: 1046.50, duration: 0.12, sampleRate: sampleRate, volume: 0.4);
        final f5 = _synthSquare(frequency: 783.99, duration: 0.07, sampleRate: sampleRate, volume: 0.4);
        final f6 = _synthSquare(frequency: 1046.50, duration: 0.35, sampleRate: sampleRate, volume: 0.5);
        samples = [...f1, ...f2, ...f3, ...f4, ...f5, ...f6];
        break;

      case SoundType.snakeEat:
        // Eating food: Quick upward sweep (Triangle wave munch/pop)
        samples = _synthSweep(startFreq: 220.0, endFreq: 660.0, duration: 0.1, sampleRate: sampleRate, isTriangle: true, volume: 0.6);
        break;

      case SoundType.snakeMove:
        // Subtle click on direction change
        samples = _synthSquare(frequency: 800.0, duration: 0.03, sampleRate: sampleRate, volume: 0.25);
        break;

      case SoundType.snakeSpeedUp:
        // Speed/level up jingle: 2 quick rising square tones
        final p1 = _synthSquare(frequency: 587.33, duration: 0.08, sampleRate: sampleRate, volume: 0.4);
        final p2 = _synthSquare(frequency: 880.0, duration: 0.18, sampleRate: sampleRate, volume: 0.5);
        samples = [...p1, ...p2];
        break;

      case SoundType.buttonTap:
        // Menu / standard click
        samples = _synthSquare(frequency: 600.0, duration: 0.05, sampleRate: sampleRate, volume: 0.4);
        break;

      case SoundType.buttonBack:
        // Back menu click (slightly lower pitch)
        samples = _synthSquare(frequency: 400.0, duration: 0.06, sampleRate: sampleRate, volume: 0.4);
        break;

      case SoundType.difficultySelect:
        // Difficulty select chime (two quick notes rising)
        final d1 = _synthSquare(frequency: 700.0, duration: 0.04, sampleRate: sampleRate, volume: 0.35);
        final d2 = _synthSquare(frequency: 900.0, duration: 0.08, sampleRate: sampleRate, volume: 0.4);
        samples = [...d1, ...d2];
        break;

      case SoundType.countdownTick:
        // Short beep for countdown 3, 2, 1
        samples = _synthSquare(frequency: 523.25, duration: 0.07, sampleRate: sampleRate, volume: 0.4);
        break;

      case SoundType.countdownGo:
        // Higher beep for countdown GO!
        samples = _synthSquare(frequency: 1046.50, duration: 0.25, sampleRate: sampleRate, volume: 0.5);
        break;

      case SoundType.winFanfare:
        // Victory chime arpeggio
        final w1 = _synthSquare(frequency: 523.25, duration: 0.08, sampleRate: sampleRate, volume: 0.4);
        final w2 = _synthSquare(frequency: 659.25, duration: 0.08, sampleRate: sampleRate, volume: 0.4);
        final w3 = _synthSquare(frequency: 783.99, duration: 0.08, sampleRate: sampleRate, volume: 0.4);
        final w4 = _synthSquare(frequency: 1046.50, duration: 0.25, sampleRate: sampleRate, volume: 0.5);
        samples = [...w1, ...w2, ...w3, ...w4];
        break;

      case SoundType.loseSound:
        // Fail chime arpeggio descending
        final l1 = _synthSquare(frequency: 392.00, duration: 0.15, sampleRate: sampleRate, volume: 0.4);
        final l2 = _synthSquare(frequency: 329.63, duration: 0.15, sampleRate: sampleRate, volume: 0.4);
        final l3 = _synthSquare(frequency: 261.63, duration: 0.30, sampleRate: sampleRate, volume: 0.4);
        samples = [...l1, ...l2, ...l3];
        break;

      case SoundType.drawSound:
        // Neutral tone
        final dr1 = _synthSquare(frequency: 440.00, duration: 0.15, sampleRate: sampleRate, volume: 0.4);
        final dr2 = _synthSquare(frequency: 415.30, duration: 0.20, sampleRate: sampleRate, volume: 0.4);
        samples = [...dr1, ...dr2];
        break;

      case SoundType.aiReveal:
        // Suspense sweep before move reveal
        samples = _synthSweep(startFreq: 200.0, endFreq: 400.0, duration: 0.2, sampleRate: sampleRate, isTriangle: false, volume: 0.4);
        break;

      case SoundType.placeO:
        // Different click for AI O placement in TTT
        samples = _synthSquare(frequency: 500.0, duration: 0.05, sampleRate: sampleRate, volume: 0.4);
        break;

      case SoundType.lineHighlight:
        // Shine/sparkle sound (rapid pitch sweep up)
        samples = _synthSweep(startFreq: 880.0, endFreq: 2200.0, duration: 0.25, sampleRate: sampleRate, isTriangle: true, volume: 0.5);
        break;

      case SoundType.ropePull:
        // low-mid pull/struggle sound
        samples = _synthSweep(startFreq: 150.0, endFreq: 80.0, duration: 0.08, sampleRate: sampleRate, isTriangle: false, volume: 0.5);
        break;

      case SoundType.ropeSnap:
        // whip/snap sound (descending sweep with noise)
        samples = _synthSweep(startFreq: 1000.0, endFreq: 150.0, duration: 0.15, sampleRate: sampleRate, isTriangle: false, volume: 0.7);
        break;

      case SoundType.runnerStep:
        // Footstep (short low thump)
        samples = _synthSquare(frequency: 100.0, duration: 0.03, sampleRate: sampleRate, volume: 0.15);
        break;

      case SoundType.runnerJump:
        // Whoosh up
        samples = _synthSweep(startFreq: 200.0, endFreq: 900.0, duration: 0.15, sampleRate: sampleRate, isTriangle: true, volume: 0.5);
        break;

      case SoundType.runnerSlide:
        // Swoosh down
        samples = _synthSweep(startFreq: 800.0, endFreq: 200.0, duration: 0.20, sampleRate: sampleRate, isTriangle: true, volume: 0.5);
        break;

      case SoundType.runnerHit:
        // Obstacle crash sound
        samples = _synthSweep(startFreq: 500.0, endFreq: 50.0, duration: 0.4, sampleRate: sampleRate, isTriangle: false, volume: 0.7);
        break;

      case SoundType.powerupCollect:
        // Upward jingle
        final pw1 = _synthSquare(frequency: 523.25, duration: 0.05, sampleRate: sampleRate, volume: 0.4);
        final pw2 = _synthSquare(frequency: 783.99, duration: 0.05, sampleRate: sampleRate, volume: 0.4);
        final pw3 = _synthSquare(frequency: 1046.50, duration: 0.15, sampleRate: sampleRate, volume: 0.5);
        samples = [...pw1, ...pw2, ...pw3];
        break;

      case SoundType.shieldActivate:
        // Shield bubble sound
        samples = _synthSweep(startFreq: 600.0, endFreq: 1200.0, duration: 0.25, sampleRate: sampleRate, isTriangle: true, volume: 0.5);
        break;

      case SoundType.magnetActivate:
        // Magnet buzz sound
        samples = _synthSweep(startFreq: 300.0, endFreq: 500.0, duration: 0.25, sampleRate: sampleRate, isTriangle: false, volume: 0.5);
        break;

      case SoundType.speedBoost:
        // Speed up sound
        samples = _synthSweep(startFreq: 400.0, endFreq: 1600.0, duration: 0.35, sampleRate: sampleRate, isTriangle: false, volume: 0.5);
        break;
    }

    // Build the WAV file header
    final header = _buildWavHeader(samples.length, sampleRate);
    final fileBytes = Uint8List(header.length + samples.length);
    fileBytes.setRange(0, header.length, header);
    fileBytes.setRange(header.length, fileBytes.length, samples);

    return fileBytes;
  }

  /// Builds a mono 8-bit PCM WAV header.
  Uint8List _buildWavHeader(int dataLength, int sampleRate) {
    final header = ByteData(44);

    // RIFF Chunk
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataLength, Endian.little);
    
    // Format
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt subchunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // Linear PCM
    header.setUint16(22, 1, Endian.little); // 1 channel
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate, Endian.little); // Byte rate (SampleRate * 1 channel * 1 byte/sample)
    header.setUint16(32, 1, Endian.little); // Block align
    header.setUint16(34, 8, Endian.little); // 8-bit samples

    // data subchunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataLength, Endian.little);

    return header.buffer.asUint8List();
  }

  /// Synthesizes a fixed-frequency square wave.
  List<int> _synthSquare({
    required double frequency,
    required double duration,
    required int sampleRate,
    required double volume,
  }) {
    final int numSamples = (duration * sampleRate).toInt();
    final List<int> data = List<int>.filled(numSamples, 128);
    final double periodSamples = sampleRate / frequency;

    for (int i = 0; i < numSamples; i++) {
      // Linear envelope fade-out in last 15% to avoid pops
      double env = 1.0;
      if (i > numSamples * 0.85) {
        env = (numSamples - i) / (numSamples * 0.15);
      }

      final double phase = (i % periodSamples) / periodSamples;
      final double waveVal = phase < 0.5 ? 1.0 : -1.0;
      final int sample = (128 + waveVal * 127 * volume * env).clamp(0, 255).toInt();
      data[i] = sample;
    }
    return data;
  }

  /// Synthesizes a frequency sweep (linear ramp) with optional triangle waveform.
  List<int> _synthSweep({
    required double startFreq,
    required double endFreq,
    required double duration,
    required int sampleRate,
    required bool isTriangle,
    required double volume,
  }) {
    final int numSamples = (duration * sampleRate).toInt();
    final List<int> data = List<int>.filled(numSamples, 128);

    double phase = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final double progress = i / numSamples;
      // Frequency linear sweep
      final double currentFreq = startFreq + (endFreq - startFreq) * progress;
      
      // Update phase based on current frequency
      phase += (2 * math.pi * currentFreq) / sampleRate;

      // Amplitude envelope (decay over duration)
      double env = 1.0 - progress; // Fade out linearly
      if (progress < 0.05) {
        env = progress / 0.05; // Fade in quickly (first 5%)
      }

      double waveVal;
      if (isTriangle) {
        // Triangle wave: goes from -1 to 1 to -1
        final normPhase = (phase % (2 * math.pi)) / (2 * math.pi);
        waveVal = normPhase < 0.5 ? (4.0 * normPhase - 1.0) : (3.0 - 4.0 * normPhase);
      } else {
        // Square wave
        waveVal = (phase % (2 * math.pi)) < math.pi ? 1.0 : -1.0;
      }

      // Add a bit of noise on hits (sweeps starting high going low)
      if (!isTriangle && startFreq > endFreq && progress > 0.3) {
        final rand = (math.Random().nextDouble() * 2) - 1.0;
        waveVal = waveVal * 0.7 + rand * 0.3;
      }

      final int sample = (128 + waveVal * 127 * volume * env).clamp(0, 255).toInt();
      data[i] = sample;
    }
    return data;
  }
}
