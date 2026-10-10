import 'dart:math' as math;

String makeId([String prefix = 'id']) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 20)}';

enum DrawingTool {
  pencil,
  pen,
  marker,
  airbrush,
  calligraphy,
  crayon,
  eraser,
  line,
  rectangle,
  ellipse,
}

class StrokePoint {
  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 1,
    this.orientation = 0,
  });

  final double x;
  final double y;
  final double pressure;
  final double orientation;

  Map<String, Object?> toJson() => <String, Object?>{
        'x': x,
        'y': y,
        'pressure': pressure,
        'orientation': orientation,
      };

  factory StrokePoint.fromJson(Map<String, dynamic> json) => StrokePoint(
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        pressure: (json['pressure'] as num?)?.toDouble() ?? 1,
        orientation: (json['orientation'] as num?)?.toDouble() ?? 0,
      );
}

class DrawingStroke {
  DrawingStroke({
    String? id,
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    this.opacity = 1,
    this.filled = false,
  }) : id = id ?? makeId('stroke');

  final String id;
  final DrawingTool tool;
  final int color;
  final double width;
  final double opacity;
  final bool filled;
  final List<StrokePoint> points;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'tool': tool.name,
        'color': color,
        'width': width,
        'opacity': opacity,
        'filled': filled,
        'points': points.map((point) => point.toJson()).toList(),
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    final toolName = json['tool'] as String? ?? DrawingTool.pencil.name;
    final tool = DrawingTool.values.firstWhere(
      (item) => item.name == toolName,
      orElse: () => DrawingTool.pencil,
    );
    return DrawingStroke(
      id: json['id'] as String?,
      tool: tool,
      color: (json['color'] as num?)?.toInt() ?? 0xFF222222,
      width: (json['width'] as num?)?.toDouble() ?? 4,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
      filled: json['filled'] as bool? ?? false,
      points: ((json['points'] as List<dynamic>?) ?? const <dynamic>[])
          .map((item) => StrokePoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AnimationLayer {
  AnimationLayer({
    String? id,
    required this.name,
    this.visible = true,
    this.locked = false,
    this.opacity = 1,
    this.blendMode = 'normal',
  }) : id = id ?? makeId('layer');

  final String id;
  String name;
  bool visible;
  bool locked;
  double opacity;
  String blendMode;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'visible': visible,
        'locked': locked,
        'opacity': opacity,
        'blendMode': blendMode,
      };

  factory AnimationLayer.fromJson(Map<String, dynamic> json) => AnimationLayer(
        id: json['id'] as String?,
        name: json['name'] as String? ?? 'Layer',
        visible: json['visible'] as bool? ?? true,
        locked: json['locked'] as bool? ?? false,
        opacity: ((json['opacity'] as num?)?.toDouble() ?? 1).clamp(0, 1).toDouble(),
        blendMode: const <String>[
                  'normal',
                  'multiply',
                  'screen',
                  'overlay',
                  'darken',
                  'lighten',
                  'plus',
                ].contains(json['blendMode'])
            ? json['blendMode'] as String
            : 'normal',
      );
}

class AnimationFrame {
  AnimationFrame({
    String? id,
    this.holdFrames = 1,
    Map<String, List<DrawingStroke>>? drawings,
  })  : id = id ?? makeId('frame'),
        drawings = drawings ?? <String, List<DrawingStroke>>{};

  final String id;
  int holdFrames;
  final Map<String, List<DrawingStroke>> drawings;

  AnimationFrame duplicate() => AnimationFrame(
        holdFrames: holdFrames,
        drawings: drawings.map(
          (layerId, strokes) => MapEntry(
            layerId,
            strokes
                .map((stroke) => DrawingStroke.fromJson(stroke.toJson()))
                .toList(),
          ),
        ),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'holdFrames': holdFrames,
        'drawings': drawings.map(
          (layerId, strokes) => MapEntry(
            layerId,
            strokes.map((stroke) => stroke.toJson()).toList(),
          ),
        ),
      };

  factory AnimationFrame.fromJson(Map<String, dynamic> json) {
    final rawDrawings = json['drawings'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return AnimationFrame(
      id: json['id'] as String?,
      holdFrames: ((json['holdFrames'] as num?)?.toInt() ?? 1)
          .clamp(1, 60)
          .toInt(),
      drawings: rawDrawings.map((layerId, rawStrokes) {
        final strokes = (rawStrokes as List<dynamic>? ?? const <dynamic>[])
            .map((item) => DrawingStroke.fromJson(item as Map<String, dynamic>))
            .toList();
        return MapEntry(layerId, strokes);
      }),
    );
  }
}

class AnimationProject {
  AnimationProject({
    String? id,
    required this.name,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.fps,
    required this.backgroundColor,
    required this.layers,
    required this.frames,
    this.folder = 'My projects',
    this.tags = const <String>[],
    this.loop = true,
    this.audioPath,
    this.audioVolume = 1,
    this.audioMuted = false,
  }) : id = id ?? makeId('project');

  final String id;
  String name;
  int canvasWidth;
  int canvasHeight;
  int fps;
  int backgroundColor;
  final List<AnimationLayer> layers;
  final List<AnimationFrame> frames;
  String folder;
  List<String> tags;
  bool loop;
  String? audioPath;
  double audioVolume;
  bool audioMuted;

  static AnimationProject create({
    String name = 'Untitled animation',
    int width = 1080,
    int height = 1080,
  }) {
    final background = AnimationLayer(name: 'Background');
    final drawing = AnimationLayer(name: 'Drawing');
    return AnimationProject(
      name: name,
      canvasWidth: width,
      canvasHeight: height,
      fps: 12,
      backgroundColor: 0xFFFFFDF8,
      layers: <AnimationLayer>[background, drawing],
      frames: <AnimationFrame>[
        AnimationFrame(drawings: <String, List<DrawingStroke>>{
          background.id: <DrawingStroke>[],
          drawing.id: <DrawingStroke>[],
        }),
      ],
    );
  }

  /// A small editable sample project used to make the first project list useful.
  static AnimationProject sample() {
    final ground = AnimationLayer(name: 'Ground');
    final shadow = AnimationLayer(name: 'Soft shadow');
    final ball = AnimationLayer(name: 'Little ball');
    final project = AnimationProject(
      name: 'A little bounce',
      canvasWidth: 1080,
      canvasHeight: 1080,
      fps: 12,
      backgroundColor: 0xFFFFF9F0,
      layers: <AnimationLayer>[ground, shadow, ball],
      frames: <AnimationFrame>[],
      folder: 'Getting started',
      tags: <String>['sample', 'animation'],
    );

    for (var index = 0; index < 8; index++) {
      final phase = index / 7;
      final bounce = math.sin(phase * math.pi);
      final radiusX = 148 + (1 - bounce) * 15;
      final radiusY = 148 - (1 - bounce) * 18;
      final centerY = 590 - bounce * 220;
      final shadowWidth = 105 + (1 - bounce) * 65;
      final frame = AnimationFrame(drawings: <String, List<DrawingStroke>>{
        ground.id: <DrawingStroke>[
          DrawingStroke(
            tool: DrawingTool.line,
            color: 0xFFB9A899,
            width: 7,
            points: const <StrokePoint>[
              StrokePoint(x: 0.12, y: 0.79),
              StrokePoint(x: 0.88, y: 0.79),
            ],
          ),
        ],
        shadow.id: <DrawingStroke>[
          DrawingStroke(
            tool: DrawingTool.ellipse,
            color: 0x243E315F,
            width: 1,
            filled: true,
            points: <StrokePoint>[
              StrokePoint(x: (540 - shadowWidth) / 1080, y: 810 / 1080),
              StrokePoint(x: (540 + shadowWidth) / 1080, y: 855 / 1080),
            ],
          ),
        ],
        ball.id: <DrawingStroke>[
          DrawingStroke(
            tool: DrawingTool.ellipse,
            color: 0xFF6C5CE7,
            width: 8,
            filled: true,
            points: <StrokePoint>[
              StrokePoint(x: (540 - radiusX) / 1080, y: (centerY - radiusY) / 1080),
              StrokePoint(x: (540 + radiusX) / 1080, y: (centerY + radiusY) / 1080),
            ],
          ),
          DrawingStroke(
            tool: DrawingTool.ellipse,
            color: 0x66FFFFFF,
            width: 1,
            filled: true,
            points: <StrokePoint>[
              StrokePoint(x: 485 / 1080, y: (centerY - radiusY * 0.55) / 1080),
              StrokePoint(x: 525 / 1080, y: (centerY - radiusY * 0.25) / 1080),
            ],
          ),
        ],
      });
      project.frames.add(frame);
    }
    return project;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': 1,
        'id': id,
        'name': name,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'fps': fps,
        'backgroundColor': backgroundColor,
        'folder': folder,
        'tags': tags,
        'loop': loop,
        'audioPath': audioPath,
        'audioVolume': audioVolume,
        'audioMuted': audioMuted,
        'layers': layers.map((layer) => layer.toJson()).toList(),
        'frames': frames.map((frame) => frame.toJson()).toList(),
      };

  factory AnimationProject.fromJson(Map<String, dynamic> json) {
    final rawWidth = (json['canvasWidth'] as num?)?.toInt() ?? 1080;
    final rawHeight = (json['canvasHeight'] as num?)?.toInt() ?? 1080;
    final rawFps = (json['fps'] as num?)?.toInt() ?? 12;
    final rawLayers = json['layers'] as List<dynamic>? ?? const <dynamic>[];
    final rawFrames = json['frames'] as List<dynamic>? ?? const <dynamic>[];
    final layers = rawLayers
        .map((item) => AnimationLayer.fromJson(item as Map<String, dynamic>))
        .toList();
    final frames = rawFrames
        .map((item) => AnimationFrame.fromJson(item as Map<String, dynamic>))
        .toList();
    if (layers.isEmpty) {
      layers.add(AnimationLayer(name: 'Drawing'));
    }
    if (frames.isEmpty) {
      frames.add(AnimationFrame());
    }
    return AnimationProject(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Untitled animation',
      canvasWidth: rawWidth.clamp(1, 4096).toInt(),
      canvasHeight: rawHeight.clamp(1, 4096).toInt(),
      fps: const <int>[6, 8, 12, 15, 24, 30, 60].contains(rawFps) ? rawFps : 12,
      backgroundColor: (json['backgroundColor'] as num?)?.toInt() ?? 0xFFFFFDF8,
      folder: json['folder'] as String? ?? 'My projects',
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      loop: json['loop'] as bool? ?? true,
      audioPath: json['audioPath'] as String?,
      audioVolume: (json['audioVolume'] as num?)?.toDouble() ?? 1,
      audioMuted: json['audioMuted'] as bool? ?? false,
      layers: layers,
      frames: frames,
    );
  }
}
