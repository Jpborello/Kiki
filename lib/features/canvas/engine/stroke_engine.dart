import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import '../../../core/models/brush.dart';
import '../../../core/models/stroke.dart';
import '../../../core/models/symmetry.dart';

class StrokeEngine {
  /// Genera el path para un trazo básico continuo
  static Path generateStrokePath(Stroke stroke, Brush brush) {
    if (stroke.points.isEmpty) return Path();

    if (stroke.points.length == 1) {
      final p = stroke.points.first.position;
      return Path()..addOval(Rect.fromCircle(center: p, radius: brush.size / 2));
    }

    final inputPoints = stroke.points.map((pt) {
      return PointVector(
        pt.position.dx,
        pt.position.dy,
        brush.isPressureSensitive ? pt.pressure : 0.5,
      );
    }).toList();

    final options = StrokeOptions(
      size: brush.size,
      thinning: brush.isPressureSensitive ? 0.6 : 0.0,
      smoothing: 0.5,
      streamline: 0.5,
      simulatePressure: !brush.isPressureSensitive,
    );

    final outlinePoints = getStroke(inputPoints, options: options);

    if (outlinePoints.isEmpty) return Path();

    final path = Path();
    path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
    for (int i = 1; i < outlinePoints.length; i++) {
      path.lineTo(outlinePoints[i].dx, outlinePoints[i].dy);
    }
    path.close();

    return path;
  }

