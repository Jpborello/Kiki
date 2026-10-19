import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikidraw/features/canvas/brushes/brush_library.dart';
import 'package:kikidraw/features/canvas/controllers/canvas_controller.dart';

const _size = Size(40, 40);

/// Dibujo para colorear: un cuadrado negro hueco (borde de 2 px) entre
/// (10,10) y (29,29), sobre fondo transparente.
Future<ui.Image> _squareLineArt() {
  final w = _size.width.toInt();
  final h = _size.height.toInt();
  final px = Uint8List(w * h * 4);
  for (var y = 10; y < 30; y++) {
    for (var x = 10; x < 30; x++) {
      final border = x < 12 || x > 27 || y < 12 || y > 27;
      if (border) px[(y * w + x) * 4 + 3] = 255;
    }
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}

Future<Color> _pixel(ui.Image image, int x, int y) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final o = (y * image.width + x) * 4;
  return Color.fromARGB(
    data.getUint8(o + 3),
    data.getUint8(o),
    data.getUint8(o + 1),
    data.getUint8(o + 2),
  );
}

void main() {
  testWidgets('colorear: líneas bloqueadas arriba y balde con deshacer', (tester) async {
    await tester.runAsync(() async {
      final controller = await CanvasController.create(
        null,
        initialCanvasSize: _size,
        lineArt: await _squareLineArt(),
      );
      final state = controller.currentState;

      final lines = state.project.layers.singleWhere((l) => l.locked);
      final color = state.project.layers.singleWhere((l) => !l.locked);
      expect(lines.order, greaterThan(color.order), reason: 'líneas arriba');
      expect(state.activeLayerId, color.id, reason: 'nunca se pinta sobre las líneas');
      expect(state.activeBrush.id, BrushLibrary.bucket.id);

      controller.selectColor(const Color(0xFFFF0000));
      await controller.fillAt(const Offset(20, 20));

      final colorLayer = controller.currentState.layerImages[color.id]!;
      expect(await _pixel(colorLayer, 20, 20), const Color(0xFFFF0000));
      expect((await _pixel(colorLayer, 2, 2)).a, 0, reason: 'afuera no se pinta');
      expect(controller.currentState.canUndo, isTrue);

      await controller.undo();
      final undone = controller.currentState.layerImages[color.id]!;
      expect((await _pixel(undone, 20, 20)).a, 0);

      controller.dispose();
    });
  });
}
