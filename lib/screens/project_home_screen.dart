import 'dart:async';

import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/frame_renderer.dart';
import '../models/drawing_models.dart';
import '../services/project_repository.dart';
import 'about_screen.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

class ProjectHomeScreen extends StatefulWidget {
  const ProjectHomeScreen({
    super.key,
    required this.repository,
    required this.themeMode,
    required this.locale,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
  });

  final ProjectRepository repository;
  final ThemeMode themeMode;
  final Locale locale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<ProjectHomeScreen> createState() => _ProjectHomeScreenState();
}

class _ProjectHomeScreenState extends State<ProjectHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<AnimationProject> _projects = <AnimationProject>[];
  bool _loading = true;
  bool _sortByName = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadProjects());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    final projects = await widget.repository.loadProjects();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _loading = false;
    });
  }

  List<AnimationProject> get _filteredProjects {
    final results = _projects.where((project) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          project.name.toLowerCase().contains(query) ||
          project.tags.any((tag) => tag.toLowerCase().contains(query)) ||
          project.folder.toLowerCase().contains(query);
    }).toList();
    if (_sortByName) {
      results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return results;
  }

  void _openProject(AnimationProject project) {
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) => EditorScreen(
              project: project,
              repository: widget.repository,
            ),
          ),
        )
        .then((_) => _loadProjects());
  }

  Future<void> _confirmDeleteProject(AnimationProject project) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text('“${project.name}” will be removed from this device.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await widget.repository.deleteProject(project.id);
    await _loadProjects();
  }

  Future<void> _createProject() async {
    final nameController = TextEditingController(text: 'Untitled animation');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).text('createAnimation')),
        content: TextField(
          controller: nameController,
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
            onPressed: () => Navigator.of(context).pop(nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || !mounted) return;
    final project = AnimationProject.create(
      name: name.trim().isEmpty ? 'Untitled animation' : name.trim(),
    );
    await widget.repository.saveProject(project);
    if (!mounted) return;
    _openProject(project);
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          themeMode: widget.themeMode,
          locale: widget.locale,
          onThemeModeChanged: widget.onThemeModeChanged,
          onLocaleChanged: widget.onLocaleChanged,
          onAbout: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final projects = _filteredProjects;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.animation_rounded, color: Colors.white, size: 21),
            ),
            const SizedBox(width: 10),
            Text(
              strings.text('appName'),
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                    child: _WelcomeCard(onCreate: _createProject),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 330,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(() => _query = value),
                            decoration: InputDecoration(
                              hintText: strings.text('search'),
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _sortByName = !_sortByName),
                          icon: const Icon(Icons.sort_rounded, size: 18),
                          label: Text(_sortByName ? 'A–Z' : 'Recent'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            strings.text('recentProjects'),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                          ),
                        ),
                        Text(
                          '${projects.length} ${projects.length == 1 ? 'project' : 'projects'}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (projects.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyProjects(onCreate: _createProject),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.99,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ProjectCard(
                          project: projects[index],
                          onTap: () => _openProject(projects[index]),
                          onDelete: () => _confirmDeleteProject(projects[index]),
                        ),
                        childCount: projects.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        icon: const Icon(Icons.add_rounded),
        label: Text(strings.text('createAnimation')),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 23, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            colors.primary.withOpacity(0.12),
            const Color(0xFF00B894).withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withOpacity(0.12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'YOUR CREATIVE SPACE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ideas in motion.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
              ),
              const SizedBox(height: 7),
              Text(
                'A quiet place to sketch, experiment, and make your next frame.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          );
          final action = FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create animation'),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[copy, const SizedBox(height: 18), action],
            );
          }
          return Row(
            children: <Widget>[Expanded(child: copy), const SizedBox(width: 20), action],
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });

  final AnimationProject project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final previewFrame = project.frames.first;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CustomPaint(
                    painter: _ProjectPreviewPainter(project, previewFrame),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: colors.surface.withOpacity(0.88),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        tooltip: 'Project actions',
                        onSelected: (value) {
                          if (value == 'delete') onDelete();
                        },
                        itemBuilder: (context) => const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete project'),
                          ),
                        ],
                        icon: const Icon(Icons.more_horiz_rounded, size: 20),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: Text(
                          '${project.canvasWidth} × ${project.canvasHeight}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${project.frames.length} frames  ·  ${project.fps} fps',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_outward_rounded, color: colors.primary, size: 19),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectPreviewPainter extends CustomPainter {
  const _ProjectPreviewPainter(this.project, this.frame);

  final AnimationProject project;
  final AnimationFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF0EFF7), BlendMode.src);
    final available = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.save();
    final aspect = project.canvasWidth / project.canvasHeight;
    final canvasWidth = aspect > available.width / available.height
        ? available.width
        : available.height * aspect;
    final canvasHeight = canvasWidth / aspect;
    final left = (size.width - canvasWidth) / 2;
    final top = (size.height - canvasHeight) / 2;
    canvas.translate(left, top);
    FrameRenderer.paintFrame(
      canvas,
      Size(canvasWidth, canvasHeight),
      project,
      frame,
      paintBackground: true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProjectPreviewPainter oldDelegate) => true;
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.movie_filter_outlined, size: 52),
            const SizedBox(height: 12),
            Text(AppStrings.of(context).text('noProjects')),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text(AppStrings.of(context).text('createAnimation')),
            ),
          ],
        ),
      );
}
