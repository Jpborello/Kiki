import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/models/brush.dart';
import '../../../core/models/stroke.dart';
import '../../../core/models/symmetry.dart';
import '../engine/stroke_engine.dart';

class ActiveStrokePainter extends CustomPainter {
  final Stroke stroke;
  final Brush brush;
  final ui.FragmentShader? shader;
  final double time;
  final SymmetryMode symmetryMode;

  ActiveStrokePainter({
    required this.stroke,
    required this.brush,
    this.shader,
    this.time = 0.0,
    this.symmetryMode = SymmetryMode.none,
  });

  @override
  void paint(Canvas canvas, Size size) {
    StrokeEngine.paintStroke(
      canvas,
      size,
      stroke,
      brush,
      shader: shader,
      time: time,
      symmetry: symmetryMode,
    );
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) {
    return oldDelegate.stroke != stroke ||
        oldDelegate.brush != brush ||
        oldDelegate.time != time ||
        oldDelegate.symmetryMode != symmetryMode;
  }
}
