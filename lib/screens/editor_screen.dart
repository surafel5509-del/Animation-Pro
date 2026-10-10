import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/editor_controller.dart';
import '../models/drawing_models.dart';
import '../services/project_repository.dart';
import '../widgets/animation_canvas.dart';
import '../widgets/frame_timeline.dart';
import '../widgets/layer_panel.dart';
import 'export_screen.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.project,
    required this.repository,
  });

  final AnimationProject project;
  final ProjectRepository repository;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  late final EditorController _controller;
  Timer? _autosaveTimer;
  DateTime? _lastSaved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = EditorController(widget.project);
    WidgetsBinding.instance.addObserver(this);
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_saveProject());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      unawaited(_saveProject());
    }
  }

  Future<void> _saveProject({bool showFeedback = false}) async {
    if (_saving) return;
    _saving = true;
    try {
      await widget.repository.saveProject(_controller.project);
      _lastSaved = DateTime.now();
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project saved on this device.')),
        );
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save project: $error')),
        );
      }
    } finally {
      _saving = false;
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.repository.saveProject(_controller.project));
    _controller.dispose();
    super.dispose();
  }

  Future<void> _editProjectName() async {
    final textController = TextEditingController(text: _controller.project.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename animation'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 48,
          decoration: const InputDecoration(labelText: 'Project name'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (result != null) _controller.updateProjectName(result);
  }

  Future<void> _openExport() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExportScreen(project: _controller.project),
      ),
    );
  }

  void _openCompactInspector() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: _InspectorPanel(controller: _controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final hasInspector = width >= 980;
              final horizontalTools = width < 650;
              return Column(
                children: <Widget>[
                  _EditorHeader(
                    controller: _controller,
                    lastSaved: _lastSaved,
                    saving: _saving,
                    compact: width < 660,
                    onBack: () => Navigator.of(context).pop(),
                    onSave: () => _saveProject(showFeedback: true),
                    onEditName: _editProjectName,
                    onExport: _openExport,
                    onShowLayers: _openCompactInspector,
                  ),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        _ToolRail(
                          controller: _controller,
                          horizontal: horizontalTools,
                        ),
                        if (!horizontalTools)
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        Expanded(child: _EditorCenter(controller: _controller)),
                        if (hasInspector) ...<Widget>[
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          SizedBox(
                            width: 290,
                            child: _InspectorPanel(controller: _controller),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.controller,
    required this.lastSaved,
    required this.saving,
    required this.compact,
    required this.onBack,
    required this.onSave,
    required this.onEditName,
    required this.onExport,
    required this.onShowLayers,
  });

  final EditorController controller;
  final DateTime? lastSaved;
  final bool saving;
  final bool compact;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onEditName;
  final VoidCallback onExport;
  final VoidCallback onShowLayers;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final project = controller.project;
          final colors = Theme.of(context).colorScheme;
          final savedText = saving
              ? 'Saving…'
              : lastSaved == null
                  ? 'Autosaves every 30 sec'
                  : 'Saved on this device';
          return Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Back to projects',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                InkWell(
                  onTap: onEditName,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: compact ? 128 : 250),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (!compact)
                            Text(
                              '${project.canvasWidth} × ${project.canvasHeight}  ·  $savedText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Undo',
                  onPressed: controller.undoCount > 0 ? controller.undo : null,
                  icon: const Icon(Icons.undo_rounded),
                ),
                IconButton(
                  tooltip: 'Redo',
                  onPressed: controller.redoCount > 0 ? controller.redo : null,
                  icon: const Icon(Icons.redo_rounded),
                ),
                if (compact)
                  IconButton(
                    tooltip: 'Layers and brushes',
                    onPressed: onShowLayers,
                    icon: const Icon(Icons.layers_outlined),
                  )
                else
                  IconButton(
                    tooltip: 'Save now',
                    onPressed: onSave,
                    icon: Icon(
                      lastSaved == null
                          ? Icons.save_outlined
                          : Icons.cloud_done_outlined,
                    ),
                  ),
                if (!compact)
                  const SizedBox(width: 5),
                if (compact)
                  IconButton.filled(
                    tooltip: 'Export',
                    onPressed: onExport,
                    icon: const Icon(Icons.ios_share_rounded),
                  )
                else
                  FilledButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Export'),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          );
        },
      );
}

