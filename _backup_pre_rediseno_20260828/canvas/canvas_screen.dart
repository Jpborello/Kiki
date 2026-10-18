import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import '../../../core/models/project.dart';
import 'brushes/brush_library.dart';
import 'controllers/canvas_controller.dart';
import 'painters/active_stroke_painter.dart';
import 'painters/layer_painter.dart';

class CanvasScreen extends ConsumerStatefulWidget {
  final Project? project;

  const CanvasScreen({super.key, this.project});

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen>
    with SingleTickerProviderStateMixin {
  late CanvasController _controller;
  final TransformationController _transformationController = TransformationController();
  ui.FragmentShader? _glitterShader;
  ui.FragmentShader? _rainbowShader;
  late AnimationController _ticker;
  double _shaderTime = 0.0;
  bool _isInitialized = false;

  final List<Color> _palette = const [
    Color(0xFFFF69B4), // Pink
    Color(0xFF8E44AD), // Purple
    Color(0xFF00E5FF), // Cyan
    Color(0xFFFFD700), // Gold
    Color(0xFF2ECC71), // Mint
    Color(0xFFFF5722), // Orange
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
    _controller = await CanvasController.create(widget.project);
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
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
    _transformationController.dispose();
    super.dispose();
  }

  ui.FragmentShader? _getShaderForBrush(Brush brush) {
    if (brush.id == 'glitter_shader') return _glitterShader;
    if (brush.id == 'rainbow_shader') return _rainbowShader;
    return null;
  }

  Future<void> _exportToGallery(CanvasState state) async {
    try {
      final layerImg = state.layerImages[state.activeLayerId];
      if (layerImg == null) return;

      final byteData = await layerImg.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        await Gal.putImageBytes(bytes, name: 'kikidraw_${DateTime.now().millisecondsSinceEpoch}.png');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ ¡Tu dibujo guardado en la galería! 🎨'),
              backgroundColor: Color(0xFFFF69B4),
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

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A3D),
        title: Text('👑 studio • ${state.project.name}'),
        actions: [
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
            icon: const Icon(Icons.download_sharp, color: Color(0xFFFFD700)),
            onPressed: () => _exportToGallery(state),
            tooltip: 'Guardar en Galería',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Área del Canvas Interactivo
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.2,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(500),
              child: Center(
                child: Container(
                  width: state.project.canvasSize.width,
                  height: state.project.canvasSize.height,
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
                  child: Listener(
                    onPointerDown: (event) {
                      final pos = event.localPosition;
                      _controller.startStroke(pos, event.pressure, event.tilt);
                    },
                    onPointerMove: (event) {
                      final pos = event.localPosition;
                      _controller.updateStroke(pos, event.pressure, event.tilt);
                    },
                    onPointerUp: (event) {
                      _controller.endStroke(
                        shader: _getShaderForBrush(activeBrush),
                        time: _shaderTime,
                      );
                    },
                    child: Stack(
                      children: [
                        // Capas fijas horneadas
                        CustomPainterWidget(
                          painter: LayerPainter(
                            layers: state.project.layers,
                            layerImages: state.layerImages,
                          ),
                          size: state.project.canvasSize,
                        ),
                        // Trazo activo actual
                        if (state.currentStroke != null)
                          CustomPainterWidget(
                            painter: ActiveStrokePainter(
                              stroke: state.currentStroke!,
                              brush: activeBrush,
                              shader: _getShaderForBrush(activeBrush),
                              time: _shaderTime,
                            ),
                            size: state.project.canvasSize,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Panel Flotante Inferior de Herramientas y Paleta
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3D).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFF69B4).withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Paleta de Colores
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Selector cromático
                        GestureDetector(
                          onTap: () => _showColorPickerDialog(state),
                          child: Container(
                            width: 36,
                            height: 36,
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
                            child: const Icon(Icons.colorize, size: 20, color: Colors.white),
                          ),
                        ),
                        ..._palette.map((color) {
                          final isSelected = state.activeColor == color;
                          return GestureDetector(
                            onTap: () => _controller.selectColor(color),
                            child: Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Barra de Pinceles
                  SizedBox(
                    height: 48,
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
                      const Icon(Icons.circle, size: 10, color: Colors.white70),
                      Expanded(
                        child: Slider(
                          value: activeBrush.size,
                          min: 2.0,
                          max: 60.0,
                          activeColor: const Color(0xFFFF69B4),
                          onChanged: (val) {
                            _controller.setBrushSize(val);
                            setState(() {});
                          },
                        ),
                      ),
                      const Icon(Icons.circle, size: 24, color: Colors.white70),
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
