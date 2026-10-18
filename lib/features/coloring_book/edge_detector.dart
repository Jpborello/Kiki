import 'dart:typed_data';

class EdgeDetector {
  /// Filtro Sobel en Dart puro sobre un buffer RGBA para convertir una foto en line-art
  static Uint8List applySobelFilter(Uint8List rgbaBytes, int width, int height) {
    final Uint8List result = Uint8List(width * height * 4);

    // Convertir a escala de grises
    final Uint8List gray = Uint8List(width * height);
    for (int i = 0; i < width * height; i++) {
      final r = rgbaBytes[i * 4];
      final g = rgbaBytes[i * 4 + 1];
      final b = rgbaBytes[i * 4 + 2];
      gray[i] = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
    }

    // Operadores Sobel
    const List<int> gx = [-1, 0, 1, -2, 0, 2, -1, 0, 1];
    const List<int> gy = [-1, -2, -1, 0, 0, 0, 1, 2, 1];

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        int sumX = 0;
        int sumY = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = gray[(y + ky) * width + (x + kx)];
            final kIdx = (ky + 1) * 3 + (kx + 1);
            sumX += pixel * gx[kIdx];
            sumY += pixel * gy[kIdx];
          }
        }

        final magnitude = (sumX.abs() + sumY.abs()).clamp(0, 255);

        // Invertir para que las líneas sean negras sobre fondo blanco
        final int lineValue = 255 - magnitude;
        final int outIdx = (y * width + x) * 4;

        result[outIdx] = lineValue;     // R
        result[outIdx + 1] = lineValue; // G
        result[outIdx + 2] = lineValue; // B
        result[outIdx + 3] = 255;       // A
      }
    }

    return result;
  }
}
