import 'dart:typed_data';

/// Pedido de relleno con balde. Es un objeto plano (sin tipos de
/// dart:ui) para poder mandarlo a otro isolate con `compute`.
class FloodFillRequest {
  const FloodFillRequest({
    required this.rgba,
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    required this.color,
    this.tolerance = 48,
    this.grow = 1,
    this.barrier,
    this.gapClose = 0,
  });

  /// Lo que se ve en pantalla (todas las capas compuestas, opaco).
  final Uint8List rgba;
  final int width;
  final int height;

  /// Punto tocado, en píxeles del lienzo.
  final int x;
  final int y;

  /// Color del relleno en ARGB de 32 bits (como `Color.toARGB32()`).
  final int color;

  /// Diferencia máxima por canal (0..255) con el color tocado para que
  /// un píxel cuente como "de la misma zona". Con algo de margen se
  /// cubren los bordes suavizados (antialias) de las líneas.
  final int tolerance;

  /// Cuántos píxeles se agranda la zona al final, para que no quede un
  /// halo blanco entre el relleno y la línea.
  final int grow;

  /// Opcional: alfa (un byte por píxel) de las líneas del dibujo para
  /// colorear. Si está, estas líneas cortan el relleno aunque tengan
  /// huecos (ver [gapClose]), y tocar sobre una línea no rellena nada.
  final Uint8List? barrier;

  /// Solo con [barrier]: cierra huecos de hasta ~2×[gapClose] píxeles
  /// entre líneas, para que el balde no se escape por un contorno cortado.
  final int gapClose;
}

/// Resultado: un parche RGBA del tamaño justo de la zona rellenada, que
/// se dibuja en ([left], [top]) del lienzo.
class FloodFillResult {
  const FloodFillResult({
    required this.rgba,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final Uint8List rgba;
  final int left;
  final int top;
  final int width;
  final int height;
}

/// Relleno por líneas de barrido (scanline): en vez de apilar cada
/// píxel, recorre tramos horizontales enteros, así un lienzo de varios
/// millones de píxeles se rellena rápido incluso en web.
///
/// Devuelve `null` si el punto está fuera del lienzo.
FloodFillResult? floodFill(FloodFillRequest request) {
  final w = request.width;
  final h = request.height;
  final px = request.rgba;
  if (request.x < 0 || request.y < 0 || request.x >= w || request.y >= h) {
    return null;
  }

  final seed = (request.y * w + request.x) * 4;
  final sr = px[seed];
  final sg = px[seed + 1];
  final sb = px[seed + 2];
  final sa = px[seed + 3];
  final tol = request.tolerance;

  bool sameColor(int i) {
    final o = i * 4;
    return (px[o] - sr).abs() <= tol &&
        (px[o + 1] - sg).abs() <= tol &&
        (px[o + 2] - sb).abs() <= tol &&
        (px[o + 3] - sa).abs() <= tol;
  }

  final barrier = request.barrier;
  var extraGrow = 0;
  var matches = sameColor;
  if (barrier != null) {
    // Las líneas, engordadas [gapClose] px: los huecos chicos quedan
    // cerrados mientras se busca la zona.
    var blocked = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      if (barrier[i] >= 128) blocked[i] = 1;
    }
    if (request.gapClose > 0) {
      blocked = _dilateMask(blocked, w, h, request.gapClose);
    }
    if (blocked[request.y * w + request.x] == 1) return null;
    // Además del color, así lo que se dibujó a mano también es borde.
    matches = (i) => blocked[i] == 0 && sameColor(i);
    // Después se devuelve lo que se achicó por engordar las líneas
    // (queda debajo de ellas, no se ve).
    extraGrow = request.gapClose;
  }

  final mask = Uint8List(w * h);
  var minX = request.x, maxX = request.x, minY = request.y, maxY = request.y;

  final stack = <int>[request.y * w + request.x];
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    if (mask[i] == 1) continue;
    final y = i ~/ w;
    final rowStart = y * w;

    var left = i - rowStart;
    while (left > 0 && mask[rowStart + left - 1] == 0 && matches(rowStart + left - 1)) {
      left--;
    }
    var right = i - rowStart;
    while (right < w - 1 && mask[rowStart + right + 1] == 0 && matches(rowStart + right + 1)) {
      right++;
    }

    for (var x = left; x <= right; x++) {
      mask[rowStart + x] = 1;
    }
    if (left < minX) minX = left;
    if (right > maxX) maxX = right;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;

    // Encola el comienzo de cada tramo nuevo en las filas de arriba y abajo.
    for (final ny in [y - 1, y + 1]) {
      if (ny < 0 || ny >= h) continue;
      final nRow = ny * w;
      var inRun = false;
      for (var x = left; x <= right; x++) {
        final j = nRow + x;
        final open = mask[j] == 0 && matches(j);
        if (open && !inRun) stack.add(j);
        inRun = open;
      }
    }
  }

