import 'package:flutter/material.dart';

class StrokePoint {
  final Offset position;
  final double pressure; // 0.0 .. 1.0
  final double tilt;     // radians
  final int timestampMs;

  const StrokePoint({
    required this.position,
    this.pressure = 0.5,
    this.tilt = 0.0,
    required this.timestampMs,
  });

  Map<String, dynamic> toJson() => {
        'dx': position.dx,
        'dy': position.dy,
        'pressure': pressure,
        'tilt': tilt,
        'timestampMs': timestampMs,
      };

  factory StrokePoint.fromJson(Map<String, dynamic> json) {
    return StrokePoint(
      position: Offset(
        (json['dx'] as num).toDouble(),
        (json['dy'] as num).toDouble(),
      ),
      pressure: (json['pressure'] as num?)?.toDouble() ?? 0.5,
      tilt: (json['tilt'] as num?)?.toDouble() ?? 0.0,
      timestampMs: (json['timestampMs'] as num).toInt(),
    );
  }
}

class Stroke {
  final String id;
  final String brushId;
  final Color color;
  final List<StrokePoint> points;

  Stroke({
    required this.id,
    required this.brushId,
    required this.color,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'brushId': brushId,
        'color': color.toARGB32(),
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory Stroke.fromJson(Map<String, dynamic> json) {
    return Stroke(
      id: json['id'] as String,
      brushId: json['brushId'] as String,
      color: Color((json['color'] as num).toInt()),
      points: (json['points'] as List)
          .map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
