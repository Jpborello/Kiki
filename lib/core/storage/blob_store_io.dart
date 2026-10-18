import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'blob_store.dart';

BlobStore createBlobStore() => IoBlobStore();

/// Un directorio por proyecto dentro de `<documentos>/projects`, igual
/// que antes de la abstracción, así los proyectos ya guardados siguen
/// abriéndose.
class IoBlobStore implements BlobStore {
  Future<Directory> get _projectsDirectory async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, 'projects'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _projectDir(String projectId) async {
    final rootDir = await _projectsDirectory;
    return Directory(path.join(rootDir.path, projectId));
  }

  @override
  Future<List<String>> listProjectIds() async {
    final rootDir = await _projectsDirectory;
    final entities = await rootDir.list().toList();
    return [
      for (final entity in entities)
        if (entity is Directory) path.basename(entity.path),
    ];
  }

  @override
  Future<Uint8List?> read(String projectId, String name) async {
    final dir = await _projectDir(projectId);
    final file = File(path.join(dir.path, name));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(String projectId, String name, Uint8List bytes) async {
    final dir = await _projectDir(projectId);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await File(path.join(dir.path, name)).writeAsBytes(bytes);
  }

  @override
  Future<void> deleteProject(String projectId) async {
    final dir = await _projectDir(projectId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
