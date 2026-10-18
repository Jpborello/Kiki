import 'package:flutter/material.dart';
import 'layer.dart';

class Project {
  final String id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
  final Size canvasSize;
  String? thumbnailPath;
  String? tracingImagePath;
  double tracingOpacity;
  bool tracingVisible;
  List<Layer> layers;
  List<String> timelapseFramePaths;

  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.canvasSize = const Size(2048, 2048),
    this.thumbnailPath,
    this.tracingImagePath,
    this.tracingOpacity = 0.4,
    this.tracingVisible = true,
    required this.layers,
    this.timelapseFramePaths = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'canvasWidth': canvasSize.width,
        'canvasHeight': canvasSize.height,
        'thumbnailPath': thumbnailPath,
        'tracingImagePath': tracingImagePath,
        'tracingOpacity': tracingOpacity,
        'tracingVisible': tracingVisible,
        'layers': layers.map((l) => l.toJson()).toList(),
        'timelapseFramePaths': timelapseFramePaths,
      };

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      canvasSize: Size(
        (json['canvasWidth'] as num).toDouble(),
        (json['canvasHeight'] as num).toDouble(),
      ),
      thumbnailPath: json['thumbnailPath'] as String?,
      tracingImagePath: json['tracingImagePath'] as String?,
      tracingOpacity: (json['tracingOpacity'] as num?)?.toDouble() ?? 0.4,
      tracingVisible: json['tracingVisible'] as bool? ?? true,
      layers: (json['layers'] as List)
          .map((l) => Layer.fromJson(l as Map<String, dynamic>))
          .toList(),
      timelapseFramePaths: (json['timelapseFramePaths'] as List? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }
}
