import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/models/museum_frame.dart';

class CelebrationExportDialog extends StatefulWidget {
  final bool hasTracingImage;
  final Function(MuseumFrame frame, bool includeTracing) onExport;

  const CelebrationExportDialog({
    super.key,
    required this.hasTracingImage,
    required this.onExport,
  });

  @override
  State<CelebrationExportDialog> createState() => _CelebrationExportDialogState();
}

class _CelebrationExportDialogState extends State<CelebrationExportDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  MuseumFrame _selectedFrame = MuseumFrame.gold;
  bool _includeTracing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Tarjeta principal
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 36),
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2A2A3D),
                  Color(0xFF1E1E2C),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF69B4).withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🎉 ¡Sos una gran artista! 🎉',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '¡Tu obra de arte de Kiara Zoe quedó mágica!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Selector de Marcos
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '🖼️ Elegí tu marco de museo:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFrameChip('Sin marco', MuseumFrame.none, Icons.crop_square_rounded),
                    _buildFrameChip('👑 Oro Real', MuseumFrame.gold, Icons.star_rounded),
                    _buildFrameChip('🌈 Arcoíris', MuseumFrame.rainbow, Icons.palette_rounded),
                    _buildFrameChip('🌸 Floral', MuseumFrame.flowers, Icons.local_florist_rounded),
                  ],
                ),

                if (widget.hasTracingImage) ...[
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '📸 Incluir foto de fondo',
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      ),
                      subtitle: Text(
                        _includeTracing ? 'Se guarda con la foto' : 'Solo tus trazos de artista ✨',
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      value: _includeTracing,
                      activeColor: const Color(0xFFFF69B4),
                      onChanged: (val) => setState(() => _includeTracing = val),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Seguir Pintando'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF69B4),
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onExport(_selectedFrame, _includeTracing);
                        },
                        icon: const Icon(Icons.download_done_rounded, size: 20),
                        label: const Text(
                          '¡Guardar!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Corona / Trofeo animado arriba
          Positioned(
            top: 0,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final bounce = math.sin(_animController.value * 2 * math.pi) * 4;
                return Transform.translate(
                  offset: Offset(0, bounce),
                  child: child,
                );
              },
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFE67E22),
                    ],
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                      blurRadius: 18,
                    )
                  ],
                ),
                child: const Center(
                  child: Text(
                    '👑',
                    style: TextStyle(fontSize: 36),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameChip(String label, MuseumFrame frame, IconData icon) {
    final isSelected = _selectedFrame == frame;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : const Color(0xFFFFD700),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFFF69B4),
      backgroundColor: const Color(0xFF1E1E2C),
      onSelected: (_) => setState(() => _selectedFrame = frame),
    );
  }
}
