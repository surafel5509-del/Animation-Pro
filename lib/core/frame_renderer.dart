import 'dart:math' as math;
import 'dart:ui' as ui;

import '../models/drawing_models.dart';

/// Shared renderer used by the live CustomPainter and export service.
class FrameRenderer {
  const FrameRenderer._();

  static void paintFrame(
    ui.Canvas canvas,
    ui.Size size,
    AnimationProject project,
    AnimationFrame frame, {
    bool paintBackground = true,
    bool mirror = false,
    ui.Color? tint,
    double tintOpacity = 1,
  }) {
    if (paintBackground) {
      canvas.drawColor(ui.Color(project.backgroundColor), ui.BlendMode.src);
    }

    for (final layer in project.layers) {
      if (!layer.visible) continue;
      final compositingPaint = ui.Paint()
        ..color = ui.Color.fromRGBO(
          255,
          255,
          255,
          layer.opacity.clamp(0, 1).toDouble(),
        )
        ..blendMode = _blendMode(layer.blendMode);
      canvas.saveLayer(ui.Offset.zero & size, compositingPaint);
      final strokes = frame.drawings[layer.id] ?? const <DrawingStroke>[];
      for (final stroke in strokes) {
        _paintStroke(
          canvas,
          size,
          project,
          stroke,
          tint,
          tintOpacity,
        );
        if (mirror) {
          canvas.save();
          canvas.translate(size.width, 0);
          canvas.scale(-1, 1);
          _paintStroke(
            canvas,
            size,
            project,
            stroke,
            tint,
            tintOpacity,
          );
          canvas.restore();
        }
      }
      canvas.restore();
    }
  }

  static void paintGrid(ui.Canvas canvas, ui.Size size, {int divisions = 8}) {
    final paint = ui.Paint()
      ..color = const ui.Color(0x1E665B8F)
      ..strokeWidth = 1;
    for (var index = 1; index < divisions; index++) {
      final dx = size.width * index / divisions;
      final dy = size.height * index / divisions;
      canvas.drawLine(ui.Offset(dx, 0), ui.Offset(dx, size.height), paint);
      canvas.drawLine(ui.Offset(0, dy), ui.Offset(size.width, dy), paint);
    }
    final border = ui.Paint()
      ..color = const ui.Color(0x406C5CE7)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(ui.Offset.zero & size, border);
  }

  static void _paintStroke(
    ui.Canvas canvas,
    ui.Size size,
    AnimationProject project,
    DrawingStroke stroke,
    ui.Color? tint,
    double tintOpacity,
  ) {
    if (stroke.points.isEmpty) return;
    final points = stroke.points
        .map((point) => ui.Offset(point.x * size.width, point.y * size.height))
        .toList(growable: false);
    final scale = (size.width / project.canvasWidth).abs();
    final double baseWidth = math.max(0.75, stroke.width * scale).toDouble();
    final sourceColor = tint ?? ui.Color(stroke.color);
    final opacity = (stroke.opacity * (tint == null ? 1 : tintOpacity))
        .clamp(0.0, 1.0)
        .toDouble();
    final color = tint == null
        ? sourceColor.withOpacity(sourceColor.opacity * opacity)
        : sourceColor.withOpacity(
            (sourceColor.opacity * opacity).clamp(0, 1).toDouble(),
          );

    final paint = ui.Paint()
      ..color = color
      ..style = stroke.filled ? ui.PaintingStyle.fill : ui.PaintingStyle.stroke
      ..strokeWidth = baseWidth
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..isAntiAlias = true;

    if (stroke.tool == DrawingTool.eraser) {
      paint
        ..blendMode = ui.BlendMode.clear
        ..color = const ui.Color(0xFFFFFFFF)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = baseWidth;
    } else if (stroke.tool == DrawingTool.marker) {
      paint.color = color.withOpacity(color.opacity * 0.34);
      paint.strokeWidth = baseWidth * 2.5;
    } else if (stroke.tool == DrawingTool.airbrush) {
      paint
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, baseWidth * 0.65)
        ..strokeWidth = baseWidth * 2.3;
    } else if (stroke.tool == DrawingTool.calligraphy) {
      paint.strokeWidth = baseWidth * 1.25;
    } else if (stroke.tool == DrawingTool.crayon) {
      paint.color = color.withOpacity(color.opacity * 0.78);
      paint.strokeWidth = baseWidth * 1.35;
    }

    if (stroke.tool == DrawingTool.ellipse ||
        stroke.tool == DrawingTool.rectangle ||
        stroke.tool == DrawingTool.line) {
      _paintShape(canvas, points, stroke, paint);
      return;
    }

    if (points.length == 1) {
      final pressure = stroke.points.first.pressure.clamp(0.12, 1.2).toDouble();
      final radius = baseWidth * pressure / 2;
      canvas.drawCircle(points.first, radius, paint..style = ui.PaintingStyle.fill);
      return;
    }

    for (var index = 0; index < points.length - 1; index++) {
      final pressure =
          ((stroke.points[index].pressure + stroke.points[index + 1].pressure) / 2)
              .clamp(0.12, 1.2)
              .toDouble();
      var segmentWidth = baseWidth * pressure;
      if (stroke.tool == DrawingTool.calligraphy) {
        final tilt = (stroke.points[index].orientation +
                stroke.points[index + 1].orientation) /
            2;
        segmentWidth *= 0.55 + math.sin(tilt).abs() * 0.75;
      }
      if (stroke.tool == DrawingTool.crayon) {
        segmentWidth *= 0.8 + ((index % 3) * 0.1);
      }
      final segmentPaint = ui.Paint()
        ..color = paint.color
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = segmentWidth
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round
        ..blendMode = paint.blendMode
        ..maskFilter = paint.maskFilter;
      canvas.drawLine(points[index], points[index + 1], segmentPaint);
    }
  }

  static void _paintShape(
    ui.Canvas canvas,
    List<ui.Offset> points,
    DrawingStroke stroke,
    ui.Paint paint,
  ) {
    final start = points.first;
    final end = points.length > 1 ? points.last : points.first;
    if (stroke.tool == DrawingTool.line) {
      canvas.drawLine(start, end, paint..style = ui.PaintingStyle.stroke);
      return;
    }
    final rect = ui.Rect.fromPoints(start, end);
    if (stroke.tool == DrawingTool.ellipse) {
      canvas.drawOval(rect, paint);
    } else if (stroke.filled) {
      canvas.drawRect(rect, paint);
    } else {
      canvas.drawRect(rect, paint..style = ui.PaintingStyle.stroke);
    }
  }

  static ui.BlendMode _blendMode(String mode) => switch (mode) {
        'multiply' => ui.BlendMode.multiply,
        'screen' => ui.BlendMode.screen,
        'overlay' => ui.BlendMode.overlay,
        'darken' => ui.BlendMode.darken,
        'lighten' => ui.BlendMode.lighten,
        'plus' => ui.BlendMode.plus,
        _ => ui.BlendMode.srcOver,
      };
}
