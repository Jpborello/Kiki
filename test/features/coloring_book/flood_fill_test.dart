import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikidraw/features/coloring_book/flood_fill.dart';

/// Lienzo blanco de [w]x[h] con un cuadrado negro hueco (borde de 1 px)
/// entre (2,2) y (7,7).
Uint8List _canvasWithSquare(int w, int h) {
  final px = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255);
  for (var y = 2; y <= 7; y++) {
    for (var x = 2; x <= 7; x++) {
      if (x == 2 || x == 7 || y == 2 || y == 7) {
        final o = (y * w + x) * 4;
        px[o] = px[o + 1] = px[o + 2] = 0;
      }
    }
  }
  return px;
}

bool _painted(FloodFillResult r, int x, int y) {
  final lx = x - r.left;
  final ly = y - r.top;
  if (lx < 0 || ly < 0 || lx >= r.width || ly >= r.height) return false;
  return r.rgba[(ly * r.width + lx) * 4 + 3] != 0;
}

void main() {
  const w = 12;
  const h = 12;
  const red = 0xFFFF0000;

  group('floodFill', () {
    test('rellena solo el interior del cuadrado', () {
      final result = floodFill(FloodFillRequest(
        rgba: _canvasWithSquare(w, h),
        width: w,
        height: h,
        x: 4,
        y: 4,
        color: red,
        grow: 0,
      ))!;

      expect(result.left, 3);
      expect(result.top, 3);
      expect(result.width, 4);
      expect(result.height, 4);
      expect(_painted(result, 3, 3), isTrue);
      expect(_painted(result, 6, 6), isTrue);
      expect(_painted(result, 2, 4), isFalse, reason: 'el borde no se pinta');
      expect(_painted(result, 0, 0), isFalse, reason: 'el exterior no se pinta');
    });

    test('pinta con el color pedido', () {
      final result = floodFill(FloodFillRequest(
        rgba: _canvasWithSquare(w, h),
        width: w,
        height: h,
        x: 4,
        y: 4,
        color: 0xFF112233,
        grow: 0,
      ))!;
      final o = ((4 - result.top) * result.width + (4 - result.left)) * 4;
      expect(result.rgba.sublist(o, o + 4), [0x11, 0x22, 0x33, 0xFF]);
    });

    test('el exterior rodea al cuadrado sin entrar', () {
      final result = floodFill(FloodFillRequest(
        rgba: _canvasWithSquare(w, h),
        width: w,
        height: h,
        x: 0,
        y: 0,
        color: red,
        grow: 0,
      ))!;

      expect(result.width, w);
      expect(result.height, h);
      expect(_painted(result, 11, 11), isTrue);
      expect(_painted(result, 5, 5), isFalse);
    });

    test('grow agranda la zona por debajo de la línea', () {
      final result = floodFill(FloodFillRequest(
        rgba: _canvasWithSquare(w, h),
        width: w,
        height: h,
        x: 4,
        y: 4,
        color: red,
        grow: 1,
      ))!;

      expect(_painted(result, 2, 4), isTrue, reason: 'cubre el borde');
      expect(_painted(result, 1, 4), isFalse, reason: 'pero no lo cruza');
    });

    test('la tolerancia cubre bordes suavizados', () {
      final px = _canvasWithSquare(w, h);
      // Un píxel gris claro (antialias) dentro del cuadrado.
      final o = (5 * w + 5) * 4;
      px[o] = px[o + 1] = px[o + 2] = 230;

      final result = floodFill(FloodFillRequest(
        rgba: px,
        width: w,
        height: h,
        x: 4,
        y: 4,
        color: red,
        grow: 0,
      ))!;
      expect(_painted(result, 5, 5), isTrue);
    });

    group('con capa de líneas (barrier)', () {
      const bw = 30;
      const bh = 30;

      /// Lienzo blanco + líneas: una pared vertical en x=14..15 con un
      /// hueco de 2 px en y=14..15.
      ({Uint8List rgba, Uint8List barrier}) wallWithGap() {
        final rgba = Uint8List(bw * bh * 4)..fillRange(0, bw * bh * 4, 255);
        final barrier = Uint8List(bw * bh);
        for (var y = 0; y < bh; y++) {
          if (y == 14 || y == 15) continue;
          barrier[y * bw + 14] = 255;
          barrier[y * bw + 15] = 255;
        }
        return (rgba: rgba, barrier: barrier);
      }

      test('sin cerrar huecos, el relleno se escapa', () {
        final c = wallWithGap();
        final result = floodFill(FloodFillRequest(
          rgba: c.rgba, width: bw, height: bh, x: 2, y: 2, color: red,
          grow: 0, barrier: c.barrier,
        ))!;
        expect(_painted(result, 27, 2), isTrue);
      });

      test('cerrando huecos, la pared contiene el relleno', () {
        final c = wallWithGap();
        final result = floodFill(FloodFillRequest(
          rgba: c.rgba, width: bw, height: bh, x: 2, y: 2, color: red,
          grow: 0, barrier: c.barrier, gapClose: 2,
        ))!;
        expect(_painted(result, 5, 20), isTrue);
        expect(_painted(result, 27, 2), isFalse);
      });

      test('tocar sobre una línea no rellena nada', () {
        final c = wallWithGap();
        expect(
          floodFill(FloodFillRequest(
            rgba: c.rgba, width: bw, height: bh, x: 14, y: 2, color: red,
            barrier: c.barrier,
          )),
          isNull,
        );
      });
    });

    test('fuera del lienzo devuelve null', () {
      expect(
        floodFill(FloodFillRequest(
          rgba: _canvasWithSquare(w, h),
          width: w,
          height: h,
          x: w,
          y: 0,
          color: red,
        )),
        isNull,
      );
    });
  });
}
