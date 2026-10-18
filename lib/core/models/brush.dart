enum BrushType {
  basic,
  stamp,
  shader,
  eraser,
}

class Brush {
  final String id;
  final String name;
  final BrushType type;
  double size;
  double opacity;
  double spacing; // para stamp brushes
  bool isPressureSensitive;
  String? stampAssetPath;
  String? shaderAssetPath;
  String? soundAssetPath;

  Brush({
    required this.id,
    required this.name,
    required this.type,
    this.size = 12.0,
    this.opacity = 1.0,
    this.spacing = 10.0,
    this.isPressureSensitive = true,
    this.stampAssetPath,
    this.shaderAssetPath,
    this.soundAssetPath,
  });

  Brush copyWith({
    double? size,
    double? opacity,
    double? spacing,
    bool? isPressureSensitive,
  }) {
    return Brush(
      id: id,
      name: name,
      type: type,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      spacing: spacing ?? this.spacing,
      isPressureSensitive: isPressureSensitive ?? this.isPressureSensitive,
      stampAssetPath: stampAssetPath,
      shaderAssetPath: shaderAssetPath,
      soundAssetPath: soundAssetPath,
    );
  }
}
