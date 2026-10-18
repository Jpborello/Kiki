import 'dart:typed_data';

import 'package:gal/gal.dart';

/// En Android/iOS la imagen va directo a la galería del dispositivo.
const String exportSuccessMessage =
    '🎉 ✨ ¡Obra de arte guardada en la galería con éxito! 👑🎨';

Future<void> exportPngImage(Uint8List bytes, String fileName) =>
    Gal.putImageBytes(bytes, name: fileName);
