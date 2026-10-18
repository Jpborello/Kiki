import 'package:flutter/material.dart';

class Layer {
  final String id;
  String name;
  int order;
  double opacity; // 0.0 .. 1.0
  BlendMode blendMode;
  bool visible;
  bool locked; // p.ej. foto de fondo congelada
  String? imagePath; // PNG horneado guardado en disco

  Layer({
    required this.id,
    required this.name,
    required this.order,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
    this.visible = true,
    this.locked = false,
    this.imagePath,
  });

  Layer copyWith({
    String? name,
    int? order,
    double? opacity,
    BlendMode? blendMode,
    bool? visible,
    bool? locked,
    String? imagePath,
  }) {
    return Layer(
      id: id,
      name: name ?? this.name,
      order: order ?? this.order,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
        'opacity': opacity,
        'blendMode': blendMode.index,
        'visible': visible,
        'locked': locked,
        'imagePath': imagePath,
      };

  factory Layer.fromJson(Map<String, dynamic> json) {
    return Layer(
      id: json['id'] as String,
      name: json['name'] as String,
      order: (json['order'] as num).toInt(),
      opacity: (json['opacity'] as num).toDouble(),
      blendMode: BlendMode.values[(json['blendMode'] as num).toInt()],
      visible: json['visible'] as bool,
      locked: json['locked'] as bool,
      imagePath: json['imagePath'] as String?,
    );
  }
}
