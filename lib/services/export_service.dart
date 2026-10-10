import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../core/frame_renderer.dart';
import '../models/drawing_models.dart';

class ExportService {
  const ExportService._();

  static Future<Directory> _exportDirectory(String projectId) async {
    final documents = await getApplicationDocumentsDirectory();
    final safeId = projectId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final directory = Directory('${documents.path}/AnimPro/exports/$safeId');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  /// Renders one PNG for each authored timeline frame.
  static Future<List<File>> exportPngSequence(
    AnimationProject project, {
    bool transparentBackground = false,
    int? outputWidth,
    int? outputHeight,
  }) async {
    final directory = await _exportDirectory(project.id);
    final files = <File>[];
    for (var index = 0; index < project.frames.length; index++) {
      final bytes = await _renderPng(
        project,
        project.frames[index],
        transparentBackground: transparentBackground,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
      );
      final file = File('${directory.path}/frame_${(index + 1).toString().padLeft(4, '0')}.png');
      await file.writeAsBytes(bytes, flush: true);
      files.add(file);
    }
    return files;
  }

  /// Exports a looping GIF. Each frame duration includes its hold-frame count.
  static Future<File> exportGif(
    AnimationProject project, {
    bool transparentBackground = false,
    int? fps,
    int? outputWidth,
    int? outputHeight,
  }) async {
    final encoder = img.GifEncoder(repeat: project.loop ? 0 : -1);
    for (final frame in project.frames) {
      final pngBytes = await _renderPng(
        project,
        frame,
        transparentBackground: transparentBackground,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
      );
      final decoded = img.decodePng(pngBytes);
      if (decoded == null) throw StateError('Could not decode a rendered frame.');
      final duration = ((1000 / (fps ?? project.fps)) * frame.holdFrames).round();
      encoder.addFrame(decoded, duration: duration);
    }
    final encoded = encoder.finish();
    if (encoded == null) throw StateError('GIF encoding returned no data.');
    final directory = await _exportDirectory(project.id);
    final file = File('${directory.path}/${_safeFileName(project.name)}.gif');
    await file.writeAsBytes(encoded, flush: true);
    return file;
  }

  static Future<Uint8List> _renderPng(
    AnimationProject project,
    AnimationFrame frame, {
    required bool transparentBackground,
    int? outputWidth,
    int? outputHeight,
  }) async {
    final width = outputWidth ?? project.canvasWidth;
    final height = outputHeight ?? project.canvasHeight;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    FrameRenderer.paintFrame(
      canvas,
      ui.Size(width.toDouble(), height.toDouble()),
      project,
      frame,
      paintBackground: !transparentBackground,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (byteData == null) throw StateError('PNG encoding returned no data.');
    return byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
  }

  static String _safeFileName(String name) {
    final safe = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return safe.isEmpty ? 'animation' : safe;
  }
}
