import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// En web no hay galería: el navegador descarga el PNG.
const String exportSuccessMessage =
    '🎉 ✨ ¡Obra de arte descargada con éxito! 👑🎨';

Future<void> exportPngImage(Uint8List bytes, String fileName) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Safari necesita que la URL siga viva un rato después del click.
  Future.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}
