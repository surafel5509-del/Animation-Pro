import 'package:animpro/controllers/editor_controller.dart';
import 'package:animpro/models/drawing_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EditorController', () {
    late AnimationProject project;
    late EditorController controller;

    setUp(() {
      project = AnimationProject.create();
      controller = EditorController(project);
    });

    tearDown(() => controller.dispose());

    test('adds, duplicates, and removes frames without removing the last one', () {
      controller.addFrame();
      expect(controller.project.frames, hasLength(2));
      controller.duplicateFrame(0);
      expect(controller.project.frames, hasLength(3));
      controller.deleteFrame(2);
      controller.deleteFrame(1);
      controller.deleteFrame(0);
      expect(controller.project.frames, hasLength(1));
    });

    test('records a stroke and supports undo and redo', () {
      controller.pointerDown(const StrokePoint(x: 0.1, y: 0.2));
      controller.pointerMove(const StrokePoint(x: 0.3, y: 0.4, pressure: 0.7));
      controller.pointerUp();

      final layerId = controller.activeLayerId;
      expect(controller.currentFrame.drawings[layerId], hasLength(1));
      controller.undo();
      expect(controller.currentFrame.drawings[layerId], isEmpty);
      controller.redo();
      expect(controller.currentFrame.drawings[layerId], hasLength(1));
    });

    test('layer visibility, locking, and frame reordering are preserved in JSON', () {
      final layerId = controller.activeLayerId;
      controller.addLayer(name: 'Ink');
      final addedLayerId = controller.activeLayerId;
      controller.toggleLayerVisibility(layerId);
      controller.toggleLayerLock(addedLayerId);
      controller.addFrame();
      controller.reorderFrame(1, 0);

      final restored = AnimationProject.fromJson(controller.project.toJson());
      expect(restored.frames, hasLength(2));
      expect(restored.layers.firstWhere((layer) => layer.id == layerId).visible, isFalse);
      expect(restored.layers.firstWhere((layer) => layer.id == addedLayerId).locked, isTrue);
    });

    test('sample project contains editable frame-by-frame artwork', () {
      final sample = AnimationProject.sample();
      expect(sample.frames, hasLength(8));
      expect(sample.layers, hasLength(3));
      expect(sample.frames.every((frame) => frame.drawings.isNotEmpty), isTrue);
    });
  });
}
