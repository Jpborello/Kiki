import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/models/layer.dart';

class LayerPainter extends CustomPainter {
  final List<Layer> layers;
  final Map<String, ui.Image> layerImages;

  LayerPainter({
    required this.layers,
    required this.layerImages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Ordenar por capa
    final sorted = List<Layer>.from(layers)..sort((a, b) => a.order.compareTo(b.order));

    for (final layer in sorted) {
      if (!layer.visible) continue;

      final img = layerImages[layer.id];
      if (img != null) {
        final paint = Paint()
          ..color = Color.fromRGBO(255, 255, 255, layer.opacity)
          ..blendMode = layer.blendMode;

        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(0, 0, size.width, size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LayerPainter oldDelegate) {
    return oldDelegate.layers != layers || oldDelegate.layerImages != layerImages;
  }
}
