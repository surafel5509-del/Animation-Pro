import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const _pages = <({String title, String body, IconData icon, Color color})>[
    (
      title: 'welcomeTitle',
      body: 'welcomeBody',
      icon: Icons.draw_rounded,
      color: Color(0xFF6C5CE7),
    ),
    (
      title: 'tutorialCanvasTitle',
      body: 'A responsive canvas, expressive brushes, and layers that stay out of your way.',
      icon: Icons.gesture_rounded,
      color: Color(0xFF00B894),
    ),
    (
      title: 'tutorialTimelineTitle',
      body: 'Add, duplicate, and reorder frames. Onion skin helps you keep motion flowing.',
      icon: Icons.movie_creation_outlined,
      color: Color(0xFFE89A43),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _advance() {
    if (_page == _pages.length - 1) {
      widget.onComplete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final current = _pages[_page];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.animation_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        strings.text('appName'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: widget.onComplete,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (value) => setState(() => _page = value),
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        return _OnboardingArtwork(
                          title: strings.text(page.title),
                          body: index == 0
                              ? strings.text(page.body)
                              : page.body,
                          icon: page.icon,
                          color: page.color,
                          isWelcome: index == 0,
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _page ? 24 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: index == _page ? colors.primary : colors.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _advance,
                      icon: Icon(
                        _page == _pages.length - 1
                            ? Icons.brush_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        strings.text(
                          _page == _pages.length - 1 ? 'getStarted' : 'continueLabel',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingArtwork extends StatelessWidget {
  const _OnboardingArtwork({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.isWelcome,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final bool isWelcome;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final artworkSize = constraints.maxHeight.clamp(170.0, 290.0).toDouble();
        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: artworkSize,
                  height: artworkSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Container(
                        width: artworkSize * 0.76,
                        height: artworkSize * 0.76,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(artworkSize * 0.24),
                        ),
                      ),
                      Transform.rotate(
                        angle: -0.08,
                        child: Container(
                          width: artworkSize * 0.57,
                          height: artworkSize * 0.68,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: colors.outlineVariant),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: color, size: artworkSize * 0.27),
                        ),
                      ),
                      Positioned(
                        right: artworkSize * 0.05,
                        bottom: artworkSize * 0.07,
                        child: Container(
                          width: artworkSize * 0.2,
                          height: artworkSize * 0.2,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDCB6E),
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 5),
                          ),
                          child: const Icon(Icons.star_rounded, color: Color(0xFF7A5E23)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.08,
                      ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 510),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                ),
                if (isWelcome) ...<Widget>[
                  const SizedBox(height: 14),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B894).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Text(
                        'LOCAL BY DESIGN · NO AI',
                        style: TextStyle(
                          color: Color(0xFF008D70),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
