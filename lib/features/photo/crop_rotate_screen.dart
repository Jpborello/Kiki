import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Abre la pantalla para recortar y girar la foto. Devuelve la foto ya
/// recortada (PNG), o `null` si se volvió atrás.
Future<Uint8List?> cropAndRotatePhoto(BuildContext context, Uint8List bytes) {
  return Navigator.push<Uint8List>(
    context,
    MaterialPageRoute(builder: (_) => CropRotateScreen(photoBytes: bytes)),
  );
}

/// Recorte simple hecho a mano (sin paquetes nativos) para que ande igual
/// en Android y en web: se arrastra el rectángulo o sus esquinas y se gira
/// de a 90°.
class CropRotateScreen extends StatefulWidget {
  const CropRotateScreen({super.key, required this.photoBytes});

  final Uint8List photoBytes;

  @override
  State<CropRotateScreen> createState() => _CropRotateScreenState();
}

enum _DragTarget { move, topLeft, topRight, bottomLeft, bottomRight }

class _CropRotateScreenState extends State<CropRotateScreen> {
  /// Lado mínimo del recorte, como fracción de la foto.
  static const double _minFraction = 0.1;

  /// Radio (en px de pantalla) en el que se agarra una esquina. Grande a
  /// propósito para dedos chiquitos.
  static const double _handleGrab = 36;

  ui.Image? _photo;
  String? _error;
  bool _working = false;

  /// Cuartos de vuelta en sentido horario (0..3).
  int _quarterTurns = 0;

  /// Recorte en coordenadas normalizadas (0..1) de la foto ya girada.
  Rect _crop = const Rect.fromLTWH(0, 0, 1, 1);