class _EditorCenter extends StatelessWidget {
  const _EditorCenter({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          _CanvasActions(controller: controller),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final aspect = controller.project.canvasWidth /
                      controller.project.canvasHeight;
                  final maxWidth = constraints.maxWidth * 0.92;
                  final maxHeight = constraints.maxHeight * 0.94;
                  final width = (maxWidth < maxHeight * aspect
                          ? maxWidth
                          : maxHeight * aspect)
                      .toDouble();
                  final height = width / aspect;
                  return Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(controller.project.backgroundColor),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRect(
                          child: AnimationCanvas(controller: controller),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 136, child: FrameTimeline(controller: controller)),
        ],
      );
}

class _CanvasActions extends StatelessWidget {
  const _CanvasActions({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          return SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: <Widget>[
                  Icon(Icons.crop_free_rounded, size: 16, color: colors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    '${controller.project.canvasWidth} × ${controller.project.canvasHeight}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  _ToggleToolButton(
                    icon: Icons.filter_frames_outlined,
                    label: 'Onion skin',
                    value: controller.onionSkin,
                    onPressed: controller.toggleOnionSkin,
                  ),
                  _ToggleToolButton(
                    icon: Icons.flip_rounded,
                    label: 'Mirror drawing',
                    value: controller.mirrorMode,
                    onPressed: controller.toggleMirrorMode,
                  ),
                  _ToggleToolButton(
                    icon: Icons.grid_on_rounded,
                    label: 'Grid',
                    value: controller.showGrid,
                    onPressed: controller.toggleGrid,
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _ToggleToolButton extends StatelessWidget {
  const _ToggleToolButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: value
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          foregroundColor: value
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        icon: Icon(icon, size: 19),
      );
}

class _ToolRail extends StatelessWidget {
  const _ToolRail({required this.controller, required this.horizontal});

  final EditorController controller;
  final bool horizontal;

  static const _tools = <DrawingTool>[
    DrawingTool.pencil,
    DrawingTool.pen,
    DrawingTool.marker,
    DrawingTool.airbrush,
    DrawingTool.calligraphy,
    DrawingTool.crayon,
    DrawingTool.eraser,
    DrawingTool.line,
    DrawingTool.rectangle,
    DrawingTool.ellipse,
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          if (horizontal) {
            return Container(
              height: 58,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(bottom: BorderSide(color: colors.outlineVariant)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 9),
                    for (final tool in _tools)
                      _ToolButton(
                        tool: tool,
                        selected: controller.tool == tool,
                        onPressed: () => controller.setTool(tool),
                      ),
                    const SizedBox(width: 9),
                  ],
                ),
              ),
            );
          }
          return Container(
            width: 64,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 8),
                for (final tool in _tools)
                  _ToolButton(
                    tool: tool,
                    selected: controller.tool == tool,
                    onPressed: () => controller.setTool(tool),
                  ),
                const Spacer(),
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Color(controller.color),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.outlineVariant, width: 2),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.onPressed,
  });

  final DrawingTool tool;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 7),
      child: Tooltip(
        message: _toolName(tool),
        child: Material(
          color: selected ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                _toolIcon(tool),
                size: 19,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _toolName(DrawingTool tool) => switch (tool) {
      DrawingTool.pencil => 'Pencil',
      DrawingTool.pen => 'Pen',
      DrawingTool.marker => 'Marker',
      DrawingTool.airbrush => 'Airbrush',
      DrawingTool.calligraphy => 'Calligraphy',
      DrawingTool.crayon => 'Crayon',
      DrawingTool.eraser => 'Eraser',
      DrawingTool.line => 'Line',
      DrawingTool.rectangle => 'Rectangle',
      DrawingTool.ellipse => 'Ellipse',
    };

IconData _toolIcon(DrawingTool tool) => switch (tool) {
      DrawingTool.pencil => Icons.edit_outlined,
      DrawingTool.pen => Icons.create_outlined,
      DrawingTool.marker => Icons.brush_outlined,
      DrawingTool.airbrush => Icons.blur_on_outlined,
      DrawingTool.calligraphy => Icons.draw_outlined,
      DrawingTool.crayon => Icons.color_lens_outlined,
      DrawingTool.eraser => Icons.auto_fix_off_outlined,
      DrawingTool.line => Icons.show_chart_rounded,
      DrawingTool.rectangle => Icons.crop_16_9_outlined,
      DrawingTool.ellipse => Icons.circle_outlined,
    };

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(
          children: <Widget>[
            const TabBar(
              tabs: <Widget>[
                Tab(text: 'Layers', icon: Icon(Icons.layers_outlined)),
                Tab(text: 'Brush', icon: Icon(Icons.brush_outlined)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  LayerPanel(controller: controller),
                  _BrushPanel(controller: controller),
                ],
              ),
            ),
          ],
        ),
      );
}

