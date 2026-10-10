import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('About AnimPro')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.animation_rounded, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 20),
                Text(
                  'AnimPro',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A small, thoughtful studio for frame-by-frame animation.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 22),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'AnimPro is designed to keep creative work in your hands. Drawing and editing are direct, projects stay on-device by default, and no AI features are included.\n\nThis early version is a local-first foundation. Export and media capabilities depend on the platform features described in the project documentation.',
                      style: TextStyle(height: 1.55),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Version 0.1.0',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      );
}
