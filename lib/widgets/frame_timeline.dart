import 'package:flutter/material.dart';

import '../controllers/editor_controller.dart';
import '../core/frame_renderer.dart';
import '../models/drawing_models.dart';

class FrameTimeline extends StatelessWidget {
  const FrameTimeline({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final project = controller.project;
          final current = controller.currentFrame;
          final colors = Theme.of(context).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 48,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: 10),
                        IconButton(
                          tooltip: 'Previous frame',
                          visualDensity: VisualDensity.compact,
                          onPressed: controller.currentFrameIndex > 0
                              ? () => controller.selectFrame(controller.currentFrameIndex - 1)
                              : null,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        IconButton.filledTonal(
                          tooltip: controller.isPlaying ? 'Pause' : 'Play',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => controller.isPlaying
                              ? controller.stopPlayback()
                              : controller.play(),
                          icon: Icon(
                            controller.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Play in reverse',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => controller.play(reverse: true),
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                        IconButton(
                          tooltip: project.loop ? 'Loop is on' : 'Loop is off',
                          visualDensity: VisualDensity.compact,
                          onPressed: controller.toggleLoop,
                          icon: Icon(
                            Icons.repeat_rounded,
                            color: project.loop ? colors.primary : colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'FPS',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(width: 4),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: project.fps,
                            borderRadius: BorderRadius.circular(12),
                            items: const <DropdownMenuItem<int>>[
                              DropdownMenuItem(value: 6, child: Text('6')),
                              DropdownMenuItem(value: 8, child: Text('8')),
                              DropdownMenuItem(value: 12, child: Text('12')),
                              DropdownMenuItem(value: 15, child: Text('15')),
                              DropdownMenuItem(value: 24, child: Text('24')),
                              DropdownMenuItem(value: 30, child: Text('30')),
                              DropdownMenuItem(value: 60, child: Text('60')),
                            ],
                            onChanged: (value) {
                              if (value != null) controller.setFps(value);
                            },
                          ),
                        ),
                        const VerticalDivider(width: 18, indent: 11, endIndent: 11),
                        Text(
                          'Frame ${controller.currentFrameIndex + 1} / ${project.frames.length}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Copy frame',
                          visualDensity: VisualDensity.compact,
                          onPressed: controller.copyCurrentFrame,
                          icon: const Icon(Icons.copy_rounded, size: 19),
                        ),
                        IconButton(
                          tooltip: 'Paste copied frame',
                          visualDensity: VisualDensity.compact,
                          onPressed: controller.pasteFrame,
                          icon: const Icon(Icons.content_paste_rounded, size: 19),
                        ),
                        IconButton(
                          tooltip: 'Duplicate frame',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => controller.addFrame(duplicateCurrent: true),
                          icon: const Icon(Icons.library_add_outlined, size: 19),
                        ),
                        IconButton(
                          tooltip: 'Add blank frame',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => controller.addFrame(),
                          icon: const Icon(Icons.add_box_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Delete current frame',
                          visualDensity: VisualDensity.compact,
                          onPressed: project.frames.length > 1
                              ? () => controller.deleteFrame(controller.currentFrameIndex)
                              : null,
                          icon: const Icon(Icons.delete_outline_rounded, size: 19),
                        ),
                        const SizedBox(width: 8),
                        const Text('Hold'),
                        const SizedBox(width: 4),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: current.holdFrames.clamp(1, 6).toInt(),
                            borderRadius: BorderRadius.circular(12),
                            items: List<DropdownMenuItem<int>>.generate(
                              6,
                              (index) => DropdownMenuItem<int>(
                                value: index + 1,
                                child: Text('${index + 1}x'),
                              ),
                            ),
                            onChanged: (value) {
                              if (value != null) controller.setFrameHold(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 88,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                    itemCount: project.frames.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      controller.reorderFrame(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final frame = project.frames[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey<String>(frame.id),
                        index: index,
                        child: _FrameTile(
                          project: project,
                          frame: frame,
                          index: index,
                          selected: index == controller.currentFrameIndex,
                          onTap: () => controller.selectFrame(index),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _FrameTile extends StatelessWidget {
  const _FrameTile({
    required this.project,
    required this.frame,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final AnimationProject project;
  final AnimationFrame frame;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 78,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: CustomPaint(
                      painter: _FramePreviewPainter(project, frame),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? colors.primary : colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FramePreviewPainter extends CustomPainter {
  _FramePreviewPainter(this.project, this.frame);

  final AnimationProject project;
  final AnimationFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    FrameRenderer.paintFrame(
      canvas,
      size,
      project,
      frame,
      paintBackground: true,
    );
  }

  @override
  bool shouldRepaint(covariant _FramePreviewPainter oldDelegate) => true;
}
