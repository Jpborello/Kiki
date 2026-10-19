import 'dart:math' as math;
import 'dart:typed_data';

/// Pedido para convertir una foto en un dibujo para colorear. Objeto
/// plano para poder mandarlo a otro isolate con `compute`.
class LineArtRequest {
  const LineArtRequest({
    required this.rgba,
    required this.width,
    required this.height,
    this.detail = 0.5,
    this.thick = true,
  });

  /// Foto opaca en RGBA.
  final Uint8List rgba;
  final int width;
  final int height;

  /// 0 = solo los contornos más marcados, 1 = muchos detalles.
  final double detail;

  /// Engrosa las líneas: más fáciles de respetar para una nena pintando
  /// con el dedo, y el balde no se "escapa" por huecos chiquitos.
  final bool thick;
}

/// Convierte una foto en líneas negras sobre fondo transparente (RGBA),
/// listas para ir en una capa arriba del dibujo.
///
/// Usa diferencia de gaussianas (DoG): un píxel es línea si es más oscuro
/// que su entorno. Con fotos reales da contornos más limpios que un Sobel,
/// que marca cada textura y deja mucho ruido.
Uint8List generateLineArt(LineArtRequest request) {
  final w = request.width;
  final h = request.height;
  final n = w * h;
  final src = request.rgba;

  final gray = Float32List(n);
  for (var i = 0; i < n; i++) {
    final o = i * 4;
    gray[i] = 0.299 * src[o] + 0.587 * src[o + 1] + 0.114 * src[o + 2];
  }

  // El radio escala con la resolución, así el resultado se parece
  // sin importar el tamaño del lienzo.
  final base = math.max(1, (math.min(w, h) / 600).round());
  final fine = _blur(gray, w, h, base);
  final coarse = _blur(gray, w, h, base * 3);

  // Umbral en niveles de gris: alto = solo bordes fuertes.
  final detail = request.detail.clamp(0.0, 1.0);
  final strong = 20.0 - 15.0 * detail;
  final weak = strong * 0.35;

  final diff = Float32List(n);
  for (var i = 0; i < n; i++) {
    diff[i] = coarse[i] - fine[i];
  }

  // Histéresis (como en Canny): un píxel débil es línea solo si está
  // conectado a uno fuerte. Así un contorno sigue de corrido por las
  // partes donde se desvanece, en vez de cortarse y dejar huecos por
  // donde el balde se escapa; y el ruido débil suelto no aparece.
  var alpha = Uint8List(n);
  final stack = <int>[];
  for (var i = 0; i < n; i++) {
    if (diff[i] > strong && alpha[i] == 0) {
      alpha[i] = 255;
      stack.add(i);
      while (stack.isNotEmpty) {
        final j = stack.removeLast();
        final x = j % w;
        final y = j ~/ w;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= h) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= w) continue;
            final k = ny * w + nx;
            if (alpha[k] == 0 && diff[k] > weak) {
              alpha[k] = 255;
              stack.add(k);
            }
          }
        }
      }
    }
  }

  alpha = _removeSpecks(alpha, w, h, minSize: 6 + (24 * (1 - detail)).round());
  if (request.thick) {
    alpha = _dilate(alpha, w, h, base);
  }

  final out = Uint8List(n * 4);
  for (var i = 0; i < n; i++) {
    // RGB en 0 (negro): da igual si el destino espera alfa premultiplicado.
    out[i * 4 + 3] = alpha[i];
  }
  return out;
}

/// Desenfoque aproximadamente gaussiano: dos pasadas de caja en cada
/// eje, con sumas acumuladas (costo independiente del radio).
Float32List _blur(Float32List src, int w, int h, int radius) {
  var a = src;
  for (var pass = 0; pass < 2; pass++) {
    a = _boxBlurH(a, w, h, radius);
    a = _boxBlurV(a, w, h, radius);
  }
  return a;
}

Float32List _boxBlurH(Float32List src, int w, int h, int r) {
  final out = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var sum = 0.0;
    for (var x = -r; x <= r; x++) {
      sum += src[row + x.clamp(0, w - 1)];
    }
    for (var x = 0; x < w; x++) {
      out[row + x] = sum / (2 * r + 1);
      sum += src[row + (x + r + 1).clamp(0, w - 1)] - src[row + (x - r).clamp(0, w - 1)];
    }
  }
  return out;
}

Float32List _boxBlurV(Float32List src, int w, int h, int r) {
  final out = Float32List(w * h);
  for (var x = 0; x < w; x++) {
    var sum = 0.0;
    for (var y = -r; y <= r; y++) {
      sum += src[y.clamp(0, h - 1) * w + x];
    }
    for (var y = 0; y < h; y++) {
      out[y * w + x] = sum / (2 * r + 1);
      sum += src[(y + r + 1).clamp(0, h - 1) * w + x] - src[(y - r).clamp(0, h - 1) * w + x];
    }
  }
  return out;
}

/// Engrosa: cada píxel toma el máximo de su vecindario de radio [r].
Uint8List _dilate(Uint8List src, int w, int h, int r) {
  final tmp = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      var m = 0;
      for (var k = math.max(0, x - r); k <= math.min(w - 1, x + r); k++) {
        if (src[row + k] > m) m = src[row + k];
      }
      tmp[row + x] = m;
    }
  }
  final out = Uint8List(w * h);
  for (var x = 0; x < w; x++) {
    for (var y = 0; y < h; y++) {
      var m = 0;
      for (var k = math.max(0, y - r); k <= math.min(h - 1, y + r); k++) {
        if (tmp[k * w + x] > m) m = tmp[k * w + x];
      }
      out[y * w + x] = m;
    }
  }
  return out;
}

/// Borra manchitas sueltas (grupos de menos de [minSize] píxeles), que
/// en una foto suelen ser ruido o textura y ensucian el dibujo.
Uint8List _removeSpecks(Uint8List alpha, int w, int h, {required int minSize}) {
  final seen = Uint8List(w * h);
  final group = <int>[];
  final stack = <int>[];
  for (var start = 0; start < w * h; start++) {
    if (alpha[start] == 0 || seen[start] == 1) continue;
    group.clear();
    stack.add(start);
    seen[start] = 1;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      group.add(i);
      final x = i % w;
      if (x > 0) _visit(i - 1, alpha, seen, stack);
      if (x < w - 1) _visit(i + 1, alpha, seen, stack);
      if (i >= w) _visit(i - w, alpha, seen, stack);
      if (i < w * (h - 1)) _visit(i + w, alpha, seen, stack);
    }
    if (group.length < minSize) {
      for (final i in group) {
        alpha[i] = 0;
      }
    }
  }
  return alpha;
}

void _visit(int i, Uint8List alpha, Uint8List seen, List<int> stack) {
  if (alpha[i] == 0 || seen[i] == 1) return;
  seen[i] = 1;
  stack.add(i);
}
