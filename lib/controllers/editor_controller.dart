import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/drawing_models.dart';

class EditorController extends ChangeNotifier {
  EditorController(AnimationProject project)
      : _project = project,
        _activeLayerId = project.layers.isNotEmpty ? project.layers.last.id : '' {
    if (_project.layers.isEmpty) {
      _project.layers.add(AnimationLayer(name: 'Drawing'));
      _activeLayerId = _project.layers.first.id;
    }
    if (_project.frames.isEmpty) {
      _project.frames.add(AnimationFrame());
    }
  }

  AnimationProject _project;
  AnimationProject get project => _project;

  int _currentFrameIndex = 0;
  int get currentFrameIndex => _currentFrameIndex;
  AnimationFrame get currentFrame =>
      _project.frames[_currentFrameIndex.clamp(0, _project.frames.length - 1).toInt()];

  String _activeLayerId;
  String get activeLayerId => _activeLayerId;
  AnimationLayer get activeLayer => _project.layers.firstWhere(
        (layer) => layer.id == _activeLayerId,
        orElse: () => _project.layers.first,
      );

  DrawingTool _tool = DrawingTool.pencil;
  DrawingTool get tool => _tool;
  int _color = 0xFF252336;
  int get color => _color;
  double _brushSize = 7;
  double get brushSize => _brushSize;

  bool _onionSkin = true;
  bool get onionSkin => _onionSkin;
  bool _mirrorMode = false;
  bool get mirrorMode => _mirrorMode;
  bool _showGrid = false;
  bool get showGrid => _showGrid;
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  bool _reversePlayback = false;
  bool get reversePlayback => _reversePlayback;

  final List<String> _undoStack = <String>[];
  final List<String> _redoStack = <String>[];
  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  Timer? _playTimer;
  int _holdTick = 0;
  AnimationFrame? _clipboard;

  List<StrokePoint> _draftPoints = <StrokePoint>[];
  DrawingTool _draftTool = DrawingTool.pencil;
  int _draftColor = 0xFF252336;
  double _draftWidth = 7;
  DrawingStroke? get draftStroke => _draftPoints.isEmpty
      ? null
      : DrawingStroke(
          id: 'draft',
          tool: _draftTool,
          color: _draftColor,
          width: _draftWidth,
          points: List<StrokePoint>.unmodifiable(_draftPoints),
        );

  AnimationFrame? get previousFrame =>
      _currentFrameIndex > 0 ? _project.frames[_currentFrameIndex - 1] : null;
  AnimationFrame? get nextFrame => _currentFrameIndex < _project.frames.length - 1
      ? _project.frames[_currentFrameIndex + 1]
      : null;

  void setTool(DrawingTool value) {
    if (_tool == value) return;
    _tool = value;
    notifyListeners();
  }

  void setColor(int value) {
    _color = value;
    notifyListeners();
  }

  void setBrushSize(double value) {
    _brushSize = value.clamp(1, 80).toDouble();
    notifyListeners();
  }

  void toggleOnionSkin() {
    _onionSkin = !_onionSkin;
    notifyListeners();
  }

  void toggleMirrorMode() {
    _mirrorMode = !_mirrorMode;
    notifyListeners();
  }

  void toggleGrid() {
    _showGrid = !_showGrid;
    notifyListeners();
  }

  void selectFrame(int index) {
    if (index < 0 || index >= _project.frames.length) return;
    _currentFrameIndex = index;
    _holdTick = 0;
    notifyListeners();
  }

  void addFrame({bool duplicateCurrent = false}) {
    _checkpoint();
    final AnimationFrame frame;
    if (duplicateCurrent) {
      frame = currentFrame.duplicate();
    } else {
      frame = AnimationFrame(
        drawings: <String, List<DrawingStroke>>{
          for (final layer in _project.layers) layer.id: <DrawingStroke>[],
        },
      );
    }
    _project.frames.insert(_currentFrameIndex + 1, frame);
    _currentFrameIndex++;
    notifyListeners();
  }

  void duplicateFrame(int index) {
    if (index < 0 || index >= _project.frames.length) return;
    _checkpoint();
    _project.frames.insert(index + 1, _project.frames[index].duplicate());
    _currentFrameIndex = index + 1;
    notifyListeners();
  }

  void deleteFrame(int index) {
    if (_project.frames.length <= 1 ||
        index < 0 ||
        index >= _project.frames.length) {
      return;
    }
    _checkpoint();
    _project.frames.removeAt(index);
    if (_currentFrameIndex >= _project.frames.length) {
      _currentFrameIndex = _project.frames.length - 1;
    } else if (_currentFrameIndex > index) {
      _currentFrameIndex--;
    }
    notifyListeners();
  }

