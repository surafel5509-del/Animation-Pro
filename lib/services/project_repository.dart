import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/drawing_models.dart';

/// Local-only JSON repository. It does not create an account or upload projects.
class ProjectRepository {
  Future<Directory> _projectDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/AnimPro/projects');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<List<AnimationProject>> loadProjects() async {
    final directory = await _projectDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.animpro.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    final projects = <AnimationProject>[];
    for (final file in files) {
      try {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        projects.add(AnimationProject.fromJson(json));
      } on FormatException {
        // A corrupt project is skipped rather than preventing the home screen opening.
      } on TypeError {
        // Keep the rest of the local project list available if a file is malformed.
      }
    }

    if (projects.isEmpty) {
      final marker = File('${directory.path}/.starter_project_created');
      if (!await marker.exists()) {
        final sample = AnimationProject.sample();
        await saveProject(sample);
        await marker.writeAsString('1', flush: true);
        return <AnimationProject>[sample];
      }
    }
    return projects;
  }

  Future<void> saveProject(AnimationProject project) async {
    final directory = await _projectDirectory();
    final file = File('${directory.path}/${project.id}.animpro.json');
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(project.toJson()), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<void> deleteProject(String projectId) async {
    final directory = await _projectDirectory();
    final file = File('${directory.path}/$projectId.animpro.json');
    if (await file.exists()) await file.delete();
  }
}
