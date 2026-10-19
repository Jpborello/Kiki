import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/platform/image_drop.dart';

/// Solo en web: recibe imágenes pegadas con Ctrl+V o arrastradas sobre la
/// pantalla, mientras esta pantalla esté arriba de todo. En Android no
/// hace nada.
class PhotoDropTarget extends StatefulWidget {
  const PhotoDropTarget({
    super.key,
    required this.onImage,
    required this.child,
  });

  final void Function(Uint8List bytes) onImage;
  final Widget child;

  @override
  State<PhotoDropTarget> createState() => _PhotoDropTargetState();
}

class _PhotoDropTargetState extends State<PhotoDropTarget> {
  void Function()? _stopListening;
  bool _hovering = false;

  bool get _isOnTop => ModalRoute.of(context)?.isCurrent ?? true;

  @override
  void initState() {
    super.initState();
    if (!supportsImageDrop) return;
    _stopListening = listenForImageDrops(
      onImage: (bytes) {
        if (mounted && _isOnTop) widget.onImage(bytes);
      },
      onHover: (hovering) {
        if (mounted && hovering != _hovering) {
          setState(() => _hovering = hovering);
        }
      },
    );
  }

  @override
  void dispose() {
    _stopListening?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!supportsImageDrop) return widget.child;
    return Stack(
      children: [
        widget.child,
        if (_hovering && _isOnTop)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E44AD).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFFF69B4), width: 4),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '📥\nSoltá la foto acá',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
