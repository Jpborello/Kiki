import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/models/brush.dart';
import '../../../core/models/stroke.dart';
import 'stroke_engine.dart';

class LayerCompositor {
  static Future<ui.Image> createBlankImage(Size size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawColor(Colors.transparent, BlendMode.clear);
    final picture = recorder.endRecording();
    return picture.toImage(size.width.toInt(), size.height.toInt());
  }

  static Future<ui.Image> bakeStrokeIntoImage({
    required ui.Image existingImage,
    required Stroke stroke,
    required Brush brush,
    required Size canvasSize,
    ui.FragmentShader? shader,
    double time = 0.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height));

    canvas.drawImage(existingImage, Offset.zero, Paint());

    final path = StrokeEngine.generateStrokePath(stroke, brush);
    final paint = Paint()..style = PaintingStyle.fill;

    if (brush.type == BrushType.eraser) {
      paint.blendMode = BlendMode.clear;
    } else if (brush.type == BrushType.shader && shader != null) {
      shader
        ..setFloat(0, canvasSize.width)
        ..setFloat(1, canvasSize.height)
        ..setFloat(2, time)
        ..setFloat(3, stroke.color.r)
        ..setFloat(4, stroke.color.g)
        ..setFloat(5, stroke.color.b)
        ..setFloat(6, stroke.color.a * brush.opacity);
      paint.shader = shader;
    } else {
      paint.color = stroke.color.withValues(alpha: stroke.color.a * brush.opacity);
    }

    canvas.drawPath(path, paint);

    final picture = recorder.endRecording();
    return picture.toImage(canvasSize.width.toInt(), canvasSize.height.toInt());
  }
}
