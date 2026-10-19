import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/models/brush.dart';
import '../../../core/models/stroke.dart';
import '../../../core/models/symmetry.dart';
import 'stroke_engine.dart';

/// Algo que se pinta encima del checkpoint de una capa y que, mientras
/// esté en el historial, se puede deshacer: un trazo o un relleno.
abstract class LayerEdit {
  void paint(Canvas canvas, Size canvasSize);

  /// Se llama cuando el edit ya se fundió en el checkpoint y no se va a
  /// volver a pintar.
  void dispose() {}
}

/// Un trazo listo para redibujarse dentro de una capa, junto con el
/// pincel y (si corresponde) el shader que se usó para pintarlo.
class PendingStroke extends LayerEdit {
  final Stroke stroke;
  final Brush brush;
  final ui.FragmentShader? shader;
  final double time;
  final SymmetryMode symmetryMode;

  PendingStroke({
    required this.stroke,
    required this.brush,
    this.shader,
    this.time = 0.0,
    this.symmetryMode = SymmetryMode.none,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    StrokeEngine.paintStroke(
      canvas,
      canvasSize,
      stroke,
      brush,
      shader: shader,
      time: time,
      symmetry: symmetryMode,
    );
  }
}

/// Relleno con balde: un parche ya calculado (solo del tamaño de la zona
/// rellenada, no del lienzo entero) que se dibuja en [offset].
class FillEdit extends LayerEdit {
  FillEdit({required this.patch, required this.offset});

  final ui.Image patch;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    canvas.drawImage(patch, offset, Paint());
  }

  @override
  void dispose() => patch.dispose();
}

/// Estado "vivo" de una capa mientras se dibuja.
///
/// En vez de guardar una imagen completa (4096x4096 ~ 64MB) por cada
/// trazo del historial, cada capa mantiene:
///  - `checkpointImage`: una imagen horneada permanente (no se puede
///    deshacer más allá de este punto).
///  - `pending`: la lista de edits aplicados encima del checkpoint
///    (trazos, que son solo puntos + color, o parches de relleno), que
///    sí se pueden deshacer/rehacer.
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
  final List<LayerEdit> _pending = [];

  ui.Image get compositeImage => _compositeImage;
  int get pendingCount => _pending.length;

  Future<void> addEdit(LayerEdit edit, Size canvasSize) async {
    _pending.add(edit);
    await _rebuildComposite(canvasSize);
  }

  Future<void> removeLastEdit(Size canvasSize) async {
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
    oldest.paint(canvas, canvasSize);
    final picture = recorder.endRecording();
    final newCheckpoint = await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );

    _checkpointImage.dispose();
    _checkpointImage = newCheckpoint;
    oldest.dispose();
  }

  Future<void> _rebuildComposite(Size canvasSize) async {
    final previousComposite = _compositeImage;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
    );
    canvas.drawImage(_checkpointImage, Offset.zero, Paint());
    for (final edit in _pending) {
      edit.paint(canvas, canvasSize);
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

  void dispose() {
    _checkpointImage.dispose();
    if (!identical(_compositeImage, _checkpointImage)) {
      _compositeImage.dispose();
    }
  }
}