class _BrushPanel extends StatelessWidget {
  const _BrushPanel({required this.controller});

  final EditorController controller;

  static const _brushes = <DrawingTool>[
    DrawingTool.pencil,
    DrawingTool.pen,
    DrawingTool.marker,
    DrawingTool.airbrush,
    DrawingTool.calligraphy,
    DrawingTool.crayon,
    DrawingTool.eraser,
  ];
  static const _palette = <int>[
    0xFF252336,
    0xFF6C5CE7,
    0xFF00B894,
    0xFFFDCB6E,
    0xFFFF6B75,
    0xFF3685F4,
    0xFF7AAB5B,
    0xFFFFFFFF,
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              Text(
                'Brush type',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _brushes.map((tool) {
                  final selected = controller.tool == tool;
                  return Tooltip(
                    message: _toolName(tool),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => controller.setTool(tool),
                      child: Container(
                        width: 48,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected ? colors.primaryContainer : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: selected ? colors.primary : colors.outlineVariant,
                          ),
                        ),
                        child: Icon(
                          _toolIcon(tool),
                          size: 20,
                          color: selected ? colors.primary : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  const Expanded(child: Text('Size')),
                  Text('${controller.brushSize.round()} px'),
                ],
              ),
              Slider(
                value: controller.brushSize,
                min: 1,
                max: 80,
                onChanged: controller.setBrushSize,
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Color',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _chooseCustomColor(context),
                    icon: const Icon(Icons.colorize_rounded, size: 16),
                    label: const Text('Custom'),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _palette.map((value) {
                  final selected = controller.color == value;
                  return InkWell(
                    onTap: () => controller.setColor(value),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? colors.primary : colors.outlineVariant,
                          width: selected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text(
                'Stylus pressure is used where the device provides it.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ],
          );
        },
      );

  Future<void> _chooseCustomColor(BuildContext context) async {
    final value = controller.color.toRadixString(16).padLeft(8, '0').substring(2);
    final input = TextEditingController(text: '#$value');
    final colorValue = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom color'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 7,
          decoration: const InputDecoration(
            labelText: 'Hex color',
            hintText: '#6C5CE7',
          ),
          onSubmitted: (text) => Navigator.of(context).pop(_parseColor(text)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_parseColor(input.text)),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    input.dispose();
    if (colorValue != null) controller.setColor(colorValue);
  }

  int? _parseColor(String text) {
    final hex = text.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return 0xFF000000 | int.parse(hex, radix: 16);
  }
}
