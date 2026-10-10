import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../controllers/editor_controller.dart';
import '../core/frame_renderer.dart';
import '../models/drawing_models.dart';

class AnimationCanvas extends StatelessWidget {
  const AnimationCanvas({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final canvasSize = constraints.biggest;
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (controller.isPlaying) return;
                controller.pointerDown(_pointFromEvent(event, canvasSize));
              },
              onPointerMove: (event) {
                controller.pointerMove(_pointFromEvent(event, canvasSize));
              },
              onPointerUp: (_) => controller.pointerUp(),
              onPointerCancel: (_) => controller.cancelPointer(),
              child: CustomPaint(
                painter: _AnimationPainter(controller),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      );

  StrokePoint _pointFromEvent(PointerEvent event, ui.Size size) {
    final pressure = switch (event.kind) {
      ui.PointerDeviceKind.stylus || ui.PointerDeviceKind.invertedStylus =>
        event.pressure.clamp(0.05, 1.0).toDouble(),
      _ => 1.0,
    };
    return StrokePoint(
      x: (event.localPosition.dx / size.width).clamp(0, 1).toDouble(),
      y: (event.localPosition.dy / size.height).clamp(0, 1).toDouble(),
      pressure: pressure,
      orientation: event.orientation,
    );
  }
}

class _AnimationPainter extends CustomPainter {
  _AnimationPainter(this.controller);

  final EditorController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final project = controller.project;
    canvas.drawColor(Color(project.backgroundColor), BlendMode.src);

    if (controller.onionSkin) {
      final previous = controller.previousFrame;
      if (previous != null) {
        FrameRenderer.paintFrame(
          canvas,
          size,
          project,
          previous,
          paintBackground: false,
          tint: const Color(0xFF30A99B),
          tintOpacity: 0.42,
        );
      }
      final next = controller.nextFrame;
      if (next != null) {
        FrameRenderer.paintFrame(
          canvas,
          size,
          project,
          next,
          paintBackground: false,
          tint: const Color(0xFFE5798E),
          tintOpacity: 0.28,
        );
      }
    }

    final visibleFrame = controller.currentFrame.duplicate();
    final draft = controller.draftStroke;
    if (draft != null) {
      visibleFrame.drawings
          .putIfAbsent(controller.activeLayerId, () => <DrawingStroke>[])
          .add(draft);
    }
    FrameRenderer.paintFrame(
      canvas,
      size,
      project,
      visibleFrame,
      paintBackground: false,
      mirror: controller.mirrorMode,
    );

    if (controller.mirrorMode) {
      final axisPaint = Paint()
        ..color = const Color(0x806C5CE7)
        ..strokeWidth = 1.25;
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        axisPaint,
      );
    }
    if (controller.showGrid) FrameRenderer.paintGrid(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _AnimationPainter oldDelegate) => true;
}
