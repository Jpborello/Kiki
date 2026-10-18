import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models/project.dart';
import '../../core/storage/project_repository.dart';
import '../canvas/canvas_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final ProjectRepository _repository = ProjectRepository();
  List<Project> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final list = await _repository.loadAllProjects();
    setState(() {
      _projects = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👑 Galería de Obras Mágicas'),
        backgroundColor: const Color(0xFF2A2A3D),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF69B4)))
          : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.palette_outlined, size: 80, color: Colors.white38),
                      const SizedBox(height: 16),
                      const Text(
                        'Todavía no tenés obras guardadas',
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF69B4),
                        ),
                        onPressed: () {
                          final media = MediaQuery.of(context);
                          final width = media.size.width;
                          final height = media.size.height;
                          final double targetWidth = 1440;
                          final double targetHeight = (1440 * (height / width)).roundToDouble();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CanvasScreen(
                                initialCanvasSize: Size(targetWidth, targetHeight),
                              ),
                            ),
                          ).then((_) => _loadProjects());
                        },
                        child: const Text('¡Crear la primera! ✨'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      color: const Color(0xFF2A2A3D),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CanvasScreen(project: project),
                            ),
                          ).then((_) => _loadProjects());
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Container(
                                color: Colors.white,
                                child: _buildThumbnail(project),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    project.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${project.updatedAt.day}/${project.updatedAt.month}/${project.updatedAt.year}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF69B4),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          'Nueva Obra',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          final media = MediaQuery.of(context);
          final width = media.size.width;
          final height = media.size.height;
          final double targetWidth = 1440;
          final double targetHeight = (1440 * (height / width)).roundToDouble();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CanvasScreen(
                initialCanvasSize: Size(targetWidth, targetHeight),
              ),
            ),
          ).then((_) => _loadProjects());
        },
      ),
    );
  }

  Widget _buildThumbnail(Project project) {
    final thumbPath = project.thumbnailPath;
    if (thumbPath == null) {
      return const Center(
        child: Icon(Icons.brush, size: 48, color: Color(0xFFFF69B4)),
      );
    }
    return Image.file(
      File(thumbPath),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.brush, size: 48, color: Color(0xFFFF69B4)),
      ),
    );
  }
}