  // Agranda la zona [grow] píxeles (4 vecinos por pasada).
  for (var pass = 0; pass < request.grow + extraGrow; pass++) {
    final x0 = (minX - 1).clamp(0, w - 1);
    final x1 = (maxX + 1).clamp(0, w - 1);
    final y0 = (minY - 1).clamp(0, h - 1);
    final y1 = (maxY + 1).clamp(0, h - 1);
    final grown = <int>[];
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * w + x;
        if (mask[i] == 1) continue;
        if ((x > 0 && mask[i - 1] == 1) ||
            (x < w - 1 && mask[i + 1] == 1) ||
            (y > 0 && mask[i - w] == 1) ||
            (y < h - 1 && mask[i + w] == 1)) {
          grown.add(i);
        }
      }
    }
    for (final i in grown) {
      mask[i] = 1;
    }
    minX = x0;
    maxX = x1;
    minY = y0;
    maxY = y1;
  }

  final pw = maxX - minX + 1;
  final ph = maxY - minY + 1;
  final out = Uint8List(pw * ph * 4);
  final a = (request.color >> 24) & 0xFF;
  final r = (request.color >> 16) & 0xFF;
  final g = (request.color >> 8) & 0xFF;
  final b = request.color & 0xFF;
  for (var y = 0; y < ph; y++) {
    final srcRow = (minY + y) * w + minX;
    final dstRow = y * pw;
    for (var x = 0; x < pw; x++) {
      if (mask[srcRow + x] == 0) continue;
      final o = (dstRow + x) * 4;
      out[o] = r;
      out[o + 1] = g;
      out[o + 2] = b;
      out[o + 3] = a;
    }
  }

  return FloodFillResult(rgba: out, left: minX, top: minY, width: pw, height: ph);
}

/// Engorda una máscara 0/1: cada píxel toma el máximo de un cuadrado de
/// radio [r] (separable: primero filas, después columnas).
Uint8List _dilateMask(Uint8List src, int w, int h, int r) {
  final tmp = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    // Distancia al último píxel marcado, de izquierda a derecha y al revés.
    var last = -r - 1;
    for (var x = 0; x < w; x++) {
      if (src[row + x] == 1) last = x;
      if (x - last <= r) tmp[row + x] = 1;
    }
    last = w + r + 1;
    for (var x = w - 1; x >= 0; x--) {
      if (src[row + x] == 1) last = x;
      if (last - x <= r) tmp[row + x] = 1;
    }
  }
  final out = Uint8List(w * h);
  for (var x = 0; x < w; x++) {
    var last = -r - 1;
    for (var y = 0; y < h; y++) {
      if (tmp[y * w + x] == 1) last = y;
      if (y - last <= r) out[y * w + x] = 1;
    }
    last = h + r + 1;
    for (var y = h - 1; y >= 0; y--) {
      if (tmp[y * w + x] == 1) last = y;
      if (last - y <= r) out[y * w + x] = 1;
    }
  }
  return out;
}
