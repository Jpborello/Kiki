import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/project.dart';

class ProjectRepository {
  Future<Directory> get _projectsDirectory async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(docs.path, 'projects'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<Project>> loadAllProjects() async {
    final rootDir = await _projectsDirectory;
    final entities = await rootDir.list().toList();
    final List<Project> projects = [];

    for (final entity in entities) {
      if (entity is Directory) {
        final manifestFile = File(path.join(entity.path, 'manifest.json'));
        if (await manifestFile.exists()) {
          try {
            final content = await manifestFile.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            projects.add(Project.fromJson(json));
          } catch (e) {
            // Error leyendo manifesto individual
          }
        }
      }
    }

    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<void> saveProject(Project project) async {
    final rootDir = await _projectsDirectory;
    final projDir = Directory(path.join(rootDir.path, project.id));
    if (!await projDir.exists()) {
      await projDir.create(recursive: true);
    }

    final manifestFile = File(path.join(projDir.path, 'manifest.json'));
    await manifestFile.writeAsString(jsonEncode(project.toJson()));
  }

  Future<void> deleteProject(String id) async {
    final rootDir = await _projectsDirectory;
    final projDir = Directory(path.join(rootDir.path, id));
    if (await projDir.exists()) {
      await projDir.delete(recursive: true);
    }
  }

  Future<String> getProjectDirPath(String id) async {
    final rootDir = await _projectsDirectory;
    return path.join(rootDir.path, id);
  }
}
