import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/models/brush.dart';
import '../../../core/models/stroke.dart';
import '../../../core/models/symmetry.dart';
import 'stroke_engine.dart';

/// Un trazo listo para redibujarse dentro de una capa, junto con el
/// pincel y (si corresponde) el shader que se usó para pintarlo.
class PendingStroke {
  final Stroke stroke;
  final Brush brush;
  final ui.FragmentShader? shader;
  final double time;
  final SymmetryMode symmetryMode;

  const PendingStroke({
    required this.stroke,
    required this.brush,
    this.shader,
    this.time = 0.0,
    this.symmetryMode = SymmetryMode.none,
  });
}

/// Estado "vivo" de una capa mientras se dibuja.
///
/// En vez de guardar una imagen completa (4096x4096 ~ 64MB) por cada
/// trazo del historial, cada capa mantiene:
///  - `checkpointImage`: una imagen horneada permanente (no se puede
///    deshacer más allá de este punto).
///  - `pending`: la lista de trazos aplicados encima del checkpoint,
///    livianos (solo puntos + color), que sí se pueden deshacer/rehacer.
///
/// Cuando la lista de pendientes crece demasiado, [promoteOldestToCheckpoint]
/// funde el trazo más viejo dentro del checkpoint y lo saca de la lista,
/// así la memoria usada por el historial queda acotada.
class LayerRuntime {
  LayerRuntime({
    required this.layerId,
    required ui.Image checkpointImage,
  })  : _checkpointImage = checkpointImage,
        _compositeImage = checkpointImage;

  final String layerId;
  ui.Image _checkpointImage;
  ui.Image _compositeImage;
  final List<PendingStroke> _pending = [];

  ui.Image get compositeImage => _compositeImage;
  int get pendingCount => _pending.length;

  Future<void> addStroke(PendingStroke pendingStroke, Size canvasSize) async {
    _pending.add(pendingStroke);
    await _rebuildComposite(canvasSize);
  }

  Future<void> removeLastStroke(Size canvasSize) async {
    if (_pending.isEmpty) return;
    _pending.removeLast();
    await _rebuildComposite(canvasSize);
  }

  /// Funde el trazo más viejo de la lista de pendientes dentro del
  /// checkpoint. A partir de acá ese trazo ya no se puede deshacer.
  Future<void> promoteOldestToCheckpoint(Size canvasSize) async {
    if (_pending.isEmpty) return;
    final oldest = _pending.removeAt(0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
    );
    canvas.drawImage(_checkpointImage, Offset.zero, Paint());
    _paintStroke(canvas, canvasSize, oldest);
    final picture = recorder.endRecording();
    final newCheckpoint = await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );

    _checkpointImage.dispose();
    _checkpointImage = newCheckpoint;
  }

  Future<void> _rebuildComposite(Size canvasSize) async {
    final previousComposite = _compositeImage;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
    );
    canvas.drawImage(_checkpointImage, Offset.zero, Paint());
    for (final p in _pending) {
      _paintStroke(canvas, canvasSize, p);
    }
    final picture = recorder.endRecording();
    _compositeImage = await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );

    if (!identical(previousComposite, _checkpointImage)) {
      previousComposite.dispose();
    }
  }

  void _paintStroke(Canvas canvas, Size canvasSize, PendingStroke p) {
    StrokeEngine.paintStroke(
      canvas,
      canvasSize,
      p.stroke,
      p.brush,
      shader: p.shader,
      time: p.time,
      symmetry: p.symmetryMode,
    );
  }

  void dispose() {
    _checkpointImage.dispose();
    if (!identical(_compositeImage, _checkpointImage)) {
      _compositeImage.dispose();
    }
  }
}
