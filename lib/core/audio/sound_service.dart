import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sonidos de la app (en assets/sounds, generados con
/// tool/generate_sounds.mjs).
enum MagicSound {
  sparkle('sparkle'),
  harp('harp'),
  pop('pop'),
  bloop('bloop'),
  drip('drip'),
  zap('zap'),
  swish('swish'),
  whoosh('whoosh'),
  whooshUp('whoosh_up'),
  chime('chime'),
  tada('tada');

  const MagicSound(this.file);
  final String file;

  String get assetPath => 'sounds/$file.wav';
}

/// Reproduce los sonidos mágicos y recuerda si están silenciados.
///
/// Cada sonido tiene su [AudioPool], que se crea la primera vez que suena:
/// así se puede repetir rápido (o solaparse) sin esperar a que termine.
/// Un sonido que falla nunca rompe el dibujo: se ignora.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  static const String _mutedKey = 'kikidraw_sounds_muted';

  /// Volumen moderado: que acompañe, no que aturda.
  static const double _volume = 0.6;

  /// Cuántas notas tiene la escala de los colores (note_0 .. note_9).
  static const int noteCount = 10;

  final ValueNotifier<bool> muted = ValueNotifier(false);
  final Map<String, Future<AudioPool>> _pools = {};

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      muted.value = prefs.getBool(_mutedKey) ?? false;
    } catch (e) {
      debugPrint('No se pudo leer la preferencia de sonido: $e');
    }
  }

  Future<void> toggleMuted() async {
    muted.value = !muted.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedKey, muted.value);
    } catch (e) {
      debugPrint('No se pudo guardar la preferencia de sonido: $e');
    }
  }

  /// Carga de antemano todos los sonidos del lienzo. Sin esto, la primera
  /// vez que suena cada uno hay que bajarlo y decodificarlo, y si se tocan
  /// varios colores rápido las notas salen fuera de orden.
  void preload(Iterable<String> extraPaths) {
    final paths = {
      for (final sound in MagicSound.values) sound.assetPath,
      for (var i = 0; i < noteCount; i++) 'sounds/note_$i.wav',
      ...extraPaths,
    };
    for (final path in paths) {
      unawaited(_pool(path).then((_) {}, onError: (Object e) {
        _pools.remove(path);
        debugPrint('No se pudo precargar $path: $e');
      }));
    }
  }

  void play(MagicSound sound) => playAsset(sound.assetPath);

  /// Nota de la escala pentatónica de los colores: cualquier secuencia
  /// suena bien.
  void playNote(int index) => playAsset('sounds/note_${index % noteCount}.wav');

  /// [path] relativo a assets/ (como `Brush.soundAssetPath`).
  void playAsset(String path) {
    if (muted.value) return;
    unawaited(_start(path));
  }

  Future<void> _start(String path) async {
    try {
      final pool = await _pool(path);
      await pool.start(volume: _volume);
    } catch (e) {
      // Que se pueda reintentar la próxima vez.
      _pools.remove(path);
      debugPrint('No se pudo reproducir $path: $e');
    }
  }

  Future<AudioPool> _pool(String path) => _pools[path] ??= AudioPool.createFromAsset(
        path: path,
        maxPlayers: 3,
      );
}
