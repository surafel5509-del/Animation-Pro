import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 950), widget.onComplete);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.24),
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.animation_rounded, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'AnimPro',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Make it move, one frame at a time.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
