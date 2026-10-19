import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikidraw/features/coloring_book/line_art.dart';

/// Foto sintética: fondo gris claro con un rectángulo oscuro en el medio.
Uint8List _photoWithRect(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final inside = x >= 40 && x < 120 && y >= 40 && y < 120;
      final v = inside ? 40 : 220;
      final o = (y * w + x) * 4;
      px[o] = px[o + 1] = px[o + 2] = v;
      px[o + 3] = 255;
    }
  }
  return px;
}

int _alpha(Uint8List rgba, int w, int x, int y) => rgba[(y * w + x) * 4 + 3];

void main() {
  const w = 160;
  const h = 160;

  group('generateLineArt', () {
    test('marca el contorno del rectángulo', () {
      final out = generateLineArt(LineArtRequest(
        rgba: _photoWithRect(w, h),
        width: w,
        height: h,
      ));
      // Justo adentro del borde izquierdo (lado oscuro) hay línea.
      final edge = [for (var x = 38; x <= 44; x++) _alpha(out, w, x, 80)];
      expect(edge.any((a) => a > 128), isTrue);
    });

    test('las zonas lisas quedan transparentes', () {
      final out = generateLineArt(LineArtRequest(
        rgba: _photoWithRect(w, h),
        width: w,
        height: h,
      ));
      expect(_alpha(out, w, 10, 10), 0, reason: 'fondo');
      expect(_alpha(out, w, 80, 80), 0, reason: 'centro del rectángulo');
    });

    test('las líneas son negras', () {
      final out = generateLineArt(LineArtRequest(
        rgba: _photoWithRect(w, h),
        width: w,
        height: h,
      ));
      for (var i = 0; i < w * h; i++) {
        expect(out[i * 4] | out[i * 4 + 1] | out[i * 4 + 2], 0);
      }
    });

    test('con poco detalle hay menos líneas que con mucho', () {
      // Ruido suave: con detalle alto aparece algo, con bajo no.
      final px = _photoWithRect(w, h);
      for (var i = 0; i < w * h; i++) {
        final n = ((i * 2654435761) >> 28) & 0xF; // pseudoaleatorio 0..15
        for (var c = 0; c < 3; c++) {
          px[i * 4 + c] = (px[i * 4 + c] - n).clamp(0, 255);
        }
      }
      int count(double detail) {
        final out = generateLineArt(LineArtRequest(
          rgba: px,
          width: w,
          height: h,
          detail: detail,
          thick: false,
        ));
        var c = 0;
        for (var i = 0; i < w * h; i++) {
          if (out[i * 4 + 3] > 0) c++;
        }
        return c;
      }

      expect(count(0.0), lessThan(count(1.0)));
    });
  });
}
