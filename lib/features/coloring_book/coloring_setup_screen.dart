import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../canvas/canvas_screen.dart';
import 'line_art.dart';

/// Convierte una foto en un dibujo para colorear: muestra cómo queda,
/// deja elegir cuánto detalle y qué tan gruesas son las líneas, y abre el
/// lienzo con las líneas en una capa fija arriba.
class ColoringSetupScreen extends StatefulWidget {
  const ColoringSetupScreen({
    super.key,
    required this.photoBytes,
    required this.canvasSize,
  });

  final Uint8List photoBytes;
  final Size canvasSize;

  @override
  State<ColoringSetupScreen> createState() => _ColoringSetupScreenState();
}

class _ColoringSetupScreenState extends State<ColoringSetupScreen> {
  /// La vista previa se calcula a la mitad de resolución para que mover
  /// el control de detalle responda rápido (sobre todo en web, donde no
  /// hay isolates). El dibujo final se hace en tamaño completo.
  static const double _previewScale = 0.5;

  ui.Image? _photo;
  Uint8List? _previewRgba;
  ui.Image? _preview;
  double _detail = 0.5;
  bool _thick = true;
  bool _working = true;
  int _previewGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _photo?.dispose();
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.photoBytes);
      _photo = (await codec.getNextFrame()).image;
      final previewSize = widget.canvasSize * _previewScale;
      _previewRgba = await _photoOnCanvasRgba(previewSize);
      await _regeneratePreview();
    } catch (e) {
      debugPrint('No se pudo abrir la foto: $e');
      if (mounted) setState(() => _error = 'No pudimos abrir esa foto 😕');
    }
  }

  /// La foto centrada y entera (sin recortar) sobre un lienzo blanco del
  /// tamaño pedido, en RGBA. El blanco liso no genera líneas.
  Future<Uint8List> _photoOnCanvasRgba(Size size) async {
    final photo = _photo!;
    final w = size.width.round();
    final h = size.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.drawColor(Colors.white, BlendMode.src);
    final src = Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble());
    final fitted = applyBoxFit(BoxFit.contain, src.size, Size(w.toDouble(), h.toDouble()));
    final dst = Alignment.center.inscribe(
      fitted.destination,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );
    canvas.drawImageRect(photo, src, dst, Paint()..filterQuality = FilterQuality.medium);
    final image = await recorder.endRecording().toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<ui.Image> _lineArtImage(Uint8List photoRgba, int w, int h) async {
    final lines = await compute(
      generateLineArt,
      LineArtRequest(rgba: photoRgba, width: w, height: h, detail: _detail, thick: _thick),
    );
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(lines, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  Future<void> _regeneratePreview() async {
    final rgba = _previewRgba;
    if (rgba == null) return;
    final generation = ++_previewGeneration;
    setState(() => _working = true);
    final size = widget.canvasSize * _previewScale;
    final image = await _lineArtImage(rgba, size.width.round(), size.height.round());
    // Si mientras tanto se pidió otra vista previa, esta ya está vieja.
    if (!mounted || generation != _previewGeneration) {
      image.dispose();
      return;
    }
    setState(() {
      _preview?.dispose();
      _preview = image;
      _working = false;
    });
  }

  Future<void> _startColoring() async {
    setState(() => _working = true);
    final size = widget.canvasSize;
    final rgba = await _photoOnCanvasRgba(size);
    final lineArt = await _lineArtImage(rgba, size.width.round(), size.height.round());
    if (!mounted) {
      lineArt.dispose();
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CanvasScreen(
          initialCanvasSize: size,
          initialLineArt: lineArt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('🖍️ Colorear una foto'),
        backgroundColor: const Color(0xFF2A2A3D),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: widget.canvasSize.aspectRatio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_preview != null)
                                  RawImage(image: _preview, fit: BoxFit.fill),
                                if (_working)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFFF69B4),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Poquito', style: TextStyle(color: Colors.white70)),
                        Expanded(
                          child: Slider(
                            value: _detail,
                            activeColor: const Color(0xFFFF69B4),
                            label: 'Detalle',
                            onChanged: (v) => setState(() => _detail = v),
                            onChangeEnd: (_) => _regeneratePreview(),
                          ),
                        ),
                        const Text('Muchísimo', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                    SwitchListTile(
                      value: _thick,
                      activeThumbColor: const Color(0xFFFF69B4),
                      title: const Text(
                        'Líneas gruesas ✏️',
                        style: TextStyle(color: Colors.white),
                      ),
                      onChanged: (v) {
                        setState(() => _thick = v);
                        _regeneratePreview();
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF69B4),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: _working || _preview == null ? null : _startColoring,
                      icon: const Icon(Icons.format_paint_rounded, size: 28),
                      label: const Text(
                        '¡A pintar! 🎨',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
