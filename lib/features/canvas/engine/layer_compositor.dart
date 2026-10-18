import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/models/layer.dart';
import '../../../core/models/museum_frame.dart';

class LayerCompositor {
  static Future<ui.Image> createBlankImage(Size size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    canvas.drawColor(Colors.transparent, BlendMode.clear);
    final picture = recorder.endRecording();
    return picture.toImage(size.width.toInt(), size.height.toInt());
  }

  /// Compone todas las capas visibles en una sola imagen.
  /// Soporta opcionalmente marco de museo y firma de Kiara Zoe.
  static Future<ui.Image> flattenLayers({
    required List<Layer> layers,
    required Map<String, ui.Image> layerImages,
    required Size canvasSize,
    ui.Image? tracingImage,
    double tracingOpacity = 0.4,
    bool includeTracing = false,
    MuseumFrame frame = MuseumFrame.none,
    bool includeSignature = true,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
    );
    canvas.drawColor(Colors.white, BlendMode.src);

    // Si se incluye la imagen de calco al fondo
    if (includeTracing && tracingImage != null) {
      final paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, tracingOpacity)
        ..blendMode = BlendMode.srcOver;
      canvas.drawImageRect(
        tracingImage,
        Rect.fromLTWH(0, 0, tracingImage.width.toDouble(), tracingImage.height.toDouble()),
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        paint,
      );
    }

    final sorted = List<Layer>.from(layers)
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final layer in sorted) {
      if (!layer.visible) continue;
      final img = layerImages[layer.id];
      if (img == null) continue;

      final paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, layer.opacity)
        ..blendMode = layer.blendMode;

      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        paint,
      );
    }

    // Dibujar marco artístico si corresponde
    _paintMuseumFrame(canvas, canvasSize, frame);

    // Dibujar firma artística
    if (includeSignature) {
      _paintArtistSignature(canvas, canvasSize);
    }

    final picture = recorder.endRecording();
    return picture.toImage(canvasSize.width.toInt(), canvasSize.height.toInt());
  }

  static void _paintMuseumFrame(Canvas canvas, Size size, MuseumFrame frame) {
    if (frame == MuseumFrame.none) return;

    final borderWidth = size.shortestSide * 0.04;
    final rect = Rect.fromLTWH(borderWidth / 2, borderWidth / 2, size.width - borderWidth, size.height - borderWidth);

    if (frame == MuseumFrame.gold) {
      // Marco Dorado Real
      final outerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFFF8DC),
            Color(0xFFDAA520),
            Color(0xFFFFD700),
            Color(0xFFB8860B),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(rect, outerPaint);

      final innerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth * 0.15
        ..color = const Color(0xFF5C4033);
      canvas.drawRect(Rect.fromLTWH(borderWidth, borderWidth, size.width - borderWidth * 2, size.height - borderWidth * 2), innerPaint);
    } else if (frame == MuseumFrame.rainbow) {
      // Marco Arcoíris
      final rainbowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..shader = const SweepGradient(
          colors: [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.purple,
            Colors.red,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(rect, rainbowPaint);
    } else if (frame == MuseumFrame.flowers) {
      // Marco Floral Rosa / Menta
      final flowerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFF69B4),
            Color(0xFF2ECC71),
            Color(0xFFFF69B4),
            Color(0xFF9B59B6),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(rect, flowerPaint);
    }
  }

  static void _paintArtistSignature(Canvas canvas, Size size) {
    final fontSize = (size.shortestSide * 0.024).clamp(16.0, 36.0);
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.right, fontSize: fontSize),
    )
      ..pushStyle(
        ui.TextStyle(
          color: const Color(0xFF8E44AD),
          fontWeight: FontWeight.bold,
          shadows: [
            const Shadow(color: Colors.white, blurRadius: 4, offset: Offset(1, 1)),
          ],
        ),
      )
      ..addText('👑 Kiara Zoe Art Studio');

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: size.width - 40));

    canvas.drawParagraph(
      paragraph,
      Offset(20, size.height - paragraph.height - 20),
    );
  }
}
