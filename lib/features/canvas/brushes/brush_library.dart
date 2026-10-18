import '../../../core/models/brush.dart';
export '../../../core/models/brush.dart';

class BrushLibrary {
  static final Brush pencil = Brush(
    id: 'pencil',
    name: 'Lápiz',
    type: BrushType.basic,
    size: 6.0,
    opacity: 0.9,
    isPressureSensitive: true,
  );

  static final Brush marker = Brush(
    id: 'marker',
    name: 'Marcador',
    type: BrushType.basic,
    size: 14.0,
    opacity: 1.0,
    isPressureSensitive: false,
  );

  static final Brush watercolor = Brush(
    id: 'watercolor',
    name: 'Acuarela',
    type: BrushType.basic,
    size: 24.0,
    opacity: 0.5,
    isPressureSensitive: true,
  );

  static final Brush airbrush = Brush(
    id: 'aerografo',
    name: 'Aerógrafo',
    type: BrushType.basic,
    size: 32.0,
    opacity: 0.3,
    isPressureSensitive: true,
  );

  static final Brush eraser = Brush(
    id: 'eraser',
    name: 'Goma de borrar',
    type: BrushType.eraser,
    size: 28.0,
    opacity: 1.0,
    isPressureSensitive: false,
  );

  static final Brush neon = Brush(
    id: 'neon',
    name: 'Neón Mágico 💡',
    type: BrushType.basic,
    size: 16.0,
    opacity: 1.0,
    isPressureSensitive: true,
  );

  static final Brush stars = Brush(
    id: 'stars',
    name: 'Estrellitas ✨',
    type: BrushType.stamp,
    size: 26.0,
    opacity: 1.0,
    spacing: 28.0,
    isPressureSensitive: true,
  );

  static final Brush hearts = Brush(
    id: 'hearts',
    name: 'Corazones 💖',
    type: BrushType.stamp,
    size: 26.0,
    opacity: 1.0,
    spacing: 28.0,
    isPressureSensitive: true,
  );

  static final Brush flowers = Brush(
    id: 'flowers',
    name: 'Flores 🌸',
    type: BrushType.stamp,
    size: 28.0,
    opacity: 1.0,
    spacing: 30.0,
    isPressureSensitive: true,
  );

  static final Brush glitterShader = Brush(
    id: 'glitter_shader',
    name: 'Purpurina 🌟',
    type: BrushType.shader,
    size: 20.0,
    opacity: 1.0,
    shaderAssetPath: 'shaders/glitter.frag',
  );

  static final Brush rainbowShader = Brush(
    id: 'rainbow_shader',
    name: 'Arcoíris 🌈',
    type: BrushType.shader,
    size: 18.0,
    opacity: 1.0,
    shaderAssetPath: 'shaders/rainbow.frag',
  );

  static List<Brush> get defaultBrushes => [
        pencil,
        marker,
        watercolor,
        airbrush,
        neon,
        stars,
        hearts,
        flowers,
        glitterShader,
        rainbowShader,
        eraser,
      ];
}
