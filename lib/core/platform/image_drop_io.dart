import 'dart:typed_data';

/// En Android/iOS no hay portapapeles de imágenes ni arrastrar archivos:
/// las fotos entran solo por la cámara o la galería.
const bool supportsImageDrop = false;

void Function() listenForImageDrops({
  required void Function(Uint8List bytes) onImage,
  required void Function(bool hovering) onHover,
}) => () {};