  /// Crea la silueta de una estrella de 5 puntas
  static Path createStarPath(Offset center, double radius) {
    final path = Path();
    final double innerRadius = radius * 0.42;
    for (int i = 0; i < 10; i++) {
      final double r = i.isEven ? radius : innerRadius;
      final double angle = (i * 36 - 90) * math.pi / 180;
      final double x = center.dx + r * math.cos(angle);
      final double y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  /// Crea la silueta de un corazón
  static Path createHeartPath(Offset center, double size) {
    final path = Path();
    final w = size;
    final h = size;
    final x = center.dx - w / 2;
    final y = center.dy - h / 2;
    path.moveTo(x + w / 2, y + h * 0.35);
    path.cubicTo(x + w / 2, y + h * 0.1, x, y, x, y + h * 0.35);
    path.cubicTo(x, y + h * 0.65, x + w * 0.4, y + h * 0.85, x + w / 2, y + h);
    path.cubicTo(x + w * 0.6, y + h * 0.85, x + w, y + h * 0.65, x + w, y + h * 0.35);
    path.cubicTo(x + w, y, x + w / 2, y + h * 0.1, x + w / 2, y + h * 0.35);
    path.close();
    return path;
  }

  /// Crea la silueta de una flor de 5 pétalos
  static Path createFlowerPath(Offset center, double radius) {
    final path = Path();
    final petalRadius = radius * 0.5;
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72) * math.pi / 180;
      final cx = center.dx + (radius * 0.55) * math.cos(angle);
      final cy = center.dy + (radius * 0.55) * math.sin(angle);
      path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: petalRadius));
    }
    path.addOval(Rect.fromCircle(center: center, radius: radius * 0.35));
    return path;
  }

  /// Dibuja un trazo completo (o con simetría) en el canvas
  static void paintStroke(
    Canvas canvas,
    Size canvasSize,
    Stroke stroke,
    Brush brush, {
    ui.FragmentShader? shader,
    double time = 0.0,
    SymmetryMode symmetry = SymmetryMode.none,
  }) {
    if (stroke.points.isEmpty) return;

    final transforms = _getSymmetryTransforms(canvasSize, symmetry);
    for (final transform in transforms) {
      canvas.save();
      canvas.transform(transform.storage);
      _paintSingleStroke(canvas, canvasSize, stroke, brush, shader: shader, time: time);
      canvas.restore();
    }
  }

  static void _paintSingleStroke(
    Canvas canvas,
    Size canvasSize,
    Stroke stroke,
    Brush brush, {
    ui.FragmentShader? shader,
    double time = 0.0,
  }) {
    if (brush.type == BrushType.eraser) {
      final path = generateStrokePath(stroke, brush);
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.clear;
      canvas.drawPath(path, paint);
      return;
    }

    if (brush.id == 'neon') {
      final path = generateStrokePath(stroke, brush);
      // Resplandor exterior
      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = stroke.color.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, brush.size * 0.7);
      canvas.drawPath(path, glowPaint);

      // Núcleo blanco brillante
      final coreBrush = brush.copyWith(size: brush.size * 0.45);
      final corePath = generateStrokePath(stroke, coreBrush);
      final corePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: 0.95);
      canvas.drawPath(corePath, corePaint);
      return;
    }

    if (brush.type == BrushType.stamp) {
      _paintStampStroke(canvas, stroke, brush);
      return;
    }

    if (brush.type == BrushType.shader && shader != null) {
      final path = generateStrokePath(stroke, brush);
      final paint = Paint()..style = PaintingStyle.fill;
      shader
        ..setFloat(0, canvasSize.width)
        ..setFloat(1, canvasSize.height)
        ..setFloat(2, time)
        ..setFloat(3, stroke.color.r)
        ..setFloat(4, stroke.color.g)
        ..setFloat(5, stroke.color.b)
        ..setFloat(6, stroke.color.a * brush.opacity);
      paint.shader = shader;
      canvas.drawPath(path, paint);
      return;
    }

    // Trazo básico normal
    final path = generateStrokePath(stroke, brush);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = stroke.color.withValues(alpha: stroke.color.a * brush.opacity);
    canvas.drawPath(path, paint);
  }

  static void _paintStampStroke(Canvas canvas, Stroke stroke, Brush brush) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = stroke.color.withValues(alpha: stroke.color.a * brush.opacity);

    final spacing = brush.spacing.clamp(8.0, 100.0);
    Offset? lastPos;
    double accumulatedDist = 0.0;

    for (int i = 0; i < stroke.points.length; i++) {
      final pt = stroke.points[i];
      if (lastPos == null) {
        _drawStampShape(canvas, pt.position, brush, pt.pressure, paint, i);
        lastPos = pt.position;
        accumulatedDist = 0.0;
        continue;
      }

      final dist = (pt.position - lastPos).distance;
      accumulatedDist += dist;

      if (accumulatedDist >= spacing || i == stroke.points.length - 1) {
        _drawStampShape(canvas, pt.position, brush, pt.pressure, paint, i);
        lastPos = pt.position;
        accumulatedDist = 0.0;
      }
    }
  }

  static void _drawStampShape(
    Canvas canvas,
    Offset position,
    Brush brush,
    double pressure,
    Paint paint,
    int index,
  ) {
    final stampSize = brush.size * (0.6 + pressure * 0.8);
    canvas.save();
    canvas.translate(position.dx, position.dy);

    // Rotación sutil para dinamismo
    final rot = (index * 0.45) % (2 * math.pi);
    canvas.rotate(rot);

    Path shape;
    if (brush.id == 'stars') {
      shape = createStarPath(Offset.zero, stampSize / 2);
    } else if (brush.id == 'hearts') {
      shape = createHeartPath(Offset.zero, stampSize);
    } else if (brush.id == 'flowers') {
      shape = createFlowerPath(Offset.zero, stampSize / 2);
    } else {
      shape = createStarPath(Offset.zero, stampSize / 2);
    }

    canvas.drawPath(shape, paint);
    canvas.restore();
  }

  static List<Matrix4> _getSymmetryTransforms(Size size, SymmetryMode mode) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (mode) {
      case SymmetryMode.none:
        return [Matrix4.identity()];

      case SymmetryMode.horizontalMirror:
        return [
          Matrix4.identity(),
          Matrix4.identity()
            ..translate(cx, cy)
            ..scale(-1.0, 1.0)
            ..translate(-cx, -cy),
        ];

      case SymmetryMode.fourWay:
        return [
          Matrix4.identity(),
          Matrix4.identity()
            ..translate(cx, cy)
            ..scale(-1.0, 1.0)
            ..translate(-cx, -cy),
          Matrix4.identity()
            ..translate(cx, cy)
            ..scale(1.0, -1.0)
            ..translate(-cx, -cy),
          Matrix4.identity()
            ..translate(cx, cy)
            ..scale(-1.0, -1.0)
            ..translate(-cx, -cy),
        ];

      case SymmetryMode.kaleidoscope8:
        final list = <Matrix4>[];
        for (int i = 0; i < 4; i++) {
          final angle = i * math.pi / 2;
          list.add(
            Matrix4.identity()
              ..translate(cx, cy)
              ..rotateZ(angle)
              ..translate(-cx, -cy),
          );
          list.add(
            Matrix4.identity()
              ..translate(cx, cy)
              ..rotateZ(angle)
              ..scale(-1.0, 1.0)
              ..translate(-cx, -cy),
          );
        }
        return list;
    }
  }
}
