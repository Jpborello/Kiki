import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../canvas/canvas_screen.dart';
import '../coloring_book/coloring_setup_screen.dart';
import 'crop_rotate_screen.dart';

/// Para qué se usa una foto que llegó sin que se haya elegido antes
/// (pegada o arrastrada en web).
enum PhotoUse { color, trace }

/// Recorta la foto y abre la pantalla para convertirla en dibujo para
/// colorear.
Future<void> colorPhoto(BuildContext context, Uint8List bytes) async {
  final canvasSize = CanvasScreen.defaultCanvasSize(context);
  final cropped = await cropAndRotatePhoto(context, bytes);
  if (cropped == null || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) =>
              ColoringSetupScreen(photoBytes: cropped, canvasSize: canvasSize),
    ),
  );
}

/// Recorta la foto y abre un lienzo nuevo con ella de fondo para calcar.
Future<void> tracePhoto(BuildContext context, Uint8List bytes) async {
  final canvasSize = CanvasScreen.defaultCanvasSize(context);
  final cropped = await cropAndRotatePhoto(context, bytes);
  if (cropped == null || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) => CanvasScreen(
            initialCanvasSize: canvasSize,
            initialTracingBytes: cropped,
          ),
    ),
  );
}

/// Pregunta "¿Colorear o calcar?" con dos botones grandes.
Future<PhotoUse?> askPhotoUse(BuildContext context, Uint8List bytes) {
  return showDialog<PhotoUse>(
    context: context,
    builder:
        (ctx) => Dialog(
          backgroundColor: const Color(0xFF2A2A3D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¿Colorear o calcar? 🤔',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _UseButton(
                          emoji: '🖍️',
                          label: 'Colorear',
                          color: const Color(0xFFFFD700),
                          onTap: () => Navigator.pop(ctx, PhotoUse.color),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _UseButton(
                          emoji: '✏️',
                          label: 'Calcar',
                          color: const Color(0xFF2ECC71),
                          onTap: () => Navigator.pop(ctx, PhotoUse.trace),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
  );
}

class _UseButton extends StatelessWidget {
  const _UseButton({
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
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color, width: 2.5),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
