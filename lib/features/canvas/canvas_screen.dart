import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/museum_frame.dart';
import '../../core/models/project.dart';
import '../../core/models/symmetry.dart';
import 'brushes/brush_library.dart';
import 'controllers/canvas_controller.dart';
import 'engine/layer_compositor.dart';
import 'painters/active_stroke_painter.dart';
import 'painters/layer_painter.dart';
import 'widgets/celebration_export_dialog.dart';

class CanvasScreen extends StatefulWidget {
  final Project? project;
  final Size? initialCanvasSize;

  const CanvasScreen({super.key, this.project, this.initialCanvasSize});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _ActivePointer {
  Offset position;
  final PointerDeviceKind kind;
  _ActivePointer(this.position, this.kind);
}

class _CanvasScreenState extends State<CanvasScreen>
    with SingleTickerProviderStateMixin {
  late CanvasController _controller;
  void Function()? _removeControllerListener;
  ui.FragmentShader? _glitterShader;
  ui.FragmentShader? _rainbowShader;
  late AnimationController _ticker;
  double _shaderTime = 0.0;
  bool _isInitialized = false;

  Offset _canvasTranslation = Offset.zero;
  double _canvasScale = 1.0;
  bool _userAdjustedView = false;
  Size _lastViewportSize = Size.zero;
  bool _isToolbarCollapsed = false;
  bool _fillScreenMode = true;

  final Map<int, _ActivePointer> _pointers = {};
  int? _drawingPointerId;
  bool _isTransformGesture = false;
  Offset? _lastFocal;
  double? _lastSpan;

  final ImagePicker _picker = ImagePicker();

  final List<Color> _palette = const [
    Color(0xFFFF69B4), // Pink
    Color(0xFF8E44AD), // Purple
    Color(0xFF00E5FF), // Cyan
    Color(0xFFFFD700), // Gold
    Color(0xFF2ECC71), // Mint
    Color(0xFFFF5722), // Orange
    Color(0xFF3498DB), // Sky Blue
    Color(0xFFE91E63), // Rose
    Colors.white,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _loadShaders();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        setState(() {
          _shaderTime += 0.016;
        });
      });
    _ticker.repeat();
    _initController();
  }

  Future<void> _initController() async {
    final controller = await CanvasController.create(
      widget.project,
      initialCanvasSize: widget.initialCanvasSize,
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    _controller = controller;
    _removeControllerListener = _controller.addListener(
      (_) {
        if (mounted) setState(() {});
      },
      fireImmediately: false,
    );
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _loadShaders() async {
    try {
      final glitterProgram = await ui.FragmentProgram.fromAsset('shaders/glitter.frag');
      final rainbowProgram = await ui.FragmentProgram.fromAsset('shaders/rainbow.frag');
      if (mounted) {
        setState(() {
          _glitterShader = glitterProgram.fragmentShader();
          _rainbowShader = rainbowProgram.fragmentShader();
        });
      }
    } catch (e) {
      debugPrint('Error cargando shaders: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (_isInitialized) {
      _removeControllerListener?.call();
      _controller.dispose();
    }
    super.dispose();
  }

  ui.FragmentShader? _getShaderForBrush(Brush brush) {
    if (brush.id == 'glitter_shader') return _glitterShader;
    if (brush.id == 'rainbow_shader') return _rainbowShader;
    return null;
  }

  void _fitCanvasToViewport(Size viewportSize, {bool? fill}) {
    if (viewportSize.width <= 1 || viewportSize.height <= 1) return;
    _lastViewportSize = viewportSize;

    final canvasSize = _controller.currentState.project.canvasSize;
    final shouldFill = fill ?? _fillScreenMode;

    final scaleX = viewportSize.width / canvasSize.width;
    final scaleY = viewportSize.height / canvasSize.height;

    // Si llenamos pantalla tomamos max (cubre 100% sin barras), sino min (ajusta todo visible)
    final fitScale = (shouldFill ? math.max(scaleX, scaleY) : math.min(scaleX, scaleY))
        .clamp(0.05, 10.0)
        .toDouble();

    final scaledWidth = canvasSize.width * fitScale;
    final scaledHeight = canvasSize.height * fitScale;

    final fitTranslation = Offset(
      (viewportSize.width - scaledWidth) / 2,
      (viewportSize.height - scaledHeight) / 2,
    );

    _canvasScale = fitScale;
    _canvasTranslation = fitTranslation;
  }

  bool _isStylus(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.stylus || kind == PointerDeviceKind.invertedStylus;

  List<Offset> get _touchPositions => _pointers.values
      .where((p) => p.kind == PointerDeviceKind.touch)
      .map((p) => p.position)
      .toList();

  Offset _viewportToCanvas(Offset viewportPos) {
    return (viewportPos - _canvasTranslation) / _canvasScale;
  }

  Offset _canvasToViewport(Offset canvasPos) {
    return canvasPos * _canvasScale + _canvasTranslation;
  }

  double _normalizedPressure(PointerEvent event) {
    final range = event.pressureMax - event.pressureMin;
    if (range <= 0) return 0.5;
    final normalized = (event.pressure - event.pressureMin) / range;
    return normalized.clamp(0.0, 1.0).toDouble();
  }

  void _startDraw(int pointerId, Offset localPosition, PointerEvent event) {
    _drawingPointerId = pointerId;
    final canvasPos = _viewportToCanvas(localPosition);
    final pressure = _normalizedPressure(event);
    _controller.startStroke(canvasPos, pressure, event.tilt);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = _ActivePointer(event.localPosition, event.kind);

    if (_isStylus(event.kind)) {
      if (_drawingPointerId == null) {
        _startDraw(event.pointer, event.localPosition, event);
      }
      return;
    }

    final stylusIsDrawing = _drawingPointerId != null &&
        _pointers[_drawingPointerId]?.kind != PointerDeviceKind.touch;
    if (stylusIsDrawing || _isTransformGesture) {
      return;
    }

    final touches = _touchPositions;
    if (_drawingPointerId != null && touches.length >= 2) {
      _controller.cancelStroke();
      _drawingPointerId = null;
      _beginTransformGesture();
    } else if (_drawingPointerId == null && touches.length == 1) {
      _startDraw(event.pointer, event.localPosition, event);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final tracked = _pointers[event.pointer];
    if (tracked == null) return;
    tracked.position = event.localPosition;

    if (_isTransformGesture) {
      _updateTransformGesture();
    } else if (_drawingPointerId == event.pointer) {
      final canvasPos = _viewportToCanvas(event.localPosition);
      final pressure = _normalizedPressure(event);
      _controller.updateStroke(canvasPos, pressure, event.tilt);
    }
  }

  void _onPointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);

    if (_drawingPointerId == event.pointer) {
      _drawingPointerId = null;
      _controller.endStroke(
        shader: _getShaderForBrush(_controller.currentState.activeBrush),
        time: _shaderTime,
      );
    }

    if (_isTransformGesture && _touchPositions.length < 2) {
      _isTransformGesture = false;
      _lastFocal = null;
      _lastSpan = null;
    }
  }

  void _beginTransformGesture() {
    final touches = _touchPositions;
    if (touches.length < 2) return;
    _isTransformGesture = true;
    _userAdjustedView = true;
    _lastFocal = (touches[0] + touches[1]) / 2.0;
    _lastSpan = (touches[0] - touches[1]).distance;
  }

  void _updateTransformGesture() {
    final touches = _touchPositions;
    if (touches.length < 2 || _lastFocal == null || _lastSpan == null) return;

    final focal = (touches[0] + touches[1]) / 2.0;
    final span = (touches[0] - touches[1]).distance;
    final focalDelta = focal - _lastFocal!;
    final scaleDelta = _lastSpan! > 0 ? span / _lastSpan! : 1.0;

    setState(() {
      final canvasFocalBefore = _viewportToCanvas(focal);
      _canvasScale = (_canvasScale * scaleDelta).clamp(0.05, 10.0).toDouble();
      final screenFocalAfter = _canvasToViewport(canvasFocalBefore);
      _canvasTranslation += focalDelta + (focal - screenFocalAfter);
    });

    _lastFocal = focal;
    _lastSpan = span;
  }

  void _openCelebrationExport() {
    final state = _controller.currentState;
    showDialog(
      context: context,
      builder: (ctx) => CelebrationExportDialog(
        hasTracingImage: state.tracingImage != null,
        onExport: (frame, includeTracing) => _executeExport(frame, includeTracing),
      ),
    );
  }

  Future<void> _executeExport(MuseumFrame frame, bool includeTracing) async {
    try {
      final state = _controller.currentState;
      final flattened = await LayerCompositor.flattenLayers(
        layers: state.project.layers,
        layerImages: state.layerImages,
        canvasSize: state.project.canvasSize,
        tracingImage: state.tracingImage,
        tracingOpacity: state.project.tracingOpacity,
        includeTracing: includeTracing,
        frame: frame,
        includeSignature: true,
      );

      final byteData = await flattened.toByteData(format: ui.ImageByteFormat.png);
      flattened.dispose();
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        await Gal.putImageBytes(
          bytes,
          name: 'kikidraw_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 ✨ ¡Obra de arte guardada en la galería con éxito! 👑🎨'),
              backgroundColor: Color(0xFFFF69B4),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  Future<void> _pickTracingImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        await _controller.setTracingImageFromFile(File(picked.path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📸 ¡Foto lista para calcar! Podés ajustar su transparencia'),
              backgroundColor: Color(0xFF8E44AD),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error seleccionando imagen: $e');
    }
  }

  void _showTracingSheet(CanvasState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF232336),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasPhoto = state.tracingImage != null;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📸 Calco Mágico (Papel Manteca)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (hasPhoto)
                          IconButton(
                            icon: Icon(
                              state.project.tracingVisible
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: const Color(0xFF00E5FF),
                            ),
                            tooltip: 'Ocultar / Mostrar Foto',
                            onPressed: () {
                              _controller.toggleTracingVisible();
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF69B4),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _pickTracingImage(ImageSource.camera);
                            },
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Sacar Foto 📷'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF00E5FF)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _pickTracingImage(ImageSource.gallery);
                            },
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Galería 🖼️'),
                          ),
                        ),
                      ],
                    ),
                    if (hasPhoto) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text(
                            'Transparencia:',
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                          Expanded(
                            child: Slider(
                              value: state.project.tracingOpacity,
                              min: 0.05,
                              max: 1.0,
                              activeColor: const Color(0xFFFF69B4),
                              onChanged: (val) {
                                _controller.setTracingOpacity(val);
                                setSheetState(() {});
                              },
                            ),
                          ),
                          Text(
                            '${(state.project.tracingOpacity * 100).toInt()}%',
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        onPressed: () {
                          _controller.removeTracingImage();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        label: const Text('Quitar foto de fondo'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSymmetryMenu() {
    final state = _controller.currentState;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF232336),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '❄️ Simetría Mágica / Caleidoscopio',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSymmetryTile(
                  title: 'Normal (1 Eje)',
                  subtitle: 'Dibujo libre tradicional',
                  icon: Icons.edit_rounded,
                  mode: SymmetryMode.none,
                  current: state.symmetryMode,
                ),
                _buildSymmetryTile(
                  title: 'Espejo Horizontal 🪞',
                  subtitle: 'Dibuja mariposas y caras simétricas',
                  icon: Icons.flip_rounded,
                  mode: SymmetryMode.horizontalMirror,
                  current: state.symmetryMode,
                ),
                _buildSymmetryTile(
                  title: 'Cruz Mágica (4 Ejes) ➕',
                  subtitle: 'Flores y estrellas perfectas',
                  icon: Icons.add_circle_outline_rounded,
                  mode: SymmetryMode.fourWay,
                  current: state.symmetryMode,
                ),
                _buildSymmetryTile(
                  title: 'Caleidoscopio (8 Ejes) ❄️',
                  subtitle: 'Mandalas y copos de nieve alucinantes',
                  icon: Icons.ac_unit_rounded,
                  mode: SymmetryMode.kaleidoscope8,
                  current: state.symmetryMode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSymmetryTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required SymmetryMode mode,
    required SymmetryMode current,
  }) {
    final isSelected = mode == current;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFFFF69B4) : Colors.white70,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFFFF69B4) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.white54),
      ),
      trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFFFF69B4)) : null,
      onTap: () {
        _controller.setSymmetryMode(mode);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _saveProject() async {
    await _controller.saveProject();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💾 ¡Obra guardada!'),
          backgroundColor: Color(0xFF2ECC71),
        ),
      );
    }
  }

  void _showColorPickerDialog(CanvasState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elige tu color mágico 🌈'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: state.activeColor,
            onColorChanged: (col) => _controller.selectColor(col),
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('¡Listo!'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF69B4)),
        ),
      );
    }

    final state = _controller.currentState;
    final activeBrush = state.activeBrush;
    final canvasSize = state.project.canvasSize;

    return Scaffold(
      backgroundColor: const Color(0xFF161622),
      appBar: AppBar(
        backgroundColor: const Color(0xFF232336).withValues(alpha: 0.92),
        elevation: 0,
        title: Text(
          '👑 studio • ${state.project.name}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.camera_alt_rounded,
              color: state.tracingImage != null ? const Color(0xFFFF69B4) : Colors.white70,
            ),
            onPressed: () => _showTracingSheet(state),
            tooltip: 'Calco Mágico con Foto',
          ),
          IconButton(
            icon: Icon(
              Icons.ac_unit_rounded,
              color: state.symmetryMode != SymmetryMode.none
                  ? const Color(0xFF00E5FF)
                  : Colors.white70,
            ),
            onPressed: _showSymmetryMenu,
            tooltip: 'Simetría Mágica',
          ),
          IconButton(
            icon: Icon(
              _fillScreenMode ? Icons.fullscreen_rounded : Icons.fit_screen_rounded,
              color: const Color(0xFF00E5FF),
            ),
            onPressed: () {
              if (_lastViewportSize.width > 0) {
                setState(() {
                  _userAdjustedView = false;
                  _fillScreenMode = !_fillScreenMode;
                  _fitCanvasToViewport(_lastViewportSize, fill: _fillScreenMode);
                });
              }
            },
            tooltip: _fillScreenMode ? 'Llenar Pantalla Completa' : 'Ajustar Contenido',
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: state.canUndo ? () => _controller.undo() : null,
            tooltip: 'Deshacer',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: state.canRedo ? () => _controller.redo() : null,
            tooltip: 'Rehacer',
          ),
          IconButton(
            icon: state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            onPressed: state.isSaving ? null : _saveProject,
            tooltip: 'Guardar',
          ),
          IconButton(
            icon: const Icon(Icons.download_sharp, color: Color(0xFFFFD700)),
            onPressed: _openCelebrationExport,
            tooltip: 'Celebración y Guardar en Galería',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

                if (!_userAdjustedView || _lastViewportSize != viewportSize) {
                  _fitCanvasToViewport(viewportSize);
                }

                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerEnd,
                  onPointerCancel: _onPointerEnd,
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      final zoomFactor = pointerSignal.scrollDelta.dy < 0 ? 1.15 : 0.85;
                      final focal = pointerSignal.localPosition;
                      final canvasFocalBefore = _viewportToCanvas(focal);
                      final newScale = (_canvasScale * zoomFactor).clamp(0.05, 10.0).toDouble();
                      final screenFocalAfter = canvasFocalBefore * newScale + _canvasTranslation;
                      final translationDelta = focal - screenFocalAfter;

                      setState(() {
                        _canvasScale = newScale;
                        _canvasTranslation += translationDelta;
                        _userAdjustedView = true;
                      });
                    }
                  },
                  child: ClipRect(
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translate(_canvasTranslation.dx, _canvasTranslation.dy)
                        ..scale(_canvasScale),
                      child: OverflowBox(
                        minWidth: 0,
                        minHeight: 0,
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        alignment: Alignment.topLeft,
                        child: Container(
                          width: canvasSize.width,
                          height: canvasSize.height,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Foto de calco mágico de fondo
                              if (state.project.tracingVisible && state.tracingImage != null)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: state.project.tracingOpacity,
                                    child: RawImage(
                                      image: state.tracingImage,
                                      fit: BoxFit.contain,
                                      width: canvasSize.width,
                                      height: canvasSize.height,
                                    ),
                                  ),
                                ),
                              CustomPainterWidget(
                                painter: LayerPainter(
                                  layers: state.project.layers,
                                  layerImages: state.layerImages,
                                ),
                                size: canvasSize,
                              ),
                              if (state.currentStroke != null)
                                CustomPainterWidget(
                                  painter: ActiveStrokePainter(
                                    stroke: state.currentStroke!,
                                    brush: activeBrush,
                                    shader: _getShaderForBrush(activeBrush),
                                    time: _shaderTime,
                                    symmetryMode: state.symmetryMode,
                                  ),
                                  size: canvasSize,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Panel Flotante Inferior de Herramientas y Paleta (Colapsable y Glassmorphism)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: _isToolbarCollapsed ? null : 16,
            right: 16,
            bottom: 20,
            child: _isToolbarCollapsed
                ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _isToolbarCollapsed = false),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A3D).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFFF69B4).withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: state.activeColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.brush_rounded, color: Color(0xFFFF69B4), size: 20),
                            const SizedBox(width: 6),
                            const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70, size: 22),
                          ],
                        ),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF232336).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFF69B4).withValues(alpha: 0.35)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Encabezado de la barra con botón para minimizar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '🎨 Pinceles & Colores',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _isToolbarCollapsed = true),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  children: [
                                    Text(
                                      'Ocultar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Paleta de Colores
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              GestureDetector(
                                onTap: () => _showColorPickerDialog(state),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [
                                        Colors.red,
                                        Colors.yellow,
                                        Colors.green,
                                        Colors.blue,
                                        Colors.purple,
                                        Colors.red
                                      ],
                                    ),
                                  ),
                                  child: const Icon(Icons.colorize, size: 18, color: Colors.white),
                                ),
                              ),
                              ..._palette.map((color) {
                                final isSelected = state.activeColor == color;
                                return GestureDetector(
                                  onTap: () => _controller.selectColor(color),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.white24,
                                        width: isSelected ? 3 : 1,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Barra de Pinceles
                        SizedBox(
                          height: 42,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: BrushLibrary.defaultBrushes.map((b) {
                              final isSelected = activeBrush.id == b.id;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Text(
                                    b.name,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFFFF69B4),
                                  backgroundColor: const Color(0xFF1E1E2C),
                                  onSelected: (_) => _controller.selectBrush(b),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // Ajuste de tamaño de pincel
                        Row(
                          children: [
                            const Icon(Icons.circle, size: 8, color: Colors.white70),
                            Expanded(
                              child: Slider(
                                value: activeBrush.size,
                                min: 2.0,
                                max: 60.0,
                                activeColor: const Color(0xFFFF69B4),
                                onChanged: (val) => _controller.setBrushSize(val),
                              ),
                            ),
                            const Icon(Icons.circle, size: 20, color: Colors.white70),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class CustomPainterWidget extends StatelessWidget {
  final CustomPainter painter;
  final Size size;

  const CustomPainterWidget({
    super.key,
    required this.painter,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: painter,
      size: size,
    );
  }
}