  void reorderFrame(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _project.frames.length ||
        newIndex < 0 ||
        newIndex >= _project.frames.length ||
        oldIndex == newIndex) {
      return;
    }
    _checkpoint();
    final currentId = currentFrame.id;
    final frame = _project.frames.removeAt(oldIndex);
    _project.frames.insert(newIndex, frame);
    _currentFrameIndex = _project.frames.indexWhere((item) => item.id == currentId);
    notifyListeners();
  }

  void setFrameHold(int value) {
    final hold = value.clamp(1, 60).toInt();
    if (currentFrame.holdFrames == hold) return;
    _checkpoint();
    currentFrame.holdFrames = hold;
    notifyListeners();
  }

  void toggleLoop() {
    _project.loop = !_project.loop;
    notifyListeners();
  }

  void setFps(int value) {
    const allowed = <int>[6, 8, 12, 15, 24, 30, 60];
    if (!allowed.contains(value) || _project.fps == value) return;
    _project.fps = value;
    if (_isPlaying) {
      final wasReverse = _reversePlayback;
      play(reverse: wasReverse);
    }
    notifyListeners();
  }

  void play({bool reverse = false}) {
    stopPlayback(notify: false);
    _reversePlayback = reverse;
    _isPlaying = true;
    _holdTick = 0;
    final intervalMs = math.max(1, (1000 / _project.fps).round()).toInt();
    _playTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (_project.frames.isEmpty) return;
      _holdTick++;
      if (_holdTick < currentFrame.holdFrames) {
        notifyListeners();
        return;
      }
      _holdTick = 0;
      final step = _reversePlayback ? -1 : 1;
      var nextIndex = _currentFrameIndex + step;
      if (nextIndex < 0 || nextIndex >= _project.frames.length) {
        if (_project.loop) {
          nextIndex = _reversePlayback ? _project.frames.length - 1 : 0;
        } else {
          stopPlayback();
          return;
        }
      }
      _currentFrameIndex = nextIndex;
      notifyListeners();
    });
    notifyListeners();
  }

  void stopPlayback({bool notify = true}) {
    _playTimer?.cancel();
    _playTimer = null;
    _isPlaying = false;
    _holdTick = 0;
    if (notify) notifyListeners();
  }

  void copyCurrentFrame() {
    _clipboard = currentFrame.duplicate();
  }

  void pasteFrame() {
    final copied = _clipboard;
    if (copied == null) return;
    _checkpoint();
    final frame = copied.duplicate();
    for (final layer in _project.layers) {
      frame.drawings.putIfAbsent(layer.id, () => <DrawingStroke>[]);
    }
    _project.frames[_currentFrameIndex] = frame;
    notifyListeners();
  }

  void clearCurrentLayer() {
    if (activeLayer.locked) return;
    _checkpoint();
    currentFrame.drawings[activeLayer.id] = <DrawingStroke>[];
    notifyListeners();
  }

  void addLayer({String? name}) {
    _checkpoint();
    final layer = AnimationLayer(
      name: name ?? 'Layer ${_project.layers.length}',
    );
    _project.layers.add(layer);
    for (final frame in _project.frames) {
      frame.drawings.putIfAbsent(layer.id, () => <DrawingStroke>[]);
    }
    _activeLayerId = layer.id;
    notifyListeners();
  }

  void deleteLayer(String layerId) {
    if (_project.layers.length <= 1) return;
    final index = _project.layers.indexWhere((layer) => layer.id == layerId);
    if (index < 0) return;
    _checkpoint();
    _project.layers.removeAt(index);
    for (final frame in _project.frames) {
      frame.drawings.remove(layerId);
    }
    if (_activeLayerId == layerId) {
      _activeLayerId = _project.layers.last.id;
    }
    notifyListeners();
  }

  void renameLayer(String layerId, String name) {
    final layer = _project.layers.firstWhere((item) => item.id == layerId);
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == layer.name) return;
    _checkpoint();
    layer.name = trimmed;
    notifyListeners();
  }

  void selectLayer(String layerId) {
    final layer = _project.layers.firstWhere(
      (item) => item.id == layerId,
      orElse: () => _project.layers.last,
    );
    if (layer.locked || !layer.visible) return;
    _activeLayerId = layer.id;
    notifyListeners();
  }

  void toggleLayerVisibility(String layerId) {
    final layer = _project.layers.firstWhere((item) => item.id == layerId);
    _checkpoint();
    layer.visible = !layer.visible;
    if (!layer.visible && _activeLayerId == layerId) {
      final available = _project.layers.where((item) => item.visible && !item.locked);
      if (available.isNotEmpty) _activeLayerId = available.last.id;
    }
    notifyListeners();
  }

  void toggleLayerLock(String layerId) {
    final layer = _project.layers.firstWhere((item) => item.id == layerId);
    _checkpoint();
    layer.locked = !layer.locked;
    if (layer.locked && _activeLayerId == layerId) {
      final available = _project.layers.where((item) => item.visible && !item.locked);
      if (available.isNotEmpty) _activeLayerId = available.last.id;
    }
    notifyListeners();
  }

  void startLayerOpacityChange() => _checkpoint();

  void setLayerOpacity(String layerId, double value) {
    final layer = _project.layers.firstWhere((item) => item.id == layerId);
    layer.opacity = value.clamp(0, 1).toDouble();
    notifyListeners();
  }

  void reorderLayer(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _project.layers.length ||
        newIndex < 0 ||
        newIndex >= _project.layers.length ||
        oldIndex == newIndex) {
      return;
    }
    _checkpoint();
    final layer = _project.layers.removeAt(oldIndex);
    _project.layers.insert(newIndex, layer);
    notifyListeners();
  }

  void setLayerOrder(List<String> ids) {
    if (ids.length != _project.layers.length) return;
    final byId = <String, AnimationLayer>{
      for (final layer in _project.layers) layer.id: layer,
    };
    if (ids.any((id) => !byId.containsKey(id))) return;
    _checkpoint();
    _project.layers
      ..clear()
      ..addAll(ids.map((id) => byId[id]!));
    notifyListeners();
  }

  void setLayerBlendMode(String layerId, String value) {
    final layer = _project.layers.firstWhere((item) => item.id == layerId);
    if (layer.blendMode == value) return;
    _checkpoint();
    layer.blendMode = value;
    notifyListeners();
  }

  void pointerDown(StrokePoint point) {
    if (activeLayer.locked || !activeLayer.visible) return;
    _draftTool = _tool;
    _draftColor = _color;
    _draftWidth = _brushSize;
    _draftPoints = <StrokePoint>[point];
    notifyListeners();
  }

  void pointerMove(StrokePoint point) {
    if (_draftPoints.isEmpty) return;
    final last = _draftPoints.last;
    if ((last.x - point.x).abs() + (last.y - point.y).abs() < 0.00025) {
      return;
    }
    _draftPoints.add(point);
    notifyListeners();
  }

  void pointerUp() {
    if (_draftPoints.isEmpty) return;
    final points = List<StrokePoint>.from(_draftPoints);
    if (_draftTool == DrawingTool.line ||
        _draftTool == DrawingTool.rectangle ||
        _draftTool == DrawingTool.ellipse) {
      final first = points.first;
      final last = points.last;
      points
        ..clear()
        ..add(first)
        ..add(last);
    }
    _draftPoints = <StrokePoint>[];
    _checkpoint();
    currentFrame.drawings.putIfAbsent(activeLayer.id, () => <DrawingStroke>[]).add(
          DrawingStroke(
            tool: _draftTool,
            color: _draftColor,
            width: _draftWidth,
            points: points,
          ),
        );
    notifyListeners();
  }

  void cancelPointer() {
    if (_draftPoints.isEmpty) return;
    _draftPoints = <StrokePoint>[];
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(jsonEncode(_project.toJson()));
    _restore(_undoStack.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(jsonEncode(_project.toJson()));
    _restore(_redoStack.removeLast());
    notifyListeners();
  }

  void updateProjectName(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && trimmed != _project.name) {
      _project.name = trimmed;
      notifyListeners();
    }
  }

  void _checkpoint() {
    _undoStack.add(jsonEncode(_project.toJson()));
    _redoStack.clear();
  }

  void _restore(String snapshot) {
    _project = AnimationProject.fromJson(jsonDecode(snapshot) as Map<String, dynamic>);
    _currentFrameIndex =
        _currentFrameIndex.clamp(0, _project.frames.length - 1).toInt();
    if (!_project.layers.any((layer) => layer.id == _activeLayerId)) {
      _activeLayerId = _project.layers.last.id;
    }
    _draftPoints = <StrokePoint>[];
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }
}
