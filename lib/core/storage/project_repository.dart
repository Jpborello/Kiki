import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/project.dart';
import 'blob_store.dart';

class ProjectRepository {
  ProjectRepository({BlobStore? store}) : _store = store ?? BlobStore.instance;

  final BlobStore _store;

  static const String manifestFileName = 'manifest.json';
  static const String thumbnailFileName = 'thumb.png';

  Future<List<Project>> loadAllProjects() async {
    final ids = await _store.listProjectIds();
    final List<Project> projects = [];

    for (final id in ids) {
      final bytes = await _store.read(id, manifestFileName);
      if (bytes == null) continue;
      try {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        projects.add(Project.fromJson(json));
      } catch (e) {
        debugPrint('Manifest ilegible en el proyecto $id: $e');
      }
    }

    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<void> saveProject(Project project) async {
    final bytes = utf8.encode(jsonEncode(project.toJson()));
    await _store.write(project.id, manifestFileName, bytes);
  }

  Future<void> deleteProject(String id) => _store.deleteProject(id);

  /// Lee un archivo del proyecto (PNG de capa, miniatura, calco).
  /// Devuelve `null` si no existe.
  Future<Uint8List?> readFile(String projectId, String name) =>
      _store.read(projectId, name);

  Future<void> writeFile(String projectId, String name, Uint8List bytes) =>
      _store.write(projectId, name, bytes);
}