  _DragTarget? _dragTarget;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _photo?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.photoBytes);
      final image = (await codec.getNextFrame()).image;
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _photo = image);
    } catch (e) {
      debugPrint('No se pudo abrir la foto: $e');
      if (mounted) setState(() => _error = 'No pudimos abrir esa foto 😕');
    }
  }

  /// Tamaño de la foto después de girarla.
  Size get _rotatedSize {
    final photo = _photo!;
    final w = photo.width.toDouble();
    final h = photo.height.toDouble();
    return _quarterTurns.isOdd ? Size(h, w) : Size(w, h);
  }

  void _rotate() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      // Girar el recorte junto con la foto (horario: x' = 1 - y - h, y' = x).
      _crop = Rect.fromLTWH(
        1 - _crop.bottom,
        _crop.left,
        _crop.height,
        _crop.width,
      );
    });
  }

  void _resetCrop() => setState(() => _crop = const Rect.fromLTWH(0, 0, 1, 1));

  void _onPanStart(Offset local, Rect imageRect) {
    final crop = _toScreen(_crop, imageRect);
    final corners = {
      _DragTarget.topLeft: crop.topLeft,
      _DragTarget.topRight: crop.topRight,
      _DragTarget.bottomLeft: crop.bottomLeft,
      _DragTarget.bottomRight: crop.bottomRight,
    };
    _DragTarget? best;
    var bestDistance = _handleGrab;
    corners.forEach((target, point) {
      final d = (point - local).distance;
      if (d <= bestDistance) {
        best = target;
        bestDistance = d;
      }
    });
    // Fuera de las esquinas, cualquier lugar mueve el recorte entero.
    _dragTarget = best ?? _DragTarget.move;
  }

  void _onPanUpdate(Offset delta, Rect imageRect) {
    final target = _dragTarget;
    if (target == null) return;
    final dx = delta.dx / imageRect.width;
    final dy = delta.dy / imageRect.height;
    var l = _crop.left, t = _crop.top, r = _crop.right, b = _crop.bottom;
    switch (target) {
      case _DragTarget.move:
        final mx = dx.clamp(-l, 1 - r);
        final my = dy.clamp(-t, 1 - b);
        l += mx;
        r += mx;
        t += my;
        b += my;
      case _DragTarget.topLeft:
        l = (l + dx).clamp(0.0, r - _minFraction);
        t = (t + dy).clamp(0.0, b - _minFraction);
      case _DragTarget.topRight:
        r = (r + dx).clamp(l + _minFraction, 1.0);
        t = (t + dy).clamp(0.0, b - _minFraction);
      case _DragTarget.bottomLeft:
        l = (l + dx).clamp(0.0, r - _minFraction);
        b = (b + dy).clamp(t + _minFraction, 1.0);
      case _DragTarget.bottomRight:
        r = (r + dx).clamp(l + _minFraction, 1.0);
        b = (b + dy).clamp(t + _minFraction, 1.0);
    }
    setState(() => _crop = Rect.fromLTRB(l, t, r, b));
  }

  static Rect _toScreen(Rect normalized, Rect imageRect) => Rect.fromLTRB(
    imageRect.left + normalized.left * imageRect.width,
    imageRect.top + normalized.top * imageRect.height,
    imageRect.left + normalized.right * imageRect.width,
    imageRect.top + normalized.bottom * imageRect.height,
  );

  /// Dibuja la foto girada y recortada y la devuelve como PNG.
  Future<void> _finish() async {
    final photo = _photo;
    if (photo == null) return;
    setState(() => _working = true);
    try {
      final rotated = _rotatedSize;
      final src = Rect.fromLTRB(
        _crop.left * rotated.width,
        _crop.top * rotated.height,
        _crop.right * rotated.width,
        _crop.bottom * rotated.height,
      );
      final outW = math.max(1, src.width.round());
      final outH = math.max(1, src.height.round());

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.translate(-src.left, -src.top);
      // Girar la foto entera alrededor del centro de la versión girada.
      canvas.translate(rotated.width / 2, rotated.height / 2);
      canvas.rotate(_quarterTurns * math.pi / 2);
      canvas.translate(-photo.width / 2, -photo.height / 2);
      canvas.drawImage(
        photo,
        Offset.zero,
        Paint()..filterQuality = FilterQuality.high,
      );
      final image = await recorder.endRecording().toImage(outW, outH);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted) return;
      Navigator.pop(context, data!.buffer.asUint8List());
    } catch (e) {
      debugPrint('No se pudo recortar la foto: $e');
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('✂️ Recortar la foto'),
        backgroundColor: const Color(0xFF2A2A3D),
      ),
      body: SafeArea(
        child:
            _error != null
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
                      Text(
                        'Mové el cuadro o tirá de las esquinas 👆',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child:
                            _photo == null
                                ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFFF69B4),
                                  ),
                                )
                                : LayoutBuilder(builder: _buildEditor),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _BigButton(
                              emoji: '🔄',
                              label: 'Girar',
                              color: const Color(0xFF00E5FF),
                              onTap:
                                  _photo == null || _working ? null : _rotate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _BigButton(
                              emoji: '🖼️',
                              label: 'Toda',
                              color: const Color(0xFFFFD700),
                              onTap:
                                  _photo == null || _working
                                      ? null
                                      : _resetCrop,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _BigButton(
                              emoji: '✅',
                              label: '¡Listo!',
                              color: const Color(0xFFFF69B4),
                              onTap:
                                  _photo == null || _working ? null : _finish,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context, BoxConstraints constraints) {
    // Margen para que las esquinas del recorte no queden cortadas en el borde.
    final area = (Offset.zero & constraints.biggest).deflate(16);
    final fitted = applyBoxFit(BoxFit.contain, _rotatedSize, area.size).destination;
    final imageRect = Alignment.center.inscribe(fitted, area);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _onPanStart(d.localPosition, imageRect),
      onPanUpdate: (d) => _onPanUpdate(d.delta, imageRect),
      onPanEnd: (_) => _dragTarget = null,
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: imageRect,
            child: RotatedBox(
              quarterTurns: _quarterTurns,
              child: RawImage(image: _photo, fit: BoxFit.fill),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _CropOverlayPainter(
                imageRect: imageRect,
                crop: _toScreen(_crop, imageRect),
              ),
            ),
          ),
          if (_working)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF69B4)),
            ),
        ],
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.imageRect, required this.crop});

  final Rect imageRect;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    // Oscurecer lo que queda afuera del recorte.
    final outside =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(imageRect)
          ..addRect(crop);
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    canvas.drawRect(
      crop,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final handleFill = Paint()..color = const Color(0xFFFF69B4);
    final handleBorder =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    for (final corner in [
      crop.topLeft,
      crop.topRight,
      crop.bottomLeft,
      crop.bottomRight,
    ]) {
      canvas.drawCircle(corner, 14, handleFill);
      canvas.drawCircle(corner, 14, handleBorder);
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.imageRect != imageRect || old.crop != crop;
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color, width: 2.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
