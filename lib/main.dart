import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/project_home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/project_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(AnimProApp(preferences: preferences));
}

class AnimProApp extends StatefulWidget {
  const AnimProApp({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  State<AnimProApp> createState() => _AnimProAppState();
}

class _AnimProAppState extends State<AnimProApp> {
  late ThemeMode _themeMode;
  late Locale _locale;
  late bool _showOnboarding;
  bool _showSplash = true;
  final ProjectRepository _repository = ProjectRepository();

  @override
  void initState() {
    super.initState();
    _themeMode = widget.preferences.getBool('dark_mode') == true
        ? ThemeMode.dark
        : ThemeMode.light;
    _locale = Locale(widget.preferences.getString('locale') ?? 'en');
    _showOnboarding = widget.preferences.getBool('onboarding_complete') != true;
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await widget.preferences.setBool('dark_mode', mode == ThemeMode.dark);
  }

  Future<void> _setLocale(Locale locale) async {
    setState(() => _locale = locale);
    await widget.preferences.setString('locale', locale.languageCode);
  }

  Future<void> _completeOnboarding() async {
    await widget.preferences.setBool('onboarding_complete', true);
    if (mounted) setState(() => _showOnboarding = false);
  }

  void _finishSplash() {
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AnimPro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode,
        locale: _locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _showSplash
            ? SplashScreen(onComplete: _finishSplash)
            : _showOnboarding
                ? OnboardingScreen(onComplete: _completeOnboarding)
                : ProjectHomeScreen(
                repository: _repository,
                themeMode: _themeMode,
                locale: _locale,
                onThemeModeChanged: _setThemeMode,
                onLocaleChanged: _setLocale,
              ),
        builder: (context, child) => child ?? const SizedBox.shrink(),
      );
}
