import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/drawing_models.dart';
import '../services/export_service.dart';

enum _ExportFormat { gif, pngSequence }

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.project});

  final AnimationProject project;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  _ExportFormat _format = _ExportFormat.gif;
  int _resolution = 1080;
  late int _fps = widget.project.fps;
  bool _transparent = false;
  bool _exporting = false;
  List<File> _files = <File>[];
  String? _error;

  (int, int) get _outputSize {
    final aspect = widget.project.canvasWidth / widget.project.canvasHeight;
    if (aspect >= 1) {
      return ((_resolution * aspect).round().clamp(1, 4096).toInt(), _resolution);
    }
    return (_resolution, (_resolution / aspect).round().clamp(1, 4096).toInt());
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _files = <File>[];
      _error = null;
    });
    try {
      final (width, height) = _outputSize;
      final files = switch (_format) {
        _ExportFormat.gif => <File>[
            await ExportService.exportGif(
              widget.project,
              transparentBackground: _transparent,
              fps: _fps,
              outputWidth: width,
              outputHeight: height,
            ),
          ],
        _ExportFormat.pngSequence => await ExportService.exportPngSequence(
            widget.project,
            transparentBackground: _transparent,
            outputWidth: width,
            outputHeight: height,
          ),
      };
      if (mounted) setState(() => _files = files);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _share() async {
    if (_files.isEmpty) return;
    await Share.shareXFiles(
      _files.map((file) => XFile(file.path)).toList(),
      text: 'Created with AnimPro',
      subject: widget.project.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (width, height) = _outputSize;
    return Scaffold(
      appBar: AppBar(title: const Text('Export animation')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: <Widget>[
              Text(
                widget.project.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                '${widget.project.frames.length} frames  ·  ${widget.project.canvasWidth} × ${widget.project.canvasHeight}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                'Format',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<_ExportFormat>(
                segments: const <ButtonSegment<_ExportFormat>>[
                  ButtonSegment<_ExportFormat>(
                    value: _ExportFormat.gif,
                    icon: Icon(Icons.movie_creation_outlined),
                    label: Text('GIF'),
                  ),
                  ButtonSegment<_ExportFormat>(
                    value: _ExportFormat.pngSequence,
                    icon: Icon(Icons.photo_library_outlined),
                    label: Text('PNG sequence'),
                  ),
                ],
                selected: <_ExportFormat>{_format},
                onSelectionChanged: (selected) => setState(() => _format = selected.first),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Video formats',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const Chip(label: Text('Not connected yet')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'MP4 and WebM need a native Android/iOS media encoder. This starter does not bundle a retired FFmpeg package. See the export guide for a safe implementation path.',
                        style: TextStyle(height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Output settings',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Resolution'),
                        subtitle: Text('$width × $height px'),
                        trailing: DropdownButton<int>(
                          value: _resolution,
                          items: const <DropdownMenuItem<int>>[
                            DropdownMenuItem(value: 480, child: Text('480p')),
                            DropdownMenuItem(value: 720, child: Text('720p')),
                            DropdownMenuItem(value: 1080, child: Text('1080p')),
                            DropdownMenuItem(value: 2048, child: Text('2K')),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _resolution = value);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Frame rate'),
                        subtitle: Text(_format == _ExportFormat.gif
                            ? 'Used to calculate GIF timing'
                            : 'Stored as one image per authored frame'),
                        trailing: DropdownButton<int>(
                          value: _fps,
                          items: const <DropdownMenuItem<int>>[
                            DropdownMenuItem(value: 6, child: Text('6 fps')),
                            DropdownMenuItem(value: 8, child: Text('8 fps')),
                            DropdownMenuItem(value: 12, child: Text('12 fps')),
                            DropdownMenuItem(value: 15, child: Text('15 fps')),
                            DropdownMenuItem(value: 24, child: Text('24 fps')),
                            DropdownMenuItem(value: 30, child: Text('30 fps')),
                            DropdownMenuItem(value: 60, child: Text('60 fps')),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _fps = value);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Transparent background'),
                        subtitle: const Text('GIF transparency is limited by the format.'),
                        value: _transparent,
                        onChanged: (value) => setState(() => _transparent = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_exporting) ...<Widget>[
                const LinearProgressIndicator(),
                const SizedBox(height: 10),
                const Text('Rendering frames…', textAlign: TextAlign.center),
              ] else
                FilledButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(
                    _format == _ExportFormat.gif
                        ? 'Render GIF'
                        : 'Render PNG sequence',
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Export failed: $_error',
                  style: TextStyle(color: colors.error),
                ),
              ],
              if (_files.isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.check_circle_rounded, color: colors.secondary),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                _format == _ExportFormat.gif
                                    ? 'GIF is ready'
                                    : '${_files.length} PNG frames are ready',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _files.first.path,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text('Share or save…'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
