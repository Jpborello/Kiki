import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/layer.dart';
import '../../../core/models/project.dart';
import '../../../core/models/stroke.dart';
import '../../../core/storage/project_repository.dart';
import '../brushes/brush_library.dart';
import '../engine/history.dart';
import '../engine/layer_compositor.dart';
import '../engine/layer_runtime.dart';

import '../../../core/models/symmetry.dart';

/// Comando de "agregar un trazo a una capa". Es liviano: no guarda
/// imágenes, solo la referencia a la capa y los datos del trazo. La
/// imagen resultante la calcula el propio [LayerRuntime].
class AddStrokeCommand extends Command {
  AddStrokeCommand({
    required this.layerRuntime,
    required this.pendingStroke,
    required this.canvasSize,
  });

  final LayerRuntime layerRuntime;
  final PendingStroke pendingStroke;
  final Size canvasSize;

  @override
  Future<void> execute() => layerRuntime.addStroke(pendingStroke, canvasSize);

  @override
  Future<void> undo() => layerRuntime.removeLastStroke(canvasSize);

  @override
  Future<void> commitPermanently() =>
      layerRuntime.promoteOldestToCheckpoint(canvasSize);
}

class CanvasState {
  final Project project;
  final String activeLayerId;
  final Map<String, LayerRuntime> layerRuntimes;
  final Brush activeBrush;
  final Color activeColor;
  final Stroke? currentStroke;
  final bool isTracingMode;
  final ui.Image? tracingImage;
  final SymmetryMode symmetryMode;
  final bool canUndo;
  final bool canRedo;
  final bool isSaving;

  CanvasState({
    required this.project,
    required this.activeLayerId,
    required this.layerRuntimes,
    required this.activeBrush,
    required this.activeColor,
    this.currentStroke,
    this.isTracingMode = false,
    this.tracingImage,
    this.symmetryMode = SymmetryMode.none,
    this.canUndo = false,
    this.canRedo = false,
    this.isSaving = false,
  });

  /// Imagen actual (checkpoint + trazos pendientes) de cada capa, para
  /// que el painter la dibuje.
  Map<String, ui.Image> get layerImages => {
        for (final entry in layerRuntimes.entries)
          entry.key: entry.value.compositeImage,
      };

