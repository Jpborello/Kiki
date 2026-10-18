import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/layer.dart';
import '../../../core/models/project.dart';
import '../../../core/models/stroke.dart';
import '../brushes/brush_library.dart';
import '../engine/history.dart';
import '../engine/layer_compositor.dart';

class CanvasState {
  final Project project;
  final String activeLayerId;
  final Map<String, ui.Image> layerImages;
  final Brush activeBrush;
  final Color activeColor;
  final Stroke? currentStroke;
  final bool isTracingMode;
  final bool canUndo;
  final bool canRedo;

  CanvasState({
    required this.project,
    required this.activeLayerId,
    required this.layerImages,
    required this.activeBrush,
    required this.activeColor,
    this.currentStroke,
    this.isTracingMode = false,
    this.canUndo = false,
    this.canRedo = false,
  });

  CanvasState copyWith({
    Project? project,
    String? activeLayerId,
    Map<String, ui.Image>? layerImages,
    Brush? activeBrush,
    Color? activeColor,
    Stroke? currentStroke,
    bool clearCurrentStroke = false,
    bool? isTracingMode,
    bool? canUndo,
    bool? canRedo,
  }) {
    return CanvasState(
      project: project ?? this.project,
      activeLayerId: activeLayerId ?? this.activeLayerId,
      layerImages: layerImages ?? this.layerImages,
      activeBrush: activeBrush ?? this.activeBrush,
      activeColor: activeColor ?? this.activeColor,
      currentStroke: clearCurrentStroke ? null : (currentStroke ?? this.currentStroke),
      isTracingMode: isTracingMode ?? this.isTracingMode,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
    );
  }
}

class CanvasController extends StateNotifier<CanvasState> {
  final HistoryManager historyManager = HistoryManager();
  final _uuid = const Uuid();

  CanvasController(Project project, Map<String, ui.Image> initialLayerImages)
      : super(
          CanvasState(
            project: project,
            activeLayerId: project.layers.first.id,
            layerImages: initialLayerImages,
            activeBrush: BrushLibrary.pencil,
            activeColor: const Color(0xFFFF69B4),
          ),
        );

  CanvasState get currentState => state;

  static Future<CanvasController> create(Project? existingProject) async {
    final Size canvasSize = existingProject?.canvasSize ?? const Size(4096, 4096);
    final String layerId = const Uuid().v4();
    final Layer defaultLayer = Layer(
      id: layerId,
      name: 'Capa 1',
      order: 0,
    );

    final project = existingProject ??
        Project(
          id: const Uuid().v4(),
          name: 'Mi Obra Mágica',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          canvasSize: canvasSize,
          layers: [defaultLayer],
        );

    final blankImage = await LayerCompositor.createBlankImage(canvasSize);
    final Map<String, ui.Image> images = {
      for (var l in project.layers) l.id: blankImage,
    };

    return CanvasController(project, images);
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

  Future<void> endStroke({ui.FragmentShader? shader, double time = 0.0}) async {
    final stroke = state.currentStroke;
    if (stroke == null) return;

    final layerId = state.activeLayerId;
    final currentImage = state.layerImages[layerId];

    if (currentImage != null) {
      final bakedImage = await LayerCompositor.bakeStrokeIntoImage(
        existingImage: currentImage,
        stroke: stroke,
        brush: state.activeBrush,
        canvasSize: state.project.canvasSize,
        shader: shader,
        time: time,
      );

      final cmd = StrokeCommand(
        oldImage: currentImage,
        newImage: bakedImage,
        onImageChanged: (newImg) {
          final updatedImages = Map<String, ui.Image>.from(state.layerImages);
          updatedImages[layerId] = newImg;
          state = state.copyWith(
            layerImages: updatedImages,
            canUndo: historyManager.canUndo,
            canRedo: historyManager.canRedo,
          );
        },
      );

      await historyManager.pushAndExecute(cmd);
    }

    state = state.copyWith(
      clearCurrentStroke: true,
      canUndo: historyManager.canUndo,
      canRedo: historyManager.canRedo,
    );
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
}
