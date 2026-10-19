import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// En web se puede pegar una captura (Ctrl+V) o arrastrar un archivo de
/// imagen sobre la página.
const bool supportsImageDrop = true;

/// Escucha imágenes pegadas o soltadas sobre la página. [onHover] avisa
/// cuando se está arrastrando un archivo por encima. Devuelve una función
/// para dejar de escuchar.
void Function() listenForImageDrops({
  required void Function(Uint8List bytes) onImage,
  required void Function(bool hovering) onHover,
}) {
  // dragenter/dragleave saltan por cada elemento hijo: se cuentan para
  // saber cuándo el archivo salió de verdad de la página.
  var dragDepth = 0;

  bool carriesFiles(web.DragEvent e) =>
      e.dataTransfer?.types.toDart.any((t) => t.toDart == 'Files') ?? false;

  final onPaste =
      ((web.ClipboardEvent e) {
        final file = _firstImage(e.clipboardData?.files);
        if (file == null) return;
        e.preventDefault();
        _read(file, onImage);
      }).toJS;

  final onDragEnter =
      ((web.DragEvent e) {
        if (!carriesFiles(e)) return;
        e.preventDefault();
        if (dragDepth++ == 0) onHover(true);
      }).toJS;

  final onDragOver =
      ((web.DragEvent e) {
        if (!carriesFiles(e)) return;
        // Sin esto el navegador no deja soltar y abre el archivo en la pestaña.
        e.preventDefault();
        e.dataTransfer?.dropEffect = 'copy';
      }).toJS;

  final onDragLeave =
      ((web.DragEvent e) {
        if (!carriesFiles(e) || dragDepth == 0) return;
        if (--dragDepth == 0) onHover(false);
      }).toJS;

  final onDrop =
      ((web.DragEvent e) {
        if (!carriesFiles(e)) return;
        e.preventDefault();
        dragDepth = 0;
        onHover(false);
        final file = _firstImage(e.dataTransfer?.files);
        if (file != null) _read(file, onImage);
      }).toJS;

  final window = web.window;
  window.addEventListener('paste', onPaste);
  window.addEventListener('dragenter', onDragEnter);
  window.addEventListener('dragover', onDragOver);
  window.addEventListener('dragleave', onDragLeave);
  window.addEventListener('drop', onDrop);
  return () {
    window.removeEventListener('paste', onPaste);
    window.removeEventListener('dragenter', onDragEnter);
    window.removeEventListener('dragover', onDragOver);
    window.removeEventListener('dragleave', onDragLeave);
    window.removeEventListener('drop', onDrop);
  };
}

web.File? _firstImage(web.FileList? files) {
  if (files == null) return null;
  for (var i = 0; i < files.length; i++) {
    final file = files.item(i);
    if (file != null && file.type.startsWith('image/')) return file;
  }
  return null;
}

Future<void> _read(
  web.File file,
  void Function(Uint8List bytes) onImage,
) async {
  final buffer = await file.arrayBuffer().toDart;
  onImage(buffer.toDart.asUint8List());
}