  CanvasState copyWith({
    Project? project,
    String? activeLayerId,
    Brush? activeBrush,
    Color? activeColor,
    Stroke? currentStroke,
    bool clearCurrentStroke = false,
    bool? isTracingMode,
    ui.Image? tracingImage,
    bool clearTracingImage = false,
    SymmetryMode? symmetryMode,
    bool? canUndo,
    bool? canRedo,
    bool? isSaving,
  }) {
    return CanvasState(
      project: project ?? this.project,
      activeLayerId: activeLayerId ?? this.activeLayerId,
      layerRuntimes: layerRuntimes,
      activeBrush: activeBrush ?? this.activeBrush,
      activeColor: activeColor ?? this.activeColor,
      currentStroke:
          clearCurrentStroke ? null : (currentStroke ?? this.currentStroke),
      isTracingMode: isTracingMode ?? this.isTracingMode,
      tracingImage: clearTracingImage ? null : (tracingImage ?? this.tracingImage),
      symmetryMode: symmetryMode ?? this.symmetryMode,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class CanvasController extends StateNotifier<CanvasState> {
  CanvasController(super.initialState);

  final HistoryManager historyManager = HistoryManager();
  final ProjectRepository _repository = ProjectRepository();
  final _uuid = const Uuid();
  int _strokesSinceAutosave = 0;

  static const int _autosaveEveryNStrokes = 8;

  CanvasState get currentState => state;

  static Future<CanvasController> create(
    Project? existingProject, {
    Size? initialCanvasSize,
  }) async {
    final Size canvasSize = existingProject?.canvasSize ??
        initialCanvasSize ??
        const Size(2048, 2048);

    final project = existingProject ??
        Project(
          id: const Uuid().v4(),
          name: 'Mi Obra Mágica',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          canvasSize: canvasSize,
          layers: [
            Layer(id: const Uuid().v4(), name: 'Capa 1', order: 0),
          ],
        );

    final Map<String, LayerRuntime> runtimes = {};
    for (final layer in project.layers) {
      ui.Image? loaded;
      if (existingProject != null) {
        loaded = await _loadLayerImage(project.id, layer.imagePath);
      }
      final baseImage = loaded ?? await LayerCompositor.createBlankImage(canvasSize);
      runtimes[layer.id] = LayerRuntime(layerId: layer.id, checkpointImage: baseImage);
    }

    ui.Image? loadedTracing;
    if (project.tracingImagePath != null) {
      loadedTracing = await _loadLayerImage(project.id, project.tracingImagePath);
    }

    final initialState = CanvasState(
      project: project,
      activeLayerId: project.layers.first.id,
      layerRuntimes: runtimes,
      activeBrush: BrushLibrary.pencil,
      activeColor: const Color(0xFFFF69B4),
      tracingImage: loadedTracing,
      isTracingMode: loadedTracing != null,
    );

    return CanvasController(initialState);
  }

  /// Carga el PNG horneado de una capa guardada (si existe) para que al
  /// reabrir un proyecto desde la Galería se vea el dibujo tal cual
  /// quedó, en vez de un lienzo en blanco.
  static Future<ui.Image?> _loadLayerImage(
    String projectId,
    String? imagePath,
  ) async {
    if (imagePath == null) return null;
    try {
      final bytes = await ProjectRepository().readFile(projectId, imagePath);
      if (bytes == null) return null;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('No se pudo cargar la capa guardada ($imagePath): $e');
      return null;
    }
  }

  void selectBrush(Brush brush) {
    state = state.copyWith(activeBrush: brush);
  }

  void selectColor(Color color) {
    state = state.copyWith(activeColor: color);
  }

  void setBrushSize(double size) {
    state = state.copyWith(activeBrush: state.activeBrush.copyWith(size: size));
  }

  void setBrushOpacity(double opacity) {
    state = state.copyWith(activeBrush: state.activeBrush.copyWith(opacity: opacity));
  }

  void startStroke(Offset position, double pressure, double tilt) {
    final stroke = Stroke(
      id: _uuid.v4(),
      brushId: state.activeBrush.id,
      color: state.activeColor,
      points: [
        StrokePoint(
          position: position,
          pressure: pressure,
          tilt: tilt,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        )
      ],
    );
    state = state.copyWith(currentStroke: stroke);
  }

  void updateStroke(Offset position, double pressure, double tilt) {
    if (state.currentStroke == null) return;
    final updatedPoints = List<StrokePoint>.from(state.currentStroke!.points)
      ..add(
        StrokePoint(
          position: position,
          pressure: pressure,
          tilt: tilt,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    final updatedStroke = Stroke(
      id: state.currentStroke!.id,
      brushId: state.currentStroke!.brushId,
      color: state.currentStroke!.color,
      points: updatedPoints,
    );
    state = state.copyWith(currentStroke: updatedStroke);
  }

  /// Cancela el trazo en curso sin hornearlo. Se usa, por ejemplo,
  /// cuando aparece un segundo dedo y la app pasa a modo pan/zoom.
  void cancelStroke() {
    if (state.currentStroke == null) return;
    state = state.copyWith(clearCurrentStroke: true);
  }

  void setSymmetryMode(SymmetryMode mode) {
    state = state.copyWith(symmetryMode: mode);
  }

  void setTracingOpacity(double opacity) {
    state.project.tracingOpacity = opacity;
    state = state.copyWith(project: state.project);
  }

  void toggleTracingVisible() {
    state.project.tracingVisible = !state.project.tracingVisible;
    state = state.copyWith(project: state.project);
  }

  void removeTracingImage() {
    state.project.tracingImagePath = null;
    state = state.copyWith(
      project: state.project,
      clearTracingImage: true,
      isTracingMode: false,
    );
  }

  Future<void> setTracingImageFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      const tracingFileName = 'tracing_ref.png';
      await _repository.writeFile(state.project.id, tracingFileName, bytes);

      state.project.tracingImagePath = tracingFileName;
      state.project.tracingVisible = true;

      state = state.copyWith(
        project: state.project,
        tracingImage: image,
        isTracingMode: true,
      );
    } catch (e) {
      debugPrint('Error configurando imagen de calco: $e');
    }
  }

  Future<void> endStroke({ui.FragmentShader? shader, double time = 0.0}) async {
    final stroke = state.currentStroke;
    if (stroke == null) return;

    final layerId = state.activeLayerId;
    final runtime = state.layerRuntimes[layerId];
    if (runtime == null) {
      state = state.copyWith(clearCurrentStroke: true);
      return;
    }

    final pendingStroke = PendingStroke(
      stroke: stroke,
      brush: state.activeBrush,
      shader: shader,
      time: time,
      symmetryMode: state.symmetryMode,
    );

    final cmd = AddStrokeCommand(
      layerRuntime: runtime,
      pendingStroke: pendingStroke,
      canvasSize: state.project.canvasSize,
    );

    await historyManager.pushAndExecute(cmd);

    state = state.copyWith(
      clearCurrentStroke: true,
      canUndo: historyManager.canUndo,
      canRedo: historyManager.canRedo,
    );

    _strokesSinceAutosave++;
    if (_strokesSinceAutosave >= _autosaveEveryNStrokes) {
      _strokesSinceAutosave = 0;
      unawaited(saveProject());
    }
  }

  Future<void> undo() async {
    await historyManager.undo();
    state = state.copyWith(
      canUndo: historyManager.canUndo,
      canRedo: historyManager.canRedo,
    );
  }

  Future<void> redo() async {
    await historyManager.redo();
    state = state.copyWith(
      canUndo: historyManager.canUndo,
      canRedo: historyManager.canRedo,
    );
  }

  /// Compone todas las capas y las guarda: manifest.json + un PNG por
  /// capa + miniatura. Se llama sola cada [_autosaveEveryNStrokes]
  /// trazos y también se puede disparar a mano (botón de guardar, o al
  /// salir de la pantalla).
  Future<void> saveProject() async {
    if (state.isSaving) return;
    state = state.copyWith(isSaving: true);
    try {
      final project = state.project;
      project.updatedAt = DateTime.now();

      for (final layer in project.layers) {
        final runtime = state.layerRuntimes[layer.id];
        if (runtime == null) continue;
        final byteData =
            await runtime.compositeImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;
        final fileName = 'layer_${layer.id}.png';
        layer.imagePath = fileName;
        await _repository.writeFile(
          project.id,
          fileName,
          byteData.buffer.asUint8List(),
        );
      }

      final flattened = await LayerCompositor.flattenLayers(
        layers: project.layers,
        layerImages: state.layerImages,
        canvasSize: project.canvasSize,
      );
      final thumbBytes = await flattened.toByteData(format: ui.ImageByteFormat.png);
      flattened.dispose();
      if (thumbBytes != null) {
        await _repository.writeFile(
          project.id,
          ProjectRepository.thumbnailFileName,
          thumbBytes.buffer.asUint8List(),
        );
        project.thumbnailPath = ProjectRepository.thumbnailFileName;
      }

      await _repository.saveProject(project);
      // La pantalla puede haberse cerrado mientras esto se guardaba
      // (autoguardado en curso al salir): si ya no está montado, no
      // hay que tocar el estado.
      if (!mounted) return;
      state = state.copyWith(project: project, isSaving: false);
    } catch (e) {
      debugPrint('Error guardando proyecto: $e');
      if (!mounted) return;
      state = state.copyWith(isSaving: false);
    }
  }

  /// Todas las capas compuestas en una sola imagen, lista para exportar
  /// (por ejemplo a la galería del dispositivo). A diferencia de sacar
  /// la capa activa sola, esto sí refleja lo que la nena ve en pantalla.
  Future<ui.Image> flattenForExport() {
    return LayerCompositor.flattenLayers(
      layers: state.project.layers,
      layerImages: state.layerImages,
      canvasSize: state.project.canvasSize,
    );
  }

  @override
  void dispose() {
    for (final runtime in state.layerRuntimes.values) {
      runtime.dispose();
    }
    super.dispose();
  }
}
