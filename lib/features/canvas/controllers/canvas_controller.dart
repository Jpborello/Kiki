import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/layer.dart';
import '../../../core/models/project.dart';
import '../../../core/models/stroke.dart';
import '../../../core/storage/project_repository.dart';
import '../../coloring_book/flood_fill.dart';
import '../brushes/brush_library.dart';
import '../engine/history.dart';
import '../engine/layer_compositor.dart';
import '../engine/layer_runtime.dart';

import '../../../core/models/symmetry.dart';

/// Comando de "agregar un trazo o un relleno a una capa". Es liviano: no
/// guarda una imagen del lienzo entero, solo la referencia a la capa y el
/// edit (los datos del trazo, o el parche chico del relleno). La imagen
/// resultante la calcula el propio [LayerRuntime].
class AddEditCommand extends Command {
  AddEditCommand({
    required this.layerRuntime,
    required this.edit,
    required this.canvasSize,
  });

  final LayerRuntime layerRuntime;
  final LayerEdit edit;
  final Size canvasSize;

  @override
  Future<void> execute() => layerRuntime.addEdit(edit, canvasSize);

  @override
  Future<void> undo() => layerRuntime.removeLastEdit(canvasSize);

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

  /// [lineArt] (solo para proyectos nuevos): dibujo para colorear del
  /// tamaño del lienzo. Va en una capa bloqueada arriba de todo, así se
  /// pinta por debajo sin borrar las líneas.
  static Future<CanvasController> create(
    Project? existingProject, {
    Size? initialCanvasSize,
    ui.Image? lineArt,
  }) async {
    final Size canvasSize = existingProject?.canvasSize ??
        initialCanvasSize ??
        const Size(2048, 2048);

    final linesLayerId = const Uuid().v4();
    final project = existingProject ??
        Project(
          id: const Uuid().v4(),
          name: lineArt != null ? 'Mi Dibujo para Colorear' : 'Mi Obra Mágica',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          canvasSize: canvasSize,
          layers: [
            Layer(id: const Uuid().v4(), name: 'Capa 1', order: 0),
            if (lineArt != null)
              Layer(id: linesLayerId, name: 'Líneas', order: 1, locked: true),
          ],
        );

    final Map<String, LayerRuntime> runtimes = {};
    for (final layer in project.layers) {
      ui.Image? loaded;
      if (existingProject != null) {
        loaded = await _loadLayerImage(project.id, layer.imagePath);
      } else if (layer.id == linesLayerId) {
        loaded = lineArt;
      }
      final baseImage = loaded ?? await LayerCompositor.createBlankImage(canvasSize);
      runtimes[layer.id] = LayerRuntime(layerId: layer.id, checkpointImage: baseImage);
    }

    // Nunca se dibuja sobre una capa bloqueada (las líneas para colorear).
    final drawableLayer = project.layers.firstWhere(
      (l) => !l.locked,
      orElse: () => project.layers.first,
    );
    final isColoringBook = project.layers.any((l) => l.locked);

    ui.Image? loadedTracing;
    if (project.tracingImagePath != null) {
      loadedTracing = await _loadLayerImage(project.id, project.tracingImagePath);
    }

    final initialState = CanvasState(
      project: project,
      activeLayerId: drawableLayer.id,
      layerRuntimes: runtimes,
      // En un dibujo para colorear lo primero que se quiere es el balde.
      activeBrush: isColoringBook ? BrushLibrary.bucket : BrushLibrary.pencil,
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

    final cmd = AddEditCommand(
      layerRuntime: runtime,
      edit: pendingStroke,
      canvasSize: state.project.canvasSize,
    );

    await historyManager.pushAndExecute(cmd);

    state = state.copyWith(
      clearCurrentStroke: true,
      canUndo: historyManager.canUndo,
      canRedo: historyManager.canRedo,
    );

    _countEditForAutosave();
  }

  void _countEditForAutosave() {
    _strokesSinceAutosave++;
    if (_strokesSinceAutosave >= _autosaveEveryNStrokes) {
      _strokesSinceAutosave = 0;
      unawaited(saveProject());
    }
  }

  bool _isFilling = false;

  /// Balde de pintura: rellena con el color activo la zona que se ve en
  /// [canvasPos] (todas las capas compuestas, sin la foto de calco) y lo
  /// pinta en la capa activa. Con la capa de líneas arriba, el relleno
  /// queda debajo de las líneas y no las tapa.
  Future<void> fillAt(Offset canvasPos) async {
    if (_isFilling) return;
    final runtime = state.layerRuntimes[state.activeLayerId];
    if (runtime == null) return;
    _isFilling = true;
    try {
      final canvasSize = state.project.canvasSize;
      final flattened = await LayerCompositor.flattenLayers(
        layers: state.project.layers,
        layerImages: state.layerImages,
        canvasSize: canvasSize,
        includeSignature: false,
      );
      final byteData = await flattened.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = flattened.width;
      final height = flattened.height;
      flattened.dispose();
      if (byteData == null) return;
      final barrier = await _lineBarrier();

      final result = await compute(
        floodFill,
        FloodFillRequest(
          rgba: byteData.buffer.asUint8List(),
          width: width,
          height: height,
          x: canvasPos.dx.floor(),
          y: canvasPos.dy.floor(),
          color: state.activeColor.toARGB32(),
          // Las líneas engrosadas tapan 2 px de desborde sin problema.
          grow: 2,
          barrier: barrier,
          // Las líneas sacadas de una foto suelen tener cortes chicos.
          gapClose: math.max(2, (math.min(width, height) / 300).round()),
        ),
      );
      if (result == null || !mounted) return;

      final patch = await _imageFromRgba(result.rgba, result.width, result.height);
      final cmd = AddEditCommand(
        layerRuntime: runtime,
        edit: FillEdit(
          patch: patch,
          offset: Offset(result.left.toDouble(), result.top.toDouble()),
        ),
        canvasSize: canvasSize,
      );
      await historyManager.pushAndExecute(cmd);
      if (!mounted) return;
      state = state.copyWith(
        canUndo: historyManager.canUndo,
        canRedo: historyManager.canRedo,
      );
      _countEditForAutosave();
    } catch (e) {
      debugPrint('Error rellenando con el balde: $e');
    } finally {
      _isFilling = false;
    }
  }

  Uint8List? _lineBarrierCache;

  /// Alfa (un byte por píxel) de las capas bloqueadas, o sea las líneas
  /// del dibujo para colorear; `null` si no hay. Esas capas nunca se
  /// editan, así que se calcula una sola vez.
  Future<Uint8List?> _lineBarrier() async {
    if (_lineBarrierCache != null) return _lineBarrierCache;
    final locked = state.project.layers.where((l) => l.locked && l.visible).toList();
    if (locked.isEmpty) return null;

    final size = state.project.canvasSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    for (final layer in locked) {
      final image = state.layerImages[layer.id];
      if (image != null) canvas.drawImage(image, Offset.zero, Paint());
    }
    final composed = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final data = await composed.toByteData(format: ui.ImageByteFormat.rawRgba);
    composed.dispose();
    if (data == null) return null;

    final rgba = data.buffer.asUint8List();
    final alpha = Uint8List(rgba.length ~/ 4);
    for (var i = 0; i < alpha.length; i++) {
      alpha[i] = rgba[i * 4 + 3];
    }
    return _lineBarrierCache = alpha;
  }

  static Future<ui.Image> _imageFromRgba(Uint8List rgba, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
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
