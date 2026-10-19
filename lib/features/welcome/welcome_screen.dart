import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../core/platform/image_drop.dart';
import '../canvas/canvas_screen.dart';
import '../gallery/gallery_screen.dart';
import '../photo/photo_drop_target.dart';
import '../photo/photo_flow.dart';
import '../photo/pick_photo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _colorPhoto(BuildContext context) async {
    final bytes = await pickPhotoBytes(context, title: '¿Qué foto querés colorear? 🖍️');
    if (bytes == null || !context.mounted) return;
    await colorPhoto(context, bytes);
  }

  Future<void> _tracePhoto(BuildContext context) async {
    final bytes = await pickPhotoBytes(context, title: '¿Qué foto querés calcar? ✏️');
    if (bytes == null || !context.mounted) return;
    await tracePhoto(context, bytes);
  }

  /// Foto pegada o arrastrada (web): se pregunta qué hacer con ella.
  Future<void> _onDroppedPhoto(BuildContext context, Uint8List bytes) async {
    final use = await askPhotoUse(context, bytes);
    if (use == null || !context.mounted) return;
    switch (use) {
      case PhotoUse.color:
        await colorPhoto(context, bytes);
      case PhotoUse.trace:
        await tracePhoto(context, bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PhotoDropTarget(
      onImage: (bytes) => _onDroppedPhoto(context, bytes),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8E44AD),
              Color(0xFF2A2A3D),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(color: const Color(0xFFFF69B4), width: 3),
                      ),
                      child: const Icon(
                        Icons.palette_rounded,
                        size: 64,
                        color: Color(0xFFFF69B4),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '¡Hola, Kiara Zoe! 👑🎨',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bienvenida a tu estudio de arte personal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 40),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF69B4),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 8,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CanvasScreen(
                              initialCanvasSize: CanvasScreen.defaultCanvasSize(context),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.brush_rounded, size: 28),
                      label: const Text(
                        'Crear Nueva Obra Mágica',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _BigPhotoButton(
                            emoji: '🖍️',
                            label: 'Colorear\nuna foto',
                            color: const Color(0xFFFFD700),
                            onTap: () => _colorPhoto(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _BigPhotoButton(
                            emoji: '✏️',
                            label: 'Calcar\nuna foto',
                            color: const Color(0xFF2ECC71),
                            onTap: () => _tracePhoto(context),
                          ),
                        ),
                      ],
                    ),
                    if (supportsImageDrop) ...[
                      const SizedBox(height: 10),
                      Text(
                        'También podés pegar una captura (Ctrl+V) o arrastrar una foto acá 📥',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        side: const BorderSide(color: Color(0xFF00E5FF), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GalleryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.collections_outlined, size: 28, color: Color(0xFF00E5FF)),
                      label: const Text(
                        'Mi Galería de Arte',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón grande y cuadrado, fácil de tocar para una nena: emoji enorme
/// y texto corto.
class _BigPhotoButton extends StatelessWidget {
  const _BigPhotoButton({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color, width: 2.5),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
