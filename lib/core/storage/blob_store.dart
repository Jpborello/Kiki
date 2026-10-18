import 'dart:typed_data';

import 'blob_store_io.dart'
    if (dart.library.js_interop) 'blob_store_web.dart' as impl;

/// Almacén de archivos de los proyectos (manifest, PNG de capas,
/// miniatura, imagen de calcado), agrupados por id de proyecto.
///
/// En Android/desktop son archivos en la carpeta de documentos de la
/// app; en web van a IndexedDB. El import condicional de arriba elige
/// la implementación, así `dart:io` nunca entra en el build web.
abstract class BlobStore {
  static final BlobStore instance = impl.createBlobStore();

  Future<List<String>> listProjectIds();

  /// Devuelve `null` si el archivo no existe.
  Future<Uint8List?> read(String projectId, String name);

  Future<void> write(String projectId, String name, Uint8List bytes);

  Future<void> deleteProject(String projectId);
}
