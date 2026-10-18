import 'package:flutter/material.dart';
import '../canvas/canvas_screen.dart';
import '../gallery/gallery_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bienvenida a tu estudio de arte personal',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 48),

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
                      );
                    },
                    icon: const Icon(Icons.add_a_photo_outlined, size: 28),
                    label: const Text(
                      'Crear Nueva Obra Mágica',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
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
    );
  }
}
