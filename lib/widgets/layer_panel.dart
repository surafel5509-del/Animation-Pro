import 'package:flutter/material.dart';

import '../controllers/editor_controller.dart';
import '../models/drawing_models.dart';

class LayerPanel extends StatelessWidget {
  const LayerPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final displayLayers = controller.project.layers.reversed.toList();
          final active = controller.activeLayer;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 10, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Layers',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add layer',
                      onPressed: () => controller.addLayer(),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Top layers appear above lower layers',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: displayLayers.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final reordered = List<AnimationLayer>.from(displayLayers);
                    final moved = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, moved);
                    controller.setLayerOrder(
                      reordered.reversed.map((layer) => layer.id).toList(),
                    );
                  },
                  itemBuilder: (context, index) {
                    final layer = displayLayers[index];
                    final selected = layer.id == controller.activeLayerId;
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey<String>(layer.id),
                      index: index,
                      child: _LayerRow(
                        layer: layer,
                        selected: selected,
                        onSelect: () => controller.selectLayer(layer.id),
                        onVisibility: () =>
                            controller.toggleLayerVisibility(layer.id),
                        onLock: () => controller.toggleLayerLock(layer.id),
                        onRename: () => _renameLayer(context, layer),
                        onDelete: () => controller.deleteLayer(layer.id),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: <Widget>[
                    const Expanded(child: Text('Opacity')),
                    Text('${(active.opacity * 100).round()}%'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Slider(
                  value: active.opacity.clamp(0, 1).toDouble(),
                  onChangeStart: (_) => controller.startLayerOpacityChange(),
                  onChanged: (value) =>
                      controller.setLayerOpacity(active.id, value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                child: DropdownButtonFormField<String>(
                  value: active.blendMode,
                  decoration: const InputDecoration(
                    labelText: 'Blend mode',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'multiply', child: Text('Multiply')),
                    DropdownMenuItem(value: 'screen', child: Text('Screen')),
                    DropdownMenuItem(value: 'overlay', child: Text('Overlay')),
                    DropdownMenuItem(value: 'darken', child: Text('Darken')),
                    DropdownMenuItem(value: 'lighten', child: Text('Lighten')),
                    DropdownMenuItem(value: 'plus', child: Text('Add')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.setLayerBlendMode(active.id, value);
                    }
                  },
                ),
              ),
            ],
          );
        },
      );

  Future<void> _renameLayer(BuildContext context, AnimationLayer layer) async {
    final textController = TextEditingController(text: layer.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename layer'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 36,
          decoration: const InputDecoration(labelText: 'Layer name'),
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
    if (name != null) controller.renameLayer(layer.id, name);
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.layer,
    required this.selected,
    required this.onSelect,
    required this.onVisibility,
    required this.onLock,
    required this.onRename,
    required this.onDelete,
  });

  final AnimationLayer layer;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onVisibility;
  final VoidCallback onLock;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? colors.primaryContainer.withOpacity(0.62) : colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onSelect,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? colors.primary.withOpacity(0.32) : colors.outlineVariant,
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.drag_indicator_rounded, size: 18),
                IconButton(
                  tooltip: layer.visible ? 'Hide layer' : 'Show layer',
                  visualDensity: VisualDensity.compact,
                  onPressed: onVisibility,
                  icon: Icon(
                    layer.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 19,
                  ),
                ),
                Expanded(
                  child: Text(
                    layer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: layer.visible ? colors.onSurface : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Layer actions',
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'rename') onRename();
                    if (value == 'delete') onDelete();
                    if (value == 'lock') onLock();
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'lock',
                      child: Text(layer.locked ? 'Unlock layer' : 'Lock layer'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                  icon: Icon(
                    layer.locked ? Icons.lock_outline_rounded : Icons.more_horiz_rounded,
                    size: 20,
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
